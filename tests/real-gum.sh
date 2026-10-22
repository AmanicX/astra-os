#!/usr/bin/env bash
# Real-gum verification of the wizard in a pseudo-terminal.
#
# Two scenarios:
#   success - complete the wizard with the deterministic pre-mounted layout
#             and stop at the dry-run screen
#   back    - press Esc at hostname, verify the step machine walks back to the
#             welcome screen, then confirm the exit path
#
# The system probes (findmnt/mountpoint/df/curl/localectl/timedatectl) are
# fixtures, so this never touches a real disk.  gum, jq and the installer are
# the real binaries.
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixtures="${root}/tests/fixtures/bin"
installer="${root}/packages/astra-installer/astra-install"
logdir=${ASTRA_TEST_LOG_DIR:-${HOME}/astraos-tests}
tmpbin=$(mktemp -d)
trap 'rm -rf -- "$tmpbin"' EXIT

for tool in expect gum jq; do
	command -v "$tool" >/dev/null 2>&1 || {
		printf 'real-gum: missing %s\n' "$tool" >&2
		exit 77
	}
done

mkdir -p "$logdir"

# Only the probes are faked.  gum and jq stay real.
for probe in findmnt mountpoint df curl localectl timedatectl; do
	ln -s "${fixtures}/${probe}" "${tmpbin}/${probe}"
done

run_scenario() {
	local scenario=$1 log state
	log="${logdir}/real-gum-${scenario}.log"
	state="${logdir}/real-gum-${scenario}-state"
	rm -rf -- "$state"
	mkdir -p "$state"
	: >"$log"

	if ! LOG="$log" SCENARIO="$scenario" INSTALLER="$installer" \
		TEST_PATH="${tmpbin}:${PATH}" \
		ASTRA_LIB_DIR="${root}/packages/astra-installer" \
		ASTRA_STATE_DIR="$state" \
		expect -f "${root}/tests/real-gum.expect"; then
		cat "$log" >&2
		return 1
	fi
	printf 'real-gum: %s scenario completed\n' "$scenario"
}

run_scenario success
run_scenario back

logdir_success="${logdir}/real-gum-success.log"
state_success="${logdir}/real-gum-success-state"
state_back="${logdir}/real-gum-back-state"

grep -Fq 'Dry run' "$logdir_success" || {
	cat "$logdir_success" >&2
	printf 'real-gum: success log is missing the dry-run message\n' >&2
	exit 1
}
grep -Fq 'Pre-mounted root at' "$logdir_success" || {
	cat "$logdir_success" >&2
	printf 'real-gum: success log is missing the pre-mounted summary\n' >&2
	exit 1
}
jq -e '.storage.mode == "premounted"' "${state_success}/answers.json" >/dev/null || {
	printf 'real-gum: answers.json does not record premounted storage\n' >&2
	exit 1
}
grep -Fq 'user chose to exit at the welcome screen' "${state_back}/install.log" || {
	cat "${state_back}/install.log" >&2
	printf 'real-gum: back-navigation run did not take the confirmed exit path\n' >&2
	exit 1
}
[[ $(grep -c 'Storage setup' "${logdir}/real-gum-back.log") -ge 2 ]] || {
	cat "${logdir}/real-gum-back.log" >&2
	printf 'real-gum: back-navigation did not return to the storage step\n' >&2
	exit 1
}
[[ ! -e ${state_back}/answers.json ]] || {
	printf 'real-gum: back-navigation run unexpectedly wrote answers.json\n' >&2
	exit 1
}

printf 'real-gum: ok (logs in %s)\n' "$logdir"
