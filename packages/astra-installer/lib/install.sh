# Package selection and installation.
#
# This layer assumes the target is already mounted by storage.sh.  It runs
# pacstrap, writes the target pacman configuration, generates fstab, and runs
# all target configuration inside arch-chroot.  The host's grub-mkconfig is
# never used.

manifest_packages() {
	local file=$1
	[[ -r $file ]] || return 1
	awk '
		{
			sub(/#.*/, "")
			gsub(/^[ \t]+|[ \t]+$/, "")
			if (length($0) > 0) print
		}
	' "$file"
}

# Fill the global PKG_LIST array with the deduplicated target package set.
build_pkg_list() {
	local -a list=()
	local -a filtered=()
	local -A seen=()
	local -A excluded=()
	local pkg manifest drv skip_nvidia_open=0

	for manifest in base desktop apps fonts-themes astra; do
		while IFS= read -r pkg; do
			[[ -n ${pkg:-} ]] && list+=("$pkg")
		done < <(manifest_packages "${MANIFESTS_DIR}/${manifest}.txt" 2>/dev/null || true)
	done

	while IFS= read -r drv; do
		[[ -n ${drv:-} ]] || continue
		while IFS= read -r pkg; do
			[[ -n ${pkg:-} ]] && list+=("$pkg")
		done < <(manifest_packages "${MANIFESTS_DIR}/${drv}.txt" 2>/dev/null || true)
	done < <(select_drivers)

	# CPU microcode is required even on machines where lspci cannot identify
	# the GPU (for example passthrough or headless installs).
	case "$(cpu_vendor)" in
	amd) list+=("amd-ucode") ;;
	intel) list+=("intel-ucode") ;;
	esac

	while IFS= read -r pkg; do
		[[ -n ${pkg:-} ]] && excluded["$pkg"]=1
	done < <(manifest_packages "${MANIFESTS_DIR}/target-exclude.txt" 2>/dev/null || true)

	# The NVIDIA manifest lists both the prebuilt and DKMS variants as a
	# fallback pair.  They conflict on Arch; prefer DKMS so kernel updates keep
	# working.
	for pkg in "${list[@]}"; do
		[[ $pkg == nvidia-open-dkms ]] && skip_nvidia_open=1
	done

	for pkg in "${list[@]}"; do
		[[ -n ${pkg:-} ]] || continue
		[[ -n ${excluded[$pkg]:-} ]] && continue
		if [[ $pkg == nvidia-open && $skip_nvidia_open == 1 ]]; then
			continue
		fi
		if [[ -n ${seen[$pkg]:-} ]]; then
			continue
		fi
		seen[$pkg]=1
		filtered+=("$pkg")
	done

	((${#filtered[@]} > 0)) || die "target package list is empty (missing manifests?)"
	printf '%s\n' "${filtered[@]}"
}

install_extra_packages() {
	local raw=${STATE[extra_packages]}
	[[ -n ${raw:-} ]] || return 0

	local -a extra=()
	local item
	while IFS= read -r item; do
		item="${item//[[:space:]]/}"
		[[ -n ${item:-} ]] || continue
		if [[ ! $item =~ ^[A-Za-z0-9@._+-]+$ ]]; then
			warn "ignoring invalid extra package name: ${item}"
			continue
		fi
		extra+=("$item")
	done < <(printf '%s' "$raw" | tr ',' '\n')

	((${#extra[@]} > 0)) || return 0
	log "installing extra packages: ${extra[*]}"
	if ! arch-chroot "$MNT_ROOT" pacman -S --noconfirm --needed "${extra[@]}" 2>&1 |
		tee -a "$LOG"; then
		warn "some extra packages could not be installed"
		ui_confirm "Continue without the failed extra packages?" ||
			die "installation cancelled after extra package failure"
	fi
}

write_target_setup_script() {
	cat >"${TARGET_SCRIPT}" <<'TARGET_SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Secrets and answers are written to a mode-0600 file by the parent installer
# and removed immediately after sourcing.
if [[ -r /tmp/astra-env ]]; then
	# shellcheck disable=SC1091
	source /tmp/astra-env
	rm -f /tmp/astra-env
fi

: "${ASTRA_HOSTNAME:?}"
: "${ASTRA_TZ:?}"
: "${ASTRA_LOCALE:?}"
: "${ASTRA_KEYMAP:?}"
: "${ASTRA_USERNAME:?}"
: "${ASTRA_ROOT_PASSWORD:?}"
: "${ASTRA_USER_PASSWORD:?}"
: "${ASTRA_SUDO_MODE:?}"
: "${ASTRA_ESP_MOUNT:?}"
: "${ASTRA_DUAL_BOOT:=0}"

echo "==> timezone and clock"
ln -sf "/usr/share/zoneinfo/${ASTRA_TZ}" /etc/localtime
hwclock --systohc 2>/dev/null || true

echo "==> locale"
if grep -q "^#${ASTRA_LOCALE} " /etc/locale.gen 2>/dev/null; then
	sed -i "s|^#${ASTRA_LOCALE} |${ASTRA_LOCALE} |" /etc/locale.gen
elif ! grep -q "^${ASTRA_LOCALE} " /etc/locale.gen 2>/dev/null; then
	printf '%s UTF-8\n' "${ASTRA_LOCALE}" >>/etc/locale.gen
fi
locale-gen
printf 'LANG=%s\n' "${ASTRA_LOCALE}" >/etc/locale.conf
printf 'KEYMAP=%s\n' "${ASTRA_KEYMAP}" >/etc/vconsole.conf

echo "==> hostname"
printf '%s\n' "${ASTRA_HOSTNAME}" >/etc/hostname
cat >/etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${ASTRA_HOSTNAME}.localdomain ${ASTRA_HOSTNAME}
EOF

echo "==> root password"
printf 'root:%s\n' "${ASTRA_ROOT_PASSWORD}" | chpasswd

echo "==> user ${ASTRA_USERNAME}"
groups="video,render,input,audio,storage,optical,network,power"
if [[ ${ASTRA_SUDO_MODE} != none ]]; then
	groups="wheel,${groups}"
fi
if id "${ASTRA_USERNAME}" >/dev/null 2>&1; then
	usermod -aG "${groups}" -s /bin/zsh "${ASTRA_USERNAME}"
else
	useradd -m -U -G "${groups}" -s /bin/zsh "${ASTRA_USERNAME}"
fi
printf '%s:%s\n' "${ASTRA_USERNAME}" "${ASTRA_USER_PASSWORD}" | chpasswd

install -d -m 0750 /etc/sudoers.d
case "${ASTRA_SUDO_MODE}" in
passwordless)
	printf '%%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n' >/etc/sudoers.d/90-astra
	;;
with-password)
	printf '%%wheel ALL=(ALL:ALL) ALL\n' >/etc/sudoers.d/90-astra
	;;
none)
	rm -f /etc/sudoers.d/90-astra
	;;
*)
	printf 'invalid ASTRA_SUDO_MODE\n' >&2
	exit 1
	;;
esac
if [[ -e /etc/sudoers.d/90-astra ]]; then
	chmod 0440 /etc/sudoers.d/90-astra
fi

echo "==> zram configuration"
if [[ ! -e /etc/systemd/zram-generator.conf ]]; then
	cat >/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF
fi

echo "==> services"
systemctl enable NetworkManager.service
systemctl enable sddm.service
systemctl enable bluetooth.service
systemctl enable power-profiles-daemon.service
systemctl enable fstrim.timer
systemctl enable systemd-timesyncd.service
systemctl enable grub-btrfsd.service 2>/dev/null || true
systemctl disable dhcpcd.service 2>/dev/null || true
systemctl set-default graphical.target

# Seed Neovim's lazy.nvim directory from the live image, matching the
# configured desktop.  Do not overwrite a pre-existing user directory.
if [[ -d /usr/share/astra/nvim/lazy && ${ASTRA_USERNAME} != root ]]; then
	home="/home/${ASTRA_USERNAME}"
	install -d -o "${ASTRA_USERNAME}" -g "${ASTRA_USERNAME}" \
		"${home}/.local/share/nvim"
	if [[ ! -d ${home}/.local/share/nvim/lazy ]]; then
		cp -a /usr/share/astra/nvim/lazy "${home}/.local/share/nvim/lazy"
	fi
	chown -R "${ASTRA_USERNAME}:${ASTRA_USERNAME}" "${home}/.local"
fi

echo "==> initramfs"
mkinitcpio -P

echo "==> GRUB"
if ! grub-install --target=x86_64-efi --efi-directory="${ASTRA_ESP_MOUNT}" \
	--bootloader-id=AstraOS --recheck; then
	echo "normal GRUB install failed; trying the removable fallback" >&2
	grub-install --target=x86_64-efi --efi-directory="${ASTRA_ESP_MOUNT}" \
		--bootloader-id=AstraOS --removable --recheck
fi

if [[ ${ASTRA_DUAL_BOOT} == 1 ]] && command -v os-prober >/dev/null 2>&1; then
	if grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub 2>/dev/null; then
		sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
	else
		printf 'GRUB_DISABLE_OS_PROBER=false\n' >>/etc/default/grub
	fi
fi

grub-mkconfig -o /boot/grub/grub.cfg

echo "==> target configuration complete"
TARGET_SCRIPT_EOF
	chmod 0700 "${TARGET_SCRIPT}"
}

configure_target() {
	write_target_setup_script

	local envfile="${MNT_ROOT}/tmp/astra-env"
	mkdir -p "${MNT_ROOT}/tmp" || die "cannot create target /tmp"

	{
		printf 'ASTRA_HOSTNAME=%q\n' "${STATE[hostname]}"
		printf 'ASTRA_TZ=%q\n' "${STATE[timezone]}"
		printf 'ASTRA_LOCALE=%q\n' "${STATE[locale]}"
		printf 'ASTRA_KEYMAP=%q\n' "${STATE[kb_layout]}"
		printf 'ASTRA_USERNAME=%q\n' "${STATE[user_name]}"
		printf 'ASTRA_ROOT_PASSWORD=%q\n' "${STATE[root_password]}"
		printf 'ASTRA_USER_PASSWORD=%q\n' "${STATE[user_password]}"
		printf 'ASTRA_SUDO_MODE=%q\n' "${STATE[user_sudo]}"
		printf 'ASTRA_ESP_MOUNT=%q\n' "${STATE[esp_mount]}"
		if [[ ${STATE[storage_mode]} == whole ]]; then
			printf 'ASTRA_DUAL_BOOT=0\n'
		else
			printf 'ASTRA_DUAL_BOOT=1\n'
		fi
	} >"${envfile}" || die "cannot write target environment file"
	chmod 0600 "${envfile}"

	install -m 0700 "${TARGET_SCRIPT}" "${MNT_ROOT}/tmp/astra-target-setup.sh" ||
		die "cannot copy the target setup script"

	if ! arch-chroot "${MNT_ROOT}" /tmp/astra-target-setup.sh 2>&1 | tee -a "$LOG"; then
		rm -f "${MNT_ROOT}/tmp/astra-target-setup.sh" "${envfile}"
		die "target configuration failed; see ${LOG}"
	fi
	rm -f "${MNT_ROOT}/tmp/astra-target-setup.sh" "${envfile}"
	log "target configuration finished"
}

run_install() {
	prepare_storage
	write_install_pacman_conf

	local -a packages=()
	while IFS= read -r pkg; do
		[[ -n ${pkg:-} ]] && packages+=("$pkg")
	done < <(build_pkg_list)
	((${#packages[@]} > 0)) || die "no packages selected"

	log "installing ${#packages[@]} packages into ${MNT_ROOT}"
	gum style --foreground 117 --margin 1 "Installing ${#packages[@]} packages..." || true

	# Do NOT pass -c here.  -c tells pacstrap to use the live host's package
	# cache, which is the 256 MiB archiso overlay (frequently only ~250 MiB
	# free).  The default lets pacstrap use the target's own cache
	# (/var/cache/pacman/pkg on the new root), so a 2 GiB download fits on the
	# 40 GiB test disk and on any disk that passed the 25 GiB size check.
	local -a pacstrap_args=(-C "$PACMAN_CONF" -M)
	if [[ ! -d ${MNT_ROOT}/etc/pacman.d/gnupg ]]; then
		pacstrap_args+=(-K)
	fi

	if ! pacstrap "${pacstrap_args[@]}" "$MNT_ROOT" "${packages[@]}" 2>&1 |
		tee -a "$LOG"; then
		die "pacstrap failed. Check the network and ${LOG}."
	fi

	write_target_pacman_conf "$MNT_ROOT"
	install_extra_packages

	# Generate fstab from the actual live mounts.  This captures Btrfs subvol=
	# options and the ESP correctly for both new and pre-mounted installs.
	genfstab -U "$MNT_ROOT" >"${MNT_ROOT}/etc/fstab" ||
		die "genfstab failed"
	log "wrote target /etc/fstab"

	configure_target

	install -Dm0644 "$LOG" "${MNT_ROOT}/var/log/astra-install.log" 2>/dev/null || true
	if [[ -r ${ANSWERS} ]]; then
		install -Dm0644 "${ANSWERS}" "${MNT_ROOT}/var/log/astra-answers.json" 2>/dev/null || true
	fi

	cleanup_mounts
	log "installation finished"
}
