#!/usr/bin/env bash
# Full wizard flow with a deterministic gum and a pre-mounted layout.
# This never touches a disk: it stops after the review screen because
# ASTRA_DRY_RUN=1.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
installer="${root}/packages/astra-installer/astra-install"
fixtures="${root}/tests/fixtures/bin"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
chmod +x "$fixtures"/*

queue="${tmp}/gum-queue"
{
	printf '%s\n' yes
	printf '%s\n' us
	printf '%s\n' 'Worldwide mirrors'
	printf '%s\n' 'Worldwide'
	printf '%s\n' 'Use a pre-mounted system'
	printf '%s\n' /mnt
	printf '%s\n' yes
	printf '%s\n' astraos
	printf '%s\n' rootpass
	printf '%s\n' rootpass
	printf '%s\n' user
	printf '%s\n' userpass
	printf '%s\n' userpass
	printf '%s\n' 'Passwordless sudo (recommended)'
	printf '%s\n' UTC
	printf '%s\n' en_US.UTF-8
	printf '%s\n' ''
	printf '%s\n' INSTALL
	printf '%s\n' yes
} >"$queue"

set +e
PATH="${fixtures}:${PATH}" \
	GUM_QUEUE="$queue" \
	ASTRA_LIB_DIR="${root}/packages/astra-installer" \
	ASTRA_STATE_DIR="${tmp}/state" \
	ASTRA_DRY_RUN=1 \
	ASTRA_SKIP_UEFI=1 \
	ASTRA_SKIP_TOOLS=1 \
	ASTRA_SKIP_ROOT=1 \
	bash "$installer" >"${tmp}/wizard.log" 2>&1
status=$?
set -e

if ((status != 0)); then
	cat "${tmp}/wizard.log"
	printf 'wizard exited with %s\n' "$status" >&2
	exit 1
fi

grep -Fq 'Dry run complete' "${tmp}/wizard.log" || {
	cat "${tmp}/wizard.log"
	printf 'dry-run completion message missing\n' >&2
	exit 1
}
grep -Fq 'Pre-mounted root at `/mnt`' "${tmp}/wizard.log" || {
	cat "${tmp}/wizard.log"
	printf 'expected the pre-mounted storage summary\n' >&2
	exit 1
}
if [[ -s $queue ]]; then
	printf 'unused fake-gum responses:\n' >&2
	cat "$queue" >&2
	exit 1
fi

printf 'wizard-dry-run: ok\n'
