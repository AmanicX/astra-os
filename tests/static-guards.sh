#!/usr/bin/env bash
# Fast, non-destructive checks for the safety invariants that regressed in the
# old installer.  These are intentionally simple greps so they run before any
# privileged or interactive test.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
installer="${root}/packages/astra-installer/astra-install"
lib="${root}/packages/astra-installer/lib"
fail=0

check_file() {
	local file=$1 pattern=$2 message=$3
	if ! grep -Eq -- "$pattern" "$file"; then
		printf 'FAIL: %s (%s)\n' "$message" "$file" >&2
		fail=1
	fi
}

check_absent() {
	local file=$1 pattern=$2 message=$3
	if grep -Eq -- "$pattern" "$file"; then
		printf 'FAIL: %s (%s)\n' "$message" "$file" >&2
		fail=1
	fi
}

# The wizard must not inherit set -e: gum returns non-zero on Esc.  Match the
# option letters only, so `set -uo pipefail` is not mistaken for `set -e`.
check_absent "$installer" '^[[:space:]]*set[[:space:]]+-[[:alpha:]]*e[[:alpha:]]*([[:space:]]|$)' \
	'the installer must not use set -e'

# gum 2.0.2 has no `gum password` subcommand.
check_absent "${lib}/common.sh" 'gum password' 'gum password is not a command'
check_file "${lib}/common.sh" 'gum input --password' 'password input must use gum input --password'

check_file "${lib}/storage.sh" 'MIN_INSTALL_GIB=.*35' 'minimum target capacity must be 35 GiB'
check_file "${lib}/storage.sh" 'MIN_ROOT_GIB=.*MIN_INSTALL_GIB' 'root minimum must derive from total capacity'
check_file "${lib}/storage.sh" 'RECOMMENDED_INSTALL_GIB=.*40' 'recommended install size must be 40 GiB'
check_file "${lib}/storage.sh" 'verify_install_target' 'target mount/free-space verification is required'
check_file "${lib}/install.sh" 'pacstrap_args=\(-C "\$PACMAN_CONF" -M\)' \
	'pacstrap must use the target package cache, not the live overlay'
check_absent "${lib}/install.sh" 'pacstrap_args=.*-c' \
	'pacstrap -c uses the tiny live overlay and must not be enabled'
check_file "${lib}/storage.sh" 'snapshot_gpt' 'GPT snapshot function is required'
check_file "${lib}/storage.sh" 'show_gpt_diff' 'cfdisk diff display is required'
check_file "${lib}/storage.sh" 'verify_gpt_unchanged' 'existing GPT verification is required'
check_file "${lib}/storage.sh" 'verify_new_partition' 'new partition geometry/type verification is required'
check_file "${lib}/storage.sh" 'verify_filesystem' 'filesystem verification is required'
check_file "${lib}/storage.sh" 'first_mib_hash' 'first-MiB hashing is required'
check_file "${lib}/storage.sh" 'for candidate in "\$root/boot/efi" "\$root/boot" "\$root/efi"' \
	'pre-mounted ESP detection must be limited to the three approved paths'
check_file "${lib}/storage.sh" '\*\*Kept:\*\*' 'summary must state what is kept'
check_file "${lib}/storage.sh" '\*\*Created:\*\*' 'summary must state what is created'
check_file "${lib}/storage.sh" '\*\*Erased' 'summary must state what is erased'

# The old regional pkgbuild hostnames do not resolve.
check_absent "${lib}/mirrors.sh" 'https://(de|fr|nl|us|sg|jp|au|br|za)\.mirror\.pkgbuild\.com' \
	'invalid regional pkgbuild mirror hostname'

if ((fail != 0)); then
	exit 1
fi
printf 'static-guards: ok\n'
