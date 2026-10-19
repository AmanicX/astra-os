#!/usr/bin/env bash
# Build the AstraOS offline repository.
#
# This script currently implements a safe `--plan` mode: it resolves the
# official package closure against the pinned Arch Linux Archive snapshot and
# prints the AUR/Astra payload. The actual download and clean-chroot build
# stages are not implemented yet and are intentionally blocked behind
# `--build` so a plan can never be mistaken for a finished repository.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=scripts/lib/manifests.sh
source "${SCRIPT_DIR}/lib/manifests.sh"

SNAPSHOT=""
PLAN=0
BUILD=0
CLEAN=0

usage() {
	cat <<'EOF'
Usage: build-repo.sh [--plan | --build] [--snapshot YYYY/MM/DD] [--clean]

  --plan                 Resolve and print the repository closure (default).
  --build                Download packages and build AUR packages (not implemented).
  --snapshot DATE        Override config/snapshot.
  --clean               Remove build/repo before starting.
  -h, --help            Show this help.
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
	--snapshot)
		[[ $# -ge 2 ]] || die "--snapshot requires a date"
		SNAPSHOT=$2
		shift
		;;
	--clean)
		CLEAN=1
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
require_tools awk curl df pacman sed sort
require_free_gib 5 "$REPO_ROOT"

if [[ -z ${SNAPSHOT} ]]; then
	SNAPSHOT="$(tr -d '[:space:]' <"${REPO_ROOT}/config/snapshot")"
fi
[[ ${SNAPSHOT} =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] ||
	die "invalid snapshot date '${SNAPSHOT}'; expected YYYY/MM/DD"

BUILD_ROOT="${REPO_ROOT}/build/repo"
PLAN_ROOT="${BUILD_ROOT}/plan"
DB_ROOT="${PLAN_ROOT}/db"
CACHE_ROOT="${PLAN_ROOT}/cache"
PACMAN_CONF="${PLAN_ROOT}/pacman.conf"

if ((CLEAN == 1)); then
	[[ ${BUILD_ROOT} == "${REPO_ROOT}/build/repo" ]] ||
		die "refusing to clean an unexpected path: ${BUILD_ROOT}"
	rm -rf -- "$BUILD_ROOT"
fi

mkdir -p "$DB_ROOT/sync" "$DB_ROOT/local" "$CACHE_ROOT"

log "snapshot: ${SNAPSHOT}"
log "repository root: ${REPO_ROOT}"

# Verify the snapshot exists before downloading a database.
curl -fsS --retry 3 --max-time 30 -o /dev/null \
	"https://archive.archlinux.org/repos/${SNAPSHOT}/core/os/x86_64/core.db" ||
	die "snapshot ${SNAPSHOT} is not available on the Arch Linux Archive"

for repo in core extra multilib; do
	log "sync database: ${repo}"
	curl -fsS --retry 3 --max-time 120 \
		"https://archive.archlinux.org/repos/${SNAPSHOT}/${repo}/os/x86_64/${repo}.db" \
		-o "${DB_ROOT}/sync/${repo}.db"
done

sed -e "s|@SNAPSHOT@|${SNAPSHOT}|g" \
	-e "s|@REPO_ROOT@|${REPO_ROOT}|g" \
	"${REPO_ROOT}/config/pacman.conf.in" |
	awk '/^\[astra-local\]/ { exit } { print }' >"$PACMAN_CONF"

official_list="${PLAN_ROOT}/official.txt"
aur_list="${PLAN_ROOT}/aur.txt"
astra_list="${PLAN_ROOT}/astra.txt"
manifest_repo_official >"$official_list"
manifest_aur >"$aur_list"
manifest_astra >"$astra_list"

log "official packages in payload: $(wc -l <"$official_list")"
log "AUR packages to build: $(wc -l <"$aur_list")"
log "Astra packages to build: $(wc -l <"$astra_list")"

closure="${PLAN_ROOT}/closure.tsv"
mapfile -t official_packages <"$official_list"
if ! pacman -Sp --print-format '%n %v %s %r' \
	--dbpath "$DB_ROOT" --cachedir "$CACHE_ROOT" --config "$PACMAN_CONF" \
	"${official_packages[@]}" >"$closure" 2>"${PLAN_ROOT}/closure.err"; then
	cat "${PLAN_ROOT}/closure.err" >&2
	die "could not resolve the official package closure"
fi

official_count="$(wc -l <"$closure")"
download_bytes="$(awk '{ sum += $3 } END { printf "%.0f", sum }' "$closure")"
download_gib="$(awk -v b="$download_bytes" 'BEGIN { printf "%.2f", b / 1024 / 1024 / 1024 }')"

log "resolved official packages: ${official_count}"
log "estimated official download: ${download_gib} GiB"
printf '\nAUR payload:\n'
sed 's/^/  /' "$aur_list"
printf '\nAstra payload:\n'
sed 's/^/  /' "$astra_list"

if ((BUILD == 0)); then
	printf '\nPlan only. No packages were downloaded and no repository was built.\n'
	exit 0
fi

die "the --build stage is not implemented yet; the plan is complete and safe"
