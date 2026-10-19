#!/usr/bin/env bash
# Scan AstraOS-owned content for secrets and personal identifiers.
#
# Usage:
#   scripts/scrub-check.sh [PATH ...]
#   scripts/scrub-check.sh --iso ISO_ROOT [--full]
#
# The repository scan covers the whole repository. The ISO scan defaults to
# Astra-owned paths only, because a full Arch ISO contains upstream package
# metadata and license files. Use --full for an exhaustive investigation.
#
# Identity values are never committed. They come from, in order:
#   ASTRA_SCRUB_IDENTITIES (space-separated)
#   ASTRA_SCRUB_IDENTITIES_FILE (default: $XDG_CONFIG_HOME/astra/scrub-identities)
#   the current login, /etc/hostname and $HOME (generic build identities skipped)
#
# Exit status: 0 = clean, 1 = findings, 2 = operational error.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly REPO_ROOT

readonly TOKEN_RE='(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
readonly EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

status=0
scan_iso=0
full=0
paths=()

usage() {
	cat <<'EOF'
Usage: scrub-check.sh [OPTIONS] [PATH ...]

Options:
  --iso       Treat PATH as an ISO root; scan Astra-owned paths by default.
  --full      With --iso, scan the whole ISO root.
  -h, --help  Show this help.

Without PATH, the repository root is scanned.
EOF
}

log() {
	printf '%s\n' "$*" >&2
}

record_failure() {
	log "SCRUB FAIL: $*"
	status=1
}

record_error() {
	log "SCRUB ERROR: $*"
	status=2
}

while (($# > 0)); do
	case "$1" in
	--iso)
		scan_iso=1
		shift
		;;
	--full)
		full=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	--)
		shift
		while (($# > 0)); do
			paths+=("$1")
			shift
		done
		;;
	-*)
		log "Unknown option: $1"
		usage
		exit 2
		;;
	*)
		paths+=("$1")
		shift
		;;
	esac
done

if ((${#paths[@]} == 0)); then
	if ((scan_iso)); then
		log "ERROR: --iso requires an ISO root path"
		exit 2
	fi
	paths=("$REPO_ROOT")
fi

for path in "${paths[@]}"; do
	if [[ ! -e "$path" ]]; then
		log "ERROR: path not found: $path"
		exit 2
	fi
done

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/astra-scrub.XXXXXX")"
# shellcheck disable=SC2317  # invoked by the EXIT trap below
cleanup() {
	rm -rf -- "$tmpdir"
}
trap cleanup EXIT

identity_file="$tmpdir/identities"
: >"$identity_file"

add_identity() {
	local value="$1"
	[[ -n "$value" ]] || return 0
	printf '%s\n' "$value" >>"$identity_file"
}

if [[ -n "${ASTRA_SCRUB_IDENTITIES:-}" ]]; then
	read -r -a identities <<<"${ASTRA_SCRUB_IDENTITIES}"
	for identity in "${identities[@]}"; do
		add_identity "$identity"
	done
fi

configured_identities="${ASTRA_SCRUB_IDENTITIES_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/astra/scrub-identities}"
if [[ -f "$configured_identities" ]]; then
	while IFS= read -r line; do
		[[ -z "$line" || "$line" == \#* ]] && continue
		add_identity "$line"
	done <"$configured_identities"
fi

current_user="$(id -un 2>/dev/null || true)"
case "$current_user" in
"" | root | builder | astra | liveuser) ;;
*) add_identity "$current_user" ;;
esac

if [[ -r /etc/hostname ]]; then
	current_host="$(</etc/hostname)"
	case "$current_host" in
	"" | localhost | localhost.localdomain) ;;
	*) add_identity "$current_host" ;;
	esac
fi

case "${HOME:-}" in
"" | /root | /home/builder | /home/astra | /home/liveuser) ;;
*) add_identity "$HOME" ;;
esac

# Drop duplicates and very short values that would create noise.
awk 'length($0) >= 3 && !seen[$0]++' "$identity_file" >"$tmpdir/identities.clean" || true
mv "$tmpdir/identities.clean" "$identity_file"

if [[ -s "$identity_file" ]]; then
	log "Identity patterns: $(wc -l <"$identity_file")"
else
	log "WARNING: no identity patterns configured; identity scan will be skipped"
fi

# Common exclusions. The scanner itself is excluded because its regex text
# intentionally contains the patterns it searches for.
common_excludes=(
	--exclude-dir=.git
	--exclude-dir=node_modules
	--exclude-dir=.cache
	--exclude-dir=build
	--exclude-dir=out
	--exclude=scrub-check.sh
)

check_regex() {
	local label="$1"
	local regex="$2"
	local path="$3"
	local rc=0

	grep -rInE "${common_excludes[@]}" -- "$regex" "$path" || rc=$?
	if ((rc == 0)); then
		record_failure "$label in $path"
	elif ((rc > 1)); then
		record_error "grep failed while checking $label in $path"
	fi
}

check_identities() {
	local path="$1"
	local rc=0

	if [[ ! -s "$identity_file" ]]; then
		return 0
	fi

	grep -rInF "${common_excludes[@]}" -f "$identity_file" -- "$path" || rc=$?
	if ((rc == 0)); then
		record_failure "personal identifier in $path"
	elif ((rc > 1)); then
		record_error "grep failed while checking identities in $path"
	fi
}

check_filenames() {
	local path="$1"
	local file

	while IFS= read -r file; do
		record_failure "forbidden file: $file"
	done < <(
		find "$path" -type f \
			\( -name 'auth.json' \
			-o -name 'service.json' \
			-o -name '*.key' \
			-o -name '*.pem' \
			-o -name '*.p12' \
			-o -name '*.pfx' \
			-o -name '.netrc' \
			-o -name '.env' \
			-o -name '*.env' \
			-o -name 'id_rsa' \
			-o -name 'id_ed25519' \
			-o -name 'id_ecdsa' \
			-o -name 'login.keyring' \
			-o -name 'user.keystore' \
			-o -name 'opencode.db' \
			-o -name 'opencode.db-wal' \
			-o -name 'opencode.db-shm' \
			-o -name 'cookies.sqlite' \
			-o -name 'logins.json' \
			-o -name 'places.sqlite' \
			-o -name '.git-credentials' \) \
			-print 2>/dev/null
	)
}

scan_path() {
	local path="$1"

	log "Scanning: $path"
	check_regex "token-like string" "$TOKEN_RE" "$path"
	check_regex "email address" "$EMAIL_RE" "$path"
	check_identities "$path"
	check_filenames "$path"
}

if ((scan_iso)); then
	for iso_root in "${paths[@]}"; do
		if [[ ! -d "$iso_root" ]]; then
			log "ERROR: ISO root is not a directory: $iso_root"
			exit 2
		fi

		if ((full)); then
			scan_path "$iso_root"
			continue
		fi

		for relative in \
			etc/skel \
			etc/astra \
			etc/os-release \
			etc/lsb-release \
			etc/issue \
			etc/sddm.conf \
			etc/sddm.conf.d \
			usr/share/astra \
			usr/share/sddm/themes \
			usr/local; do
			if [[ -e "$iso_root/$relative" ]]; then
				scan_path "$iso_root/$relative"
			fi
		done
	done
else
	for path in "${paths[@]}"; do
		scan_path "$path"
	done
fi

if ((status == 0)); then
	log "SCRUB OK"
elif ((status == 1)); then
	log "SCRUB FAILED: remove or sanitize the findings above"
else
	log "SCRUB ERROR: an operational error occurred"
fi

exit "$status"
