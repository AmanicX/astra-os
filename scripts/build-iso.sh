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

live_list="${REPO_ROOT}/build/iso/live-packages.txt"
mkdir -p "$(dirname -- "$live_list")"
manifest_live >"$live_list"

log "live packages: $(wc -l <"$live_list")"
log "repository: ${REPO_ROOT}/repo/x86_64"

if [[ -r ${REPO_ROOT}/repo/x86_64/astra-local.db ]]; then
	log "local repository database: present"
else
	# In online mode, the local repo is optional for the ISO but
	# still needed for Astra-owned packages.
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
require_tools mkarchiso

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

# 2. Configure pacman.conf for standard official mirrors.
cat <<EOF >"${PROFILE_DIR}/pacman.conf"
[options]
Architecture = auto
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

[astra-local]
SigLevel = Optional TrustAll
Server = file://${REPO_ROOT}/repo/x86_64
EOF

# 3. Set up airootfs for branding and installer
mkdir -p "${PROFILE_DIR}/airootfs/etc/astra"
mkdir -p "${PROFILE_DIR}/airootfs/usr/share/astra/manifests"

# Copy the manifests for the installer to use offline
cp "${REPO_ROOT}/manifests/"*.txt "${PROFILE_DIR}/airootfs/usr/share/astra/manifests/"

# 4. Configure bootloader (GRUB UEFI)
# The releng profile uses systemd-boot by default. We switch to GRUB.

log "running mkarchiso..."
mkdir -p "${REPO_ROOT}/out"
rm -rf -- "${REPO_ROOT}/work"
mkarchiso -v -w "${REPO_ROOT}/work" -o "${REPO_ROOT}/out" "$PROFILE_DIR"

log "ISO built successfully at ${REPO_ROOT}/out"
