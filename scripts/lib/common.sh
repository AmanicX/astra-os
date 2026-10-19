#!/usr/bin/env bash
# Shared helpers for AstraOS build scripts.
#
# Source this file from a script; do not execute it directly.
# The sourcing script is responsible for `set -Eeuo pipefail`.

if [[ -n ${ASTRA_COMMON_SH_LOADED:-} ]]; then
	return 0
fi
ASTRA_COMMON_SH_LOADED=1

COMMON_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly COMMON_DIR
REPO_ROOT="$(cd -- "${COMMON_DIR}/../.." && pwd -P)"
readonly REPO_ROOT
export REPO_ROOT

log() {
	printf '==> %s\n' "$*"
}

warn() {
	printf 'warning: %s\n' "$*" >&2
}

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_tools() {
	local tool
	for tool in "$@"; do
		require_cmd "$tool"
	done
}

# Print a command in dry-run mode; execute it otherwise.
run() {
	if [[ ${DRY_RUN:-0} -eq 1 ]]; then
		printf '+'
		printf ' %q' "$@"
		printf '\n'
	else
		"$@"
	fi
}

as_root() {
	if [[ ${EUID} -eq 0 ]]; then
		"$@"
	else
		sudo "$@"
	fi
}

require_root_or_sudo() {
	if [[ ${EUID} -eq 0 ]]; then
		return 0
	fi
	sudo -n true 2>/dev/null ||
		die "passwordless sudo is not active. Install the build sudoers rule and retry (see docs/PROGRESS.md)."
}

require_arch_host() {
	[[ -r /etc/arch-release ]] || die "this build must run on an Arch Linux host"
	[[ "$(uname -m)" == "x86_64" ]] || die "this build targets x86_64 only"
}

free_gib() {
	local path=$1
	df -Pk -- "$path" | awk 'NR == 2 { printf "%d\n", $4 / 1024 / 1024 }'
}

require_free_gib() {
	local minimum=$1
	local path=$2
	local available
	available="$(free_gib "$path")"
	if ((available < minimum)); then
		die "not enough free space in ${path}: ${available} GiB available, ${minimum} GiB required"
	fi
}

utc_stamp() {
	date -u +%Y%m%dT%H%M%SZ
}

# Print a stable, sorted list of package names from a manifest file.
manifest_packages() {
	local file=$1
	[[ -r ${file} ]] || die "manifest not readable: ${file}"
	awk '!/^[[:space:]]*#/ && NF { print $1 }' "$file"
}

# Union of one or more manifests, preserving first-seen order.
manifest_union() {
	local file
	for file in "$@"; do
		manifest_packages "$file"
	done | awk '!seen[$0]++'
}

# Remove packages listed in an exclusion manifest.
manifest_without() {
	local list=$1
	local exclude=$2
	local tmp
	tmp="$(mktemp)"
	manifest_packages "$list" >"$tmp"
	if [[ -r ${exclude} ]]; then
		manifest_packages "$exclude" | awk 'NR == FNR { skip[$0] = 1; next } !($0 in skip)' - "$tmp"
	else
		cat -- "$tmp"
	fi
	rm -f -- "$tmp"
}
