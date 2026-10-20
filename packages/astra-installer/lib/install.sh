# Installation logic. Executes only after the summary confirms the user's
# final Yes. This version uses ONLINE installation via the internet.

ask_keyboard() {
	local layout
	layout=$(gum input --prompt "Keyboard layout (xkb): " --placeholder "us")
	STATE[kb_layout]="${layout:-us}"
	gum log -l info "Keyboard: ${STATE[kb_layout]}"
}

ask_mirror_regions() {
	local regions choice
	regions=(
		"World (fallback to the Arch Linux Archive)"
		"Europe"
		"North America"
		"Asia"
		"Australia"
	)
	choice=$(gum choose --cursor.foreground 117 --height 8 -- "${regions[@]}")
	[[ -n ${choice} ]] || choice="World (fallback to the Arch Linux Archive)"
	STATE[mirror_regions]="${choice%% (*}"
	gum log -l info "Mirror region: ${STATE[mirror_regions]}"
}

driver_manifests() {
	select_drivers | while IFS= read -r m; do
		[[ -n "$m" ]] && printf '%s\n' "$m"
	done
}

ask_hostname() {
	local host
	host=$(gum input --prompt "Hostname: " --placeholder "astraos")
	STATE[hostname]="${host:-astraos}"
	gum log -l info "Hostname: ${STATE[hostname]}"
}

ask_root_password() {
	local pass1 pass2
	pass1=$(gum password --prompt "Root password: ")
	pass2=$(gum password --prompt "Root password (again): ")
	[[ "$pass1" == "$pass2" ]] || die "root passwords do not match"
	[[ -n $pass1 ]] || die "root password is required"
	STATE[root_password]="$pass1"
}

ask_user() {
	local name pass1 pass2 mode
	name=$(gum input --prompt "User account: " --placeholder "user")
	STATE[user_name]="${name:-user}"
	pass1=$(gum password --prompt "User password: ")
	pass2=$(gum password --prompt "User password (again): ")
	[[ "$pass1" == "$pass2" ]] || die "user passwords do not match"
	STATE[user_password]="$pass1"
	mode=$(gum choose --cursor.foreground 117 --header "User sudo:" "passwordless" "with-password" "none")
	STATE[user_sudo]="${mode:-none}"
	gum log -l info "User: ${STATE[user_name]} (${STATE[user_sudo]} sudo)"
}

ask_packages() {
	local extra
	extra=$(gum input --prompt "Extra packages (comma-separated, optional): " --placeholder "")
	STATE[extra_packages]="${extra:-}"
}

ask_timezone() {
	local tz
	tz=$(gum input --prompt "Timezone (Region/City, UTC for none): " --placeholder "UTC")
	STATE[timezone]="${tz:-UTC}"
	gum log -l info "Timezone: ${STATE[timezone]}"
}

