#!/usr/bin/env bash
# Build the AstraOS live ISO.
#
# ISO builds are paused by the owner (D-021). This script defaults to `--plan`
# and refuses to build unless the owner explicitly sets ASTRA_ISO_APPROVED=1.
# The build stage is not implemented yet.
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
require_free_gib 5 "$REPO_ROOT"

live_list="${REPO_ROOT}/build/iso/live-packages.txt"
mkdir -p "$(dirname -- "$live_list")"
manifest_live >"$live_list"

log "live packages: $(wc -l <"$live_list")"
log "repository: ${REPO_ROOT}/repo/x86_64"

if [[ -r ${REPO_ROOT}/repo/x86_64/astra-local.db ]]; then
	log "local repository database: present"
else
	warn "local repository database is missing"
fi

printf '\nLive-only and desktop packages are listed in:\n  %s\n' "$live_list"

if ((BUILD == 0)); then
	printf '\nPlan only. No ISO was built. ISO builds are paused by the owner (D-021).\n'
	exit 0
fi

if [[ ${ASTRA_ISO_APPROVED:-0} != "1" ]]; then
	die "ISO builds are paused. Set ASTRA_ISO_APPROVED=1 only after the owner explicitly approves a build."
fi

require_root_or_sudo
require_tools mkarchiso
die "the ISO build stage is not implemented yet; the plan is complete and safe"
