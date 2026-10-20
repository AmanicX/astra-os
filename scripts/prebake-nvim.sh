#!/usr/bin/env bash
# Pre-bake the pinned Neovim/LazyVim plugin tree for the AstraOS image.
#
# The tree is fetched at the exact commits in manifests/nvim-plugins.tsv and
# shipped read-only at /usr/share/astra/nvim/lazy. The desktop config copies
# it into the user's data directory on first launch so LazyVim can write.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

DEST="${REPO_ROOT}/build/iso/nvim-lazy"
FORCE=0

usage() {
	cat <<'EOF'
Usage: prebake-nvim.sh [--dest DIR] [--force]

  --dest DIR   Destination for the plugin tree (default: build/iso/nvim-lazy).
  --force      Re-fetch every plugin even when a cached copy exists.
  -h, --help   Show this help.
EOF
}

while (($# > 0)); do
	case "$1" in
	--dest)
		[[ $# -ge 2 ]] || die "--dest requires a directory"
		DEST=$2
		shift
		;;
	--force)
		FORCE=1
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

MANIFEST="${REPO_ROOT}/manifests/nvim-plugins.tsv"
[[ -r ${MANIFEST} ]] || die "missing manifest: ${MANIFEST}"

require_tools git

mkdir -p "$DEST"
SOURCES="${DEST}/SOURCES.tsv"
printf 'plugin\tcommit\tremote\tlicense\n' >"$SOURCES"

missing=0
count=0

while IFS=$'\t' read -r plugin commit remote license _license_file; do
	[[ ${plugin} == "plugin" ]] && continue
	[[ -n ${plugin} && -n ${commit} && -n ${remote} ]] || continue

	count=$((count + 1))
	target="${DEST}/${plugin}"

	if ((FORCE == 0)) && [[ -d ${target} ]] &&
		[[ -n $(find "$target" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) ]]; then
		log "cached: ${plugin}"
		printf '%s\t%s\t%s\t%s\n' "$plugin" "$commit" "$remote" "$license" >>"$SOURCES"
		continue
	fi

	log "fetching ${plugin} @ ${commit:0:12}"
	rm -rf -- "$target"
	git init -q "$target"
	git -C "$target" remote add origin "$remote"
	if ! git -C "$target" fetch -q --depth 1 origin "$commit"; then
		# Some servers refuse a direct commit fetch; fall back to a full fetch.
		git -C "$target" fetch -q origin
	fi
	git -C "$target" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD
	rm -rf -- "$target/.git"

	printf '%s\t%s\t%s\t%s\n' "$plugin" "$commit" "$remote" "$license" >>"$SOURCES"
done <"$MANIFEST"

# Every pinned plugin must be present before the ISO can claim LazyVim works.
while IFS=$'\t' read -r plugin _commit _remote _license _license_file; do
	[[ ${plugin} == "plugin" ]] && continue
	[[ -n ${plugin} ]] || continue
	if [[ ! -d ${DEST}/${plugin} ]]; then
		warn "missing plugin: ${plugin}"
		missing=1
	fi
done <"$MANIFEST"

((missing == 0)) || die "the Neovim plugin tree is incomplete"

log "pre-baked ${count} plugins at ${DEST} ($(du -sh "$DEST" | awk '{print $1}'))"
