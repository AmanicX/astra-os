#!/usr/bin/env bash
# Run the complete installer verification suite and keep one log.
#
# Run as root inside an Arch Linux environment (WSL or the live ISO):
#   ASTRA_TEST_LOG_DIR=/home/astra/astraos-tests bash tests/run-all.sh
#
# The storage tests only touch loopback image files under /var/tmp.
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
logdir=${ASTRA_TEST_LOG_DIR:-${HOME}/astraos-tests}
stamp=$(date -u +%Y%m%dT%H%M%SZ)
log="${logdir}/run-all-${stamp}.log"
failures=0

mkdir -p "$logdir" || exit 1
exec > >(tee -a "$log") 2>&1

section() {
	printf '\n===== %s =====\n' "$*"
}

run() {
	local name=$1
	shift
	section "$name"
	if "$@"; then
		printf '%s: ok\n' "$name"
	else
		printf '%s: FAILED\n' "$name" >&2
		failures=$((failures + 1))
	fi
}

shell_files=(
	packages/astra-installer/astra-install
	packages/astra-installer/astra-pending-packages.sh
	packages/astra-installer/lib/common.sh
	packages/astra-installer/lib/hw.sh
	packages/astra-installer/lib/install.sh
	packages/astra-installer/lib/mirrors.sh
	packages/astra-installer/lib/storage.sh
	packages/astra-updater/astra-updater
	scripts/build-iso.sh
	scripts/build-repo.sh
	scripts/prebake-nvim.sh
	scripts/render-branding.sh
	scripts/scrub-check.sh
	scripts/setup-git.sh
	scripts/lib/common.sh
	scripts/lib/manifests.sh
	scripts/lib/brand.sh
	scripts/rebrand-archiso.sh
	config/live/airootfs/root/customize_airootfs.sh
	tests/static-guards.sh
	tests/wizard-dry-run.sh
	tests/real-gum.sh
	tests/storage-loop-test.sh
	tests/branding-test.sh
	tests/run-all.sh
	tests/wsl-setup.sh
)

cd "$root" || exit 1
printf 'AstraOS installer verification\n'
printf 'root: %s\n' "$root"
printf 'log: %s\n' "$log"

section "bash syntax"
for file in "${shell_files[@]}"; do
	if ! bash -n "$file"; then
		printf 'syntax: FAILED %s\n' "$file" >&2
		failures=$((failures + 1))
	fi
done
printf 'bash syntax: checked %s files\n' "${#shell_files[@]}"

run shellcheck shellcheck -x -a "${shell_files[@]}"
run shfmt shfmt -d "${shell_files[@]}"
run static-guards bash tests/static-guards.sh
run branding bash tests/branding-test.sh
run wizard-dry-run bash tests/wizard-dry-run.sh
run real-gum bash tests/real-gum.sh

if ((EUID == 0)); then
	run storage-loop bash tests/storage-loop-test.sh
else
	section "storage-loop"
	printf 'storage-loop: skipped (run tests/run-all.sh as root)\n'
fi

section "result"
if ((failures > 0)); then
	printf 'run-all: FAILED (%s failure(s)); log: %s\n' "$failures" "$log" >&2
	exit 1
fi
printf 'run-all: PASS; log: %s\n' "$log"
