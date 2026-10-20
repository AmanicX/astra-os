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
NVIM_TREE="${REPO_ROOT}/build/iso/nvim-lazy"
if [[ ! -d ${NVIM_TREE}/lazy.nvim ]]; then
	log "pre-baking the Neovim plugin tree..."
	prebake_user="${SUDO_USER:-$(id -un)}"
	if [[ ${EUID} -eq 0 && ${prebake_user} != root ]]; then
		sudo -u "$prebake_user" "${SCRIPT_DIR}/prebake-nvim.sh" --dest "$NVIM_TREE"
	else
		"${SCRIPT_DIR}/prebake-nvim.sh" --dest "$NVIM_TREE"
	fi
fi

PROFILE_DIR="${REPO_ROOT}/build/iso/profile"
mkdir -p "$PROFILE_DIR"

log "assembling archiso profile..."
rm -rf -- "$PROFILE_DIR"
mkdir -p "$PROFILE_DIR"
cp -r /usr/share/archiso/configs/releng/. "$PROFILE_DIR/"

# 1. AstraOS identity and UEFI-only boot. v1 does not ship BIOS support.
sed -i \
	-e 's|^iso_name=.*|iso_name="astraos"|' \
	-e 's|^iso_label=.*|iso_label="ASTRA_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"|' \
	-e 's|^iso_publisher=.*|iso_publisher="AstraOS <https://astraos.org>"|' \
	-e 's|^iso_application=.*|iso_application="AstraOS Live Installer"|' \
	"${PROFILE_DIR}/profiledef.sh"

# Replace the two-entry bootmodes array with UEFI systemd-boot only.
sed -i \
	-e "s|^bootmodes=('bios.syslinux'|bootmodes=('uefi.systemd-boot')|" \
	-e "/^[[:space:]]*'uefi.systemd-boot')\$/d" \
	"${PROFILE_DIR}/profiledef.sh"

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
chmod 0440 "${PROFILE_DIR}/airootfs/etc/sudoers.d/10-astra-live"

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
rm -rf -- "${REPO_ROOT}/work"
mkarchiso -v -w "${REPO_ROOT}/work" -o "${REPO_ROOT}/out" "$PROFILE_DIR"

log "ISO built successfully at ${REPO_ROOT}/out"
