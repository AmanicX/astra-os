#!/usr/bin/env bash
# Build the AstraOS live ISO.
#
# This script assembles the archiso profile, configures the airootfs,
# and runs mkarchiso to produce the final bootable image.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=scripts/lib/manifests.sh
source "${SCRIPT_DIR}/lib/manifests.sh"
# shellcheck source=scripts/lib/brand.sh
source "${SCRIPT_DIR}/lib/brand.sh"

brand_load

PLAN=0
BUILD=0

usage() {
	cat <<'EOF'
Usage: build-iso.sh [--plan | --build]

  --plan      Print the live package set and repository readiness (default).
  --build     Build the ISO. Requires ASTRA_ISO_APPROVED=1.
  -h, --help  Show this help.
EOF
}

while (($# > 0)); do
	case "$1" in
	--plan)
		PLAN=1
		;;
	--build)
		BUILD=1
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		die "unknown argument: $1"
		;;
	esac
	shift
done

if ((PLAN == 0 && BUILD == 0)); then
	PLAN=1
fi
if ((PLAN == 1 && BUILD == 1)); then
	die "--plan and --build are mutually exclusive"
fi

require_arch_host
require_free_gib 15 "$REPO_ROOT"

SNAPSHOT="$(tr -d '[:space:]' <"${REPO_ROOT}/config/snapshot")"
[[ ${SNAPSHOT} =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] ||
	die "invalid snapshot date '${SNAPSHOT}'; expected YYYY/MM/DD"

live_list="${REPO_ROOT}/build/iso/live-packages.txt"
mkdir -p "$(dirname -- "$live_list")"
manifest_live >"$live_list"

log "identity: ${BRAND_NAME} (${BRAND_LONG_NAME})"
log "snapshot: ${SNAPSHOT}"
log "live packages: $(wc -l <"$live_list")"
log "repository: ${REPO_ROOT}/repo/x86_64"

if [[ -r ${REPO_ROOT}/repo/x86_64/astra-local.db ]]; then
	log "local repository database: present"
elif ((BUILD == 1)); then
	die "local repository database is missing; run build-repo.sh --build first"
else
	warn "local repository database is missing; ensure Astra packages are built"
fi

if ((PLAN == 1)); then
	printf '\nLive-only and desktop packages are listed in:\n  %s\n' "$live_list"
	printf '\nPlan only. No ISO was built. ISO builds are paused by the owner (D-021).\n'
	exit 0
fi

# --- BUILD STAGE ---
if [[ ${ASTRA_ISO_APPROVED:-0} != "1" ]]; then
	die "ISO builds are paused. Set ASTRA_ISO_APPROVED=1 only after the owner explicitly approves a build."
fi

require_root_or_sudo
require_tools git mkarchiso

# The desktop config expects a pinned, read-only LazyVim tree at
# /usr/share/astra/nvim/lazy. Build it once and cache it between ISO runs.
NVIM_TREE="${ASTRA_NVIM_TREE:-/var/tmp/astraos-nvim-lazy}"
if [[ ! -d ${NVIM_TREE}/lazy.nvim ]]; then
	log "pre-baking the Neovim plugin tree..."
	if [[ -d "${REPO_ROOT}/build/iso/nvim-lazy/lazy.nvim" ]]; then
		cp -a "${REPO_ROOT}/build/iso/nvim-lazy" "$NVIM_TREE"
	else
		"${SCRIPT_DIR}/prebake-nvim.sh" --dest "$NVIM_TREE"
	fi
fi

PROFILE_DIR="${ASTRA_PROFILE_DIR:-/var/tmp/astraos-profile}"
mkdir -p "$PROFILE_DIR"

log "assembling archiso profile..."
rm -rf -- "$PROFILE_DIR"
mkdir -p "$PROFILE_DIR"
cp -r /usr/share/archiso/configs/releng/. "$PROFILE_DIR/"

# 1. Rebrand the copied boot menus and set the ISO identity. The rebrand step
# keeps archisobasedir=, archisosearchuuid= and the entry filenames functional;
# only menu titles, help text and the identity fields change.
"${SCRIPT_DIR}/rebrand-archiso.sh" "${PROFILE_DIR}"

# Replace the two-entry bootmodes array with UEFI systemd-boot only.
sed -i \
	-e "s|^bootmodes=('bios.syslinux'|bootmodes=('uefi.systemd-boot')|" \
	-e "/^[[:space:]]*'uefi.systemd-boot')\$/d" \
	"${PROFILE_DIR}/profiledef.sh"

# Keep a serial console alongside the local display.  Headless installs and
# rescue work need it, and it lets the UEFI boot path be verified over serial.
grep -q '^kernel_params_x86_64=' "${PROFILE_DIR}/profiledef.sh" ||
	printf '%s\n' 'kernel_params_x86_64="console=ttyS0,115200"' \
		>>"${PROFILE_DIR}/profiledef.sh"

# zstd keeps live-image builds practical on WSL while remaining fully supported
# by the Arch kernel.  The releng profile's xz default takes an hour here.
printf '%s\n' "airootfs_image_tool_options=('-comp' 'zstd' '-b' '1M')" \
	>>"${PROFILE_DIR}/profiledef.sh"

# 2. Replace the default package list with the AstraOS live manifest.
cat "$live_list" >"${PROFILE_DIR}/packages.x86_64"

# 2. Pacman configuration. Both the mkarchiso build and the live environment
# use the date-pinned Arch Linux Archive, so installs are reproducible and do
# not drift with the current mirrors.
sed \
	-e "s|@SNAPSHOT@|${SNAPSHOT}|g" \
	-e "s|@REPO_ROOT@|${REPO_ROOT}|g" \
	"${REPO_ROOT}/config/pacman.conf.in" >"${PROFILE_DIR}/pacman.conf"

mkdir -p "${PROFILE_DIR}/airootfs/etc"
sed \
	-e "s|@SNAPSHOT@|${SNAPSHOT}|g" \
	-e "s|@REPO_ROOT@|/usr/share/astra|g" \
	"${REPO_ROOT}/config/pacman.conf.in" >"${PROFILE_DIR}/airootfs/etc/pacman.conf"

# 3. Overlay the live-session files (SDDM autologin, live user setup, network).
cp -a "${REPO_ROOT}/config/live/airootfs/." "${PROFILE_DIR}/airootfs/"
chmod 0755 "${PROFILE_DIR}/airootfs/root/customize_airootfs.sh"

# 4. Runtime data for the installer: manifests, snapshot pin and pacman
# template used to normalise the installed system.
mkdir -p "${PROFILE_DIR}/airootfs/etc/astra"
mkdir -p "${PROFILE_DIR}/airootfs/usr/share/astra/manifests"
cp "${REPO_ROOT}/manifests/"*.txt \
	"${PROFILE_DIR}/airootfs/usr/share/astra/manifests/"
install -Dm644 "${REPO_ROOT}/config/pacman.conf.in" \
	"${PROFILE_DIR}/airootfs/usr/share/astra/pacman.conf.in"
install -Dm644 "${REPO_ROOT}/config/snapshot" \
	"${PROFILE_DIR}/airootfs/usr/share/astra/snapshot"

# 4b. Always ship the installer sources from this checkout.  The prebuilt
# astra-installer package in repo/x86_64 can lag behind the source tree; the
# live image must never boot an old installer.  Stage the files under /root and
# let customize_airootfs.sh copy them in after packages are installed, because
# mkarchiso copies a custom airootfs before running pacstrap and would otherwise
# conflict with files owned by the astra-installer package.
installer_overlay="${PROFILE_DIR}/airootfs/root/astra-installer-overlay"
install -Dm755 "${REPO_ROOT}/packages/astra-installer/astra-install" \
	"${installer_overlay}/usr/bin/astra-install"
install -Dm755 "${REPO_ROOT}/packages/astra-installer/astra-engine" \
	"${installer_overlay}/usr/lib/astra/installer/astra-engine"
ln -sf ../lib/astra/installer/astra-engine \
	"${installer_overlay}/usr/bin/astra-installer-engine"
install -Dm644 "${REPO_ROOT}/packages/astra-installer/astra-installer.desktop" \
	"${installer_overlay}/usr/share/applications/astra-installer.desktop"
install -d "${installer_overlay}/usr/lib/astra/installer/lib"
cp -a "${REPO_ROOT}/packages/astra-installer/lib/." \
	"${installer_overlay}/usr/lib/astra/installer/lib/"
install -d "${installer_overlay}/etc/astra"
install -Dm644 "${REPO_ROOT}/packages/astra-installer/pacman-offline.conf" \
	"${installer_overlay}/etc/astra/pacman-offline.conf"
install -Dm644 "${REPO_ROOT}/packages/astra-installer/pacman-target.conf" \
	"${installer_overlay}/etc/astra/pacman-target.conf"
install -Dm644 "${REPO_ROOT}/packages/astra-installer/astra-pending-packages.service" \
	"${installer_overlay}/usr/lib/systemd/system/astra-pending-packages.service"
install -Dm755 "${REPO_ROOT}/packages/astra-installer/astra-pending-packages.sh" \
	"${installer_overlay}/usr/lib/astra/installer/pending-packages.sh"

# 4. Verify terminal installer entrypoint is ready.
[[ -f "${REPO_ROOT}/packages/astra-installer/astra-install" ]] ||
	die "astra-install executable is missing from packages/astra-installer"

# 5. Bundle the local repository so the installer can resolve Astra and AUR
# packages without a second network source.
install -d "${PROFILE_DIR}/airootfs/usr/share/astra/repo"
cp -a "${REPO_ROOT}/repo/x86_64" \
	"${PROFILE_DIR}/airootfs/usr/share/astra/repo/"
chown -R 0:0 "${PROFILE_DIR}/airootfs/usr/share/astra/repo"

# 6. Ship the pinned LazyVim plugin tree read-only. First login copies it to
# the user's data directory (see the Neovim config).
install -d "${PROFILE_DIR}/airootfs/usr/share/astra/nvim"
cp -a "$NVIM_TREE" "${PROFILE_DIR}/airootfs/usr/share/astra/nvim/lazy"
chown -R 0:0 "${PROFILE_DIR}/airootfs/usr/share/astra/nvim"

log "running mkarchiso..."
mkdir -p "${REPO_ROOT}/out"
WORK_DIR="${ASTRA_WORK_DIR:-/var/tmp/astraos-work}"
rm -rf -- "$WORK_DIR"
mkdir -p "$WORK_DIR"
mkarchiso -v -w "$WORK_DIR" -o "${REPO_ROOT}/out" "$PROFILE_DIR"

log "ISO built successfully at ${REPO_ROOT}/out"