summary() {
	gum format --type markdown -- \
		"## Summary

- Disk: \`${STATE[disk]}\` (mode: ${STATE[storage_mode]})
- Hostname: \`${STATE[hostname]}\`
- Keyboard: ${STATE[kb_layout]}
- Mirror region: ${STATE[mirror_regions]}
- Timezone: ${STATE[timezone]}
- User: \`${STATE[user_name]}\` (${STATE[user_sudo]} sudo)
- Extra packages: \`${STATE[extra_packages]:-none}\`"

	if ! gum confirm "Write changes to disk and install AstraOS?" \
		--affirmative "Install" --negative "Back"; then
		die "installation cancelled before any disk write"
	fi
}

# Build the target package list from the bundled manifests plus the detected
# driver sets. Each manifest line is "name # reason".
build_pkg_list() {
	local -a list=()
	local m tmp
	for m in base desktop apps fonts-themes astra; do
		while IFS= read -r pkg; do
			[[ -n "$pkg" ]] && list+=("$pkg")
		done < <(manifest_packages "${MANIFESTS_DIR}/${m}.txt" 2>/dev/null || true)
	done
	while IFS= read -r drv; do
		[[ -n "$drv" ]] && while IFS= read -r pkg; do
			[[ -n "$pkg" ]] && list+=("$pkg")
		done < <(manifest_packages "${MANIFESTS_DIR}/${drv}.txt" 2>/dev/null || true)
	done < <(driver_manifests)

	# astra-installer is a live-only package; never install it on the target.
	tmp="$(mktemp)"
	printf '%s\n' "${list[@]}" >"$tmp"
	if [[ -r ${MANIFESTS_DIR}/target-exclude.txt ]]; then
		manifest_packages "${MANIFESTS_DIR}/target-exclude.txt" |
			awk 'NR == FNR { skip[$0] = 1; next } !($0 in skip) && !seen[$0]++' - "$tmp"
	else
		awk '!seen[$0]++' "$tmp"
	fi
	rm -f -- "$tmp"
}

partition_and_mount() {
	local disk="${STATE[disk]}" mnt="${MNT_ROOT:-/mnt}" part=1
	local n_root

	if [[ ${STATE[storage_mode]} == "whole" ]]; then
		log "wiping ${disk} (whole-disk mode)"
		sgdisk --zap-all "$disk"
		sgdisk -o "$disk"
	else
		GPT_BEFORE="$(snapshot_gpt "$disk")"
	fi

	sgdisk -n "${part}:0:+${STATE[esp_size]:-1GiB}" -t "${part}:EF00" "$disk"
	ESP_PART="${disk}${part}"
	n_root=$((part + 1))
	sgdisk -n "${n_root}:0:0" -t "${n_root}:8300" "$disk"
	ROOT_PART="${disk}${n_root}"

	verify_gpt_unchanged "$disk"

	log "formatting ESP (${ESP_PART}) FAT32 and root (${ROOT_PART}) Btrfs"
	mkfs.fat -F32 "$ESP_PART"
	mkfs.btrfs -f "$ROOT_PART"

	MNT_ROOT="$mnt"
	mount "$ROOT_PART" "$mnt"
	mkdir -p "${mnt}${ESP_MOUNT}"
	mount "$ESP_PART" "${mnt}${ESP_MOUNT}"

	for sub in @ @home @log @pkg @snapshots; do
		mkdir -p "${mnt}/${sub}"
		btrfs subvolume create "${mnt}/${sub}" >/dev/null 2>&1 || true
	done
	umount "$ROOT_PART"
	mount -o noatime,compress=zstd:1,space_cache=v2 "$ROOT_PART" "$mnt"
	mkdir -p "${mnt}${ESP_MOUNT}"
	mount "$ESP_PART" "${mnt}${ESP_MOUNT}"
}

write_target_pacman_conf() {
	local mnt=$1 template="${ASTRA_DATA_DIR}/pacman.conf.in" snapshot
	[[ -r ${template} ]] || die "missing pacman template: ${template}"
	snapshot="$(tr -d '[:space:]' <"${ASTRA_DATA_DIR}/snapshot")"
	[[ ${snapshot} =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] ||
		die "invalid snapshot date in the live image: ${snapshot}"

	# The live config ends with [astra-local], which only exists on the ISO.
	# The installed system uses the pinned Arch Linux Archive instead.
	sed -e "s|@SNAPSHOT@|${snapshot}|g" "$template" |
		awk '/^\[astra-local\]/ { exit } { print }' >"${mnt}/etc/pacman.conf"
}

seed_target_nvim() {
	local mnt=$1 src="${ASTRA_DATA_DIR}/nvim/lazy"
	if [[ ! -d ${src} ]]; then
		warn "Neovim plugin tree is missing from the live image"
		return 0
	fi
	install -d "${mnt}/usr/share/astra/nvim"
	rm -rf "${mnt}/usr/share/astra/nvim/lazy"
	cp -a "$src" "${mnt}/usr/share/astra/nvim/lazy"
}

configure_target() {
	local mnt="${MNT_ROOT}" tz="${STATE[timezone]}" kb="${STATE[kb_layout]}"
	local host="${STATE[hostname]}" locale="${STATE[locale]}"

	arch-chroot "$mnt" /usr/bin/bash <<EOF
set -euo pipefail
ln -sf "/usr/share/zoneinfo/${tz}" /etc/localtime
echo "KEYMAP=${kb}" > /etc/vconsole.conf
echo "${host}" > /etc/hostname
printf '127.0.0.1 localhost\\n::1 localhost\\n127.0.1.1 %s.local %s\\n' "${host}" "${host}" > /etc/hosts
printf 'LANG=%s\\n' "${locale}" > /etc/locale.conf
printf '%s:%s\\n' '${STATE[root_password]}' '${STATE[root_password]}' | chpasswd
useradd -m -U -G wheel,video,render,input,audio,storage,optical,network,power -s /bin/zsh '${STATE[user_name]}'
printf '%s:%s\\n' '${STATE[user_name]}' '${STATE[user_password]}' | chpasswd
case '${STATE[user_sudo]}' in
	passwordless) printf '%%wheel ALL=(ALL) NOPASSWD: ALL\\n' > /etc/sudoers.d/90-astra ;;
	with-password) printf '%%wheel ALL=(ALL) ALL\\n' > /etc/sudoers.d/90-astra ;;
esac
chmod 0440 /etc/sudoers.d/90-astra || true

# Ship LazyVim writably for this user; lazy.lua seeds future users from
# /usr/share/astra/nvim/lazy.
if [[ -d /usr/share/astra/nvim/lazy ]]; then
	install -d -o '${STATE[user_name]}' -g '${STATE[user_name]}' "/home/${STATE[user_name]}/.local/share/nvim"
	rm -rf "/home/${STATE[user_name]}/.local/share/nvim/lazy"
	cp -a /usr/share/astra/nvim/lazy "/home/${STATE[user_name]}/.local/share/nvim/lazy"
	chown -R '${STATE[user_name]}:${STATE[user_name]}' "/home/${STATE[user_name]}/.local/share/nvim"
fi

# Handle dual-boot OS prober
if [[ "${STATE[storage_mode]}" == "dual" ]]; then
	echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
	pacman -S --noconfirm os-prober
fi

grub-install --target=x86_64-efi --efi-directory="${ESP_MOUNT}" --bootloader-id=AstraOS --removable
grub-mkconfig -o /boot/grub/grub.cfg
systemctl set-default graphical.target
systemctl enable sddm.service NetworkManager.service bluetooth.service power-profiles-daemon.service
systemctl disable dhcpcd.service 2>/dev/null || true
EOF
}

run_install() {
	#- require_offline_repo # REMOVED for online install

	partition_and_mount

	local -a pkgs=()
	mapfile -t pkgs < <(build_pkg_list)

	# We no longer write a local-repo pacman.conf.
	# Instead, we use the standard pacstrap which uses official mirrors.
	log "running pacstrap (ONLINE mode)"
	# Copy the live keyring so the first transaction can verify Arch packages.
	# The target config is written afterwards from the pinned snapshot template.
	pacstrap -c -M "${MNT_ROOT}" base "${pkgs[@]}"

	write_target_pacman_conf "${MNT_ROOT}"

	# Defensive fallback for images that ship without a populated keyring.
	if [[ ! -s "${MNT_ROOT}/etc/pacman.d/gnupg/trustdb.gpg" ]]; then
		arch-chroot "${MNT_ROOT}" pacman-key --init
		arch-chroot "${MNT_ROOT}" pacman-key --populate archlinux
	fi

	seed_target_nvim "${MNT_ROOT}"
	configure_target

	if [[ -n "${STATE[extra_packages]}" ]]; then
		local -a extra=()
		IFS=',' read -ra extra <<<"${STATE[extra_packages]}"
		arch-chroot "${MNT_ROOT}" pacman -S --noconfirm --needed "${extra[@]}"
	fi

	genfstab -U "${MNT_ROOT}" >>"${MNT_ROOT}/etc/fstab"
	grub-mkconfig -o "${MNT_ROOT}/boot/grub/grub.cfg"
	cleanup_mounts
	log "install complete"
}
