#!/usr/bin/env bash
# Build the AstraOS offline repository.
#
# This script builds the Astra-owned packages plus the pinned AUR set into
# repo/x86_64 and writes the astra-local database consumed by build-iso.sh.
# Official Arch packages are resolved from the date-pinned archive, not here.
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
  --build                Build Astra-owned packages into the local repo.
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
require_tools awk curl df pacman repo-add sed sort
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
REPO_PATH="${REPO_ROOT}/repo/x86_64"
TMP_BUILD_DIR="${REPO_ROOT}/build/tmp"
SRCDEST="${REPO_ROOT}/build/sources"
DB_PATH="${REPO_PATH}/astra-local.db.tar.gz"

# AUR sources to clone. Several payload packages are split-package outputs of
# these sources and therefore must not be cloned on their own:
#   nvidia-580xx-utils         -> nvidia-580xx-utils, nvidia-580xx-dkms,
#                                 opencl-nvidia-580xx
#   lib32-nvidia-580xx-utils   -> lib32-nvidia-580xx-utils,
#                                 lib32-opencl-nvidia-580xx
AUR_SOURCES=(
	paru
	oh-my-posh-bin
	nvidia-580xx-utils
	lib32-nvidia-580xx-utils
	nvidia-580xx-settings
)

# makepkg refuses to run as root. Build as the invoking user, falling back to
# the owner of the checkout when the script is started without sudo.
BUILD_USER="${SUDO_USER:-$(id -un)}"
if [[ ${BUILD_USER} == root ]]; then
	BUILD_USER="$(stat -c '%U' "$REPO_ROOT")"
fi
[[ ${BUILD_USER} != root ]] ||
	die "no unprivileged user available for makepkg; run with sudo from a normal account"

if ((CLEAN == 1)); then
	[[ ${BUILD_ROOT} == "${REPO_ROOT}/build/repo" ]] ||
		die "refusing to clean an unexpected path: ${BUILD_ROOT}"
	rm -rf -- "$BUILD_ROOT"
fi

mkdir -p "$DB_ROOT/sync" "$DB_ROOT/local" "$CACHE_ROOT"

# Earlier privileged runs leave the build tree owned by root; hand it back so
# --plan works without sudo afterwards.
if [[ ${EUID} -eq 0 && -d ${BUILD_ROOT} ]]; then
	chown -R "${BUILD_USER}:${BUILD_USER}" "$BUILD_ROOT"
fi

log "snapshot: ${SNAPSHOT}"
log "repository root: ${REPO_ROOT}"

# Verify the snapshot exists.
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
log "AUR packages in payload: $(wc -l <"$aur_list")"
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

if ((PLAN == 1)); then
	printf '\nAUR sources:\n'
	printf '  %s\n' "${AUR_SOURCES[@]}"
	printf '\nAstra payload:\n'
	sed 's/^/  /' "$astra_list"
	printf '\nPlan only. No packages were downloaded and no repository was built.\n'
	exit 0
fi

# --- BUILD STAGE ---
require_root_or_sudo
mkdir -p "$REPO_PATH" "$TMP_BUILD_DIR" "$SRCDEST"
chown -R "${BUILD_USER}:${BUILD_USER}" "$TMP_BUILD_DIR" "$SRCDEST"

log "building as ${BUILD_USER}"

# Absolute paths are used throughout. Do not cd out of the loop: a leaked
# working directory silently skips every remaining relative package path.
log "building Astra packages..."
for pkg_dir in "${REPO_ROOT}"/packages/astra-*; do
	[[ -d ${pkg_dir} ]] || continue
	pkg_name="${pkg_dir##*/}"
	log "building ${pkg_name}"

	work_dir="${TMP_BUILD_DIR}/${pkg_name}"
	rm -rf -- "$work_dir"
	mkdir -p "$work_dir"
	cp -a "${pkg_dir}/." "$work_dir/"
	chown -R "${BUILD_USER}:${BUILD_USER}" "$work_dir"

	# --nodeps breaks the chicken-and-egg cycle: astra-sddm-theme and
	# astra-meta depend on Astra packages that only exist in this repo.
	# Dependencies are still recorded in the package metadata.
	(
		cd "$work_dir" &&
			sudo -u "$BUILD_USER" makepkg --cleanbuild --nodeps --noconfirm
	) || log "warning: ${pkg_name} failed to build"

	find "$work_dir" -maxdepth 1 -name '*.pkg.tar.zst' \
		-exec cp -f {} "$REPO_PATH/" \;
done

log "building AUR packages..."
for pkg in "${AUR_SOURCES[@]}"; do
	# AUR builds are slow (Rust toolchain, 380 MiB NVIDIA blob). Reuse an
	# already built artifact; --clean clears it when a rebuild is wanted.
	if compgen -G "${REPO_PATH}/${pkg}-*.pkg.tar.zst" >/dev/null; then
		log "already built: ${pkg}"
		continue
	fi

	log "building AUR package: ${pkg}"

	work_dir="${TMP_BUILD_DIR}/aur-${pkg}"
	rm -rf -- "$work_dir"
	mkdir -p "$work_dir"
	chown -R "${BUILD_USER}:${BUILD_USER}" "$work_dir"

	(
		cd "$work_dir" &&
			sudo -u "$BUILD_USER" git clone --depth 1 \
				"https://aur.archlinux.org/${pkg}.git" .
	) || {
		log "warning: clone failed for ${pkg}"
		continue
	}

	if [[ ${pkg} == nvidia-580xx-settings ]]; then
		# Its makedepends pull nvidia-580xx-utils, which cannot be installed
		# beside the host's current NVIDIA driver. Build best-effort.
		(
			cd "$work_dir" &&
				sudo -u "$BUILD_USER" env SRCDEST="$SRCDEST" \
					makepkg --nodeps --noconfirm
		) || log "warning: ${pkg} failed to build"
	else
		(
			cd "$work_dir" &&
				sudo -u "$BUILD_USER" env SRCDEST="$SRCDEST" \
					makepkg -s --noconfirm
		) || log "warning: ${pkg} failed to build"
	fi

	find "$work_dir" -maxdepth 1 -name '*.pkg.tar.zst' \
		-exec cp -f {} "$REPO_PATH/" \;
done

log "generating repository database..."
mapfile -d '' repo_packages < <(
	find "$REPO_PATH" -maxdepth 1 -name '*.pkg.tar.zst' -print0
)
((${#repo_packages[@]} > 0)) || die "no packages were built"

repo-add "$DB_PATH" "${repo_packages[@]}"

# The ISO build requires every Astra payload package to be present.
shopt -s nullglob
missing=()
mapfile -t astra_payload <"$astra_list"
for name in "${astra_payload[@]}"; do
	matches=("${REPO_PATH}/${name}"-*.pkg.tar.zst)
	((${#matches[@]} > 0)) || missing+=("$name")
done
shopt -u nullglob

if ((${#missing[@]} > 0)); then
	die "missing Astra packages: ${missing[*]}"
fi

log "offline repository built at ${REPO_PATH}"
log "database: ${REPO_PATH}/astra-local.db"
