# Shared helpers for the AstraOS installer.
#
# The installer is intentionally written in the same spirit as archinstall:
# every destructive action is an explicit choice, nothing is formatted before
# the final confirmation, and the user can always back out of a menu with Esc.
#
# Source this file after the calling script has declared its globals.  The
# calling script deliberately does NOT use `set -e`; user cancellation and
# optional commands (grep, blkid, probe helpers) return non-zero constantly and
# must not tear the UI down.  Fatal paths call `die`.

if [[ -n ${ASTRA_INSTALLER_COMMON_LOADED:-} ]]; then
	return 0
fi
ASTRA_INSTALLER_COMMON_LOADED=1

# Bundled repository and manifest locations on the live ISO.
ASTRA_REPO_DIR="/usr/share/astra/repo"
ASTRA_DATA_DIR="/usr/share/astra"
MANIFESTS_DIR="${ASTRA_DATA_DIR}/manifests"
SNAPSHOT_FILE="${ASTRA_DATA_DIR}/snapshot"

# Partition/mount globals, filled by the storage layer.
MNT_ROOT="/mnt"
ESP_PART=""
ROOT_PART=""
ESP_MOUNT="/boot/efi"
GPT_BASELINE_FILE=""
MOUNTS_CREATED=0
KEEP_MOUNTS=0

# Runtime files.
STATE_DIR="${STATE_DIR:-/run/astra-install}"
ANSWERS="${ANSWERS:-${STATE_DIR}/answers.json}"
LOG="${LOG:-${STATE_DIR}/install.log}"
PACMAN_CONF="${PACMAN_CONF:-${STATE_DIR}/pacman.conf}"
TARGET_SCRIPT="${TARGET_SCRIPT:-${STATE_DIR}/target-setup.sh}"

# UI / flow globals.
STEP=0
CURRENT_STEP=""
TOTAL_STEPS=9
DIE_PAUSED=0
INTERRUPTED=0
WIZARD_ACTIVE=1
INTERACTIVE=1
if [[ ! -t 0 || ! -t 1 ]]; then
	INTERACTIVE=0
fi

# Answers in one place.  Passwords are never written to answers.json; they are
# only handed to chpasswd inside the target chroot.
declare -g -A STATE=(
	[kb_layout]="us"
	[kb_variant]=""
	[mirror_source]="ala"
	[mirror_region]="Worldwide"
	[storage_mode]=""
	[disk]=""
	[disk_size]=""
	[storage_note]=""
	[esp_mode]=""
	[esp_size]="1G"
	[esp_mount]="/boot/efi"
	[root_part]=""
	[esp_part]=""
	[free_start]=""
	[free_end]=""
	[free_mib]=""
	[format_root]="no"
	[format_esp]="no"
	[premounted_root]=""
	[premounted_esp]=""
	[root_password]=""
	[user_name]=""
	[user_password]=""
	[user_sudo]="passwordless"
	[extra_packages]=""
	[timezone]="UTC"
	[locale]="en_US.UTF-8"
	[hostname]="astraos"
	[driver_manifests]=""
)

log() {
	mkdir -p "${STATE_DIR}" 2>/dev/null || true
	printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"${LOG}" 2>/dev/null || true
}

warn() {
	printf 'warning: %s\n' "$*" >&2
	log "warning: $*"
}

die() {
	printf 'error: %s\n' "$*" >&2
	log "error: $*"
	if declare -F cleanup_mounts >/dev/null 2>&1; then
		cleanup_mounts
	fi
	if ((INTERACTIVE == 1 && DIE_PAUSED == 0)); then
		DIE_PAUSED=1
		printf '\n' >&2
		gum style --foreground 196 --margin 1 "Installer stopped" "Reason: $*" "Log: ${LOG}" 2>/dev/null ||
			printf 'Log: %s\n' "${LOG}" >&2
		printf '\nPress Enter to close the installer...' >&2
		read -r _ || true
	fi
	exit 1
}

# Fired from the EXIT trap.  This is what keeps the kitty window open with a
# readable message instead of vanishing after a failed install.
on_exit() {
	local status=$?
	if ((status != 0)); then
		if declare -F cleanup_mounts >/dev/null 2>&1; then
			cleanup_mounts
		fi
	fi
	if ((status != 0 && DIE_PAUSED == 0 && INTERACTIVE == 1)); then
		DIE_PAUSED=1
		printf '\n' >&2
		printf 'Installer exited with status %s. Log: %s\n' "$status" "$LOG" >&2
		printf 'Press Enter to close...' >&2
		read -r _ || true
	fi
	# Do not let a failed command in this trap mask the real status.
	return 0
}

abort_user() {
	log "interrupt received"
	if ((WIZARD_ACTIVE == 1)); then
		# During question screens there may be no mounts yet.  Let the
		# interrupted gum/read return non-zero and let the step machine go
		# back one screen instead of closing the terminal.
		INTERRUPTED=1
		printf '\nInterrupted; returning to the previous step...\n' >&2
		return 0
	fi
	trap - INT TERM
	printf '\n' >&2
	log "cancelled by user during install"
	cleanup_mounts
	if ((INTERACTIVE == 1)); then
		DIE_PAUSED=1
		printf 'Installation cancelled.\nLog: %s\nPress Enter to close...' "$LOG" >&2
		read -r _ || true
	fi
	exit 130
}

pause() {
	if ((INTERACTIVE == 1)); then
		printf '\nPress Enter to continue...'
		read -r _ || true
	fi
}

require_root() {
	if [[ ${ASTRA_SKIP_ROOT:-0} == 1 ]]; then
		warn "root check skipped because ASTRA_SKIP_ROOT=1 (test mode only)"
		return 0
	fi
	((EUID == 0)) || die "installer must run as root (try: sudo astra-install)"
}

require_tools() {
	if [[ ${ASTRA_SKIP_TOOLS:-0} == 1 ]]; then
		warn "tool check skipped because ASTRA_SKIP_TOOLS=1 (test mode only)"
		return 0
	fi
	local tool missing=()
	for tool in "$@"; do
		command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
	done
	((${#missing[@]} == 0)) ||
		die "missing required tools: ${missing[*]}"
}

# ---------------------------------------------------------------------------
# UI wrappers.  gum returns non-zero when the user presses Esc / answers No.
# Every wrapper returns that status to the caller instead of aborting the
# script, so an accidental Esc does not close the installer.
# ---------------------------------------------------------------------------

ui_choose() {
	local header=$1
	shift
	local height=${ASTRA_UI_HEIGHT:-14}
	gum choose --header "$header" --cursor.foreground 117 \
		--height "$height" -- "$@"
}

ui_filter() {
	local header=$1
	shift
	local placeholder=${1:-"Type to search..."}
	gum filter --header "$header" --placeholder "$placeholder" --height 15
}

ui_input() {
	local prompt=$1
	local placeholder=${2:-}
	local value=${3:-}
	if [[ -n ${value} ]]; then
		gum input --prompt "${prompt}: " --placeholder "$placeholder" --value "$value"
	else
		gum input --prompt "${prompt}: " --placeholder "$placeholder"
	fi
}

ui_password() {
	local prompt=$1
	# gum has no `password` subcommand; input --password is the supported form.
	# The old installer's `gum input` failure is exactly what set -e turned into
	# a silent exit, so keep this wrapper's status intact for the step machine.
	gum input --password --prompt "${prompt}: "
}

ui_confirm() {
	local question=$1
	local yes=${2:-"Yes"}
	local no=${3:-"No"}
	gum confirm --affirmative "$yes" --negative "$no" -- "$question"
}

ui_markdown() {
	gum format --type markdown -- "$@"
}

# A small header shown at the start of every step.
step_header() {
	local title=$1
	if [[ -n ${CURRENT_STEP:-} ]]; then
		STEP=$CURRENT_STEP
	else
		STEP=$((STEP + 1))
	fi
	clear
	gum style --foreground 117 --align center --width 66 --margin 1 \
		"AstraOS installer" \
		"Step ${STEP}/${TOTAL_STEPS} • ${title}" 2>/dev/null || {
		printf '=== AstraOS installer: %s (%s/%s) ===\n' "$title" "$STEP" "$TOTAL_STEPS"
	}
}

# ---------------------------------------------------------------------------
# Validation helpers.
# ---------------------------------------------------------------------------

validate_hostname() {
	local host=$1
	[[ ${#host} -ge 1 && ${#host} -le 63 ]] || return 1
	[[ $host =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] || return 1
	[[ $host != *..* ]] || return 1
	return 0
}

validate_username() {
	local user=$1
	[[ ${#user} -ge 1 && ${#user} -le 32 ]] || return 1
	[[ $user =~ ^[a-z_][a-z0-9_-]*$ ]] || return 1
	[[ $user != root ]] || return 1
	return 0
}

validate_timezone() {
	local tz=$1
	[[ -n $tz && -e "/usr/share/zoneinfo/${tz}" ]]
}

validate_locale() {
	local loc=$1
	[[ $loc =~ ^[A-Za-z0-9_]+\.UTF-8$ || $loc == "C.UTF-8" ]]
}

validate_password() {
	local pass=$1
	[[ -n $pass && $pass != *$'\n'* && $pass != *$'\r'* ]]
}

# ---------------------------------------------------------------------------
# Runtime setup.
# ---------------------------------------------------------------------------

init_runtime() {
	STATE_DIR=${ASTRA_STATE_DIR:-/run/astra-install}
	ANSWERS="${STATE_DIR}/answers.json"
	LOG="${STATE_DIR}/install.log"
	PACMAN_CONF="${STATE_DIR}/pacman.conf"
	TARGET_SCRIPT="${STATE_DIR}/target-setup.sh"
	mkdir -p "${STATE_DIR}" || die "cannot create ${STATE_DIR}"
	: >"${LOG}" || die "cannot write ${LOG}"
	chmod 700 "${STATE_DIR}" 2>/dev/null || true
	log "AstraOS installer started"
	log "command: ${0} ${*:-}"
}

check_uefi() {
	if [[ ${ASTRA_SKIP_UEFI:-0} == 1 ]]; then
		warn "UEFI check skipped because ASTRA_SKIP_UEFI=1 (test mode only)"
		return 0
	fi
	[[ -d /sys/firmware/efi ]] ||
		die "AstraOS is UEFI-only. Boot the USB in UEFI mode (disable CSM/Legacy)."
}

astra_version() {
	local v
	v="$(pacman -Q astra-meta 2>/dev/null | awk '{print $2}' || true)"
	[[ -n ${v:-} ]] || v="0.1.0"
	printf '%s' "${v}"
}

# ---------------------------------------------------------------------------
# Answers file.  Passwords are intentionally omitted.
# ---------------------------------------------------------------------------

dump_answers() {
	mkdir -p "${STATE_DIR}" 2>/dev/null || true
	jq -n \
		--arg kb "${STATE[kb_layout]}" \
		--arg mirror_source "${STATE[mirror_source]}" \
		--arg mirror_region "${STATE[mirror_region]}" \
		--arg storage_mode "${STATE[storage_mode]}" \
		--arg disk "${STATE[disk]}" \
		--arg root_part "${STATE[root_part]}" \
		--arg esp_part "${STATE[esp_part]}" \
		--arg esp_mount "${STATE[esp_mount]}" \
		--arg premounted_root "${STATE[premounted_root]}" \
		--arg hostname "${STATE[hostname]}" \
		--arg user_name "${STATE[user_name]}" \
		--arg user_sudo "${STATE[user_sudo]}" \
		--arg timezone "${STATE[timezone]}" \
		--arg locale "${STATE[locale]}" \
		--arg extra "${STATE[extra_packages]}" \
		'{
			keyboard: $kb,
			mirror: { source: $mirror_source, region: $mirror_region },
			storage: {
				mode: $storage_mode,
				disk: $disk,
				root_partition: $root_part,
				esp_partition: $esp_part,
				esp_mount: $esp_mount,
				premounted_root: $premounted_root
			},
			hostname: $hostname,
			user: { name: $user_name, sudo: $user_sudo },
			timezone: $timezone,
			locale: $locale,
			extra_packages: $extra
		}' >"${ANSWERS}" 2>/dev/null || warn "could not write ${ANSWERS}"
}
