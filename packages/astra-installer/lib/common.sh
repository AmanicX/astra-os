# Shared helpers for the AstraOS installer.
# Source after the calling script has run `set -Eeuo pipefail`.

if [[ -n ${ASTRA_INSTALLER_COMMON_LOADED:-} ]]; then
	return 0
fi
ASTRA_INSTALLER_COMMON_LOADED=1

# Offline repository and bundled manifest locations.
ASTRA_REPO_DIR="/run/astra-install/repo"
MANIFESTS_DIR="/usr/share/astra/manifests"

# Partition layout globals, filled by partition_and_mount.
MNT_ROOT=""
ESP_PART=""
ROOT_PART=""
ESP_MOUNT="/boot/efi"
GPT_BEFORE=""

STATE_DIR="${STATE_DIR:-/run/astra-install}"
ANSWERS="${ANSWERS:-${STATE_DIR}/answers.json}"
LOG="${LOG:-${STATE_DIR}/install.log}"

# Answers in one place. Passwords are never persisted to disk; they are passed
# directly to chpasswd inside the chroot.
declare -g -A STATE=(
	[kb_layout]="us"
	[kb_variant]=""
	[mirror_regions]=""
	[disk]=""
	[storage_mode]="whole"
	[esp_size]="1G"
	[root_size]=""
	[root_password]=""
	[user_name]="user"
	[user_password]=""
	[user_sudo]="passwordless"
	[extra_packages]=""
	[timezone]="UTC"
	[locale]="en_US.UTF-8"
	[hostname]="astraos"
	[driver_manifests]=""
)

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" >>"${LOG}"; }
warn() { printf 'warning: %s\n' "$*"; }
die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_tools() {
	local tool missing=()
	for tool in "$@"; do
		command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
	done
	((${#missing[@]} == 0)) || die "missing required tools: ${missing[*]}"
}

require_root() { ((EUID == 0)) || die "install must run as root"; }

require_offline_repo() {
	[[ -d "${ASTRA_REPO_DIR}" ]] \
		|| die "offline repository not mounted at ${ASTRA_REPO_DIR}"
	[[ -r "${ASTRA_REPO_DIR}/x86_64/astra-local.db" ]] \
		|| die "offline repository database missing"
}

abort() {
	local lineno=$1 cmd=$2
	log "abort: line ${lineno}: ${cmd}"
	warn "Install cancelled. Log: ${LOG}"
	cleanup_mounts
}

cleanup_mounts() {
	if [[ -n "${MNT_ROOT:-}" && -d "${MNT_ROOT}" ]]; then
		umount --recursive --quiet "${MNT_ROOT}" 2>/dev/null || true
	fi
}

astra_version() {
	local v
	v="$(pacman -Q astra-meta 2>/dev/null | awk '{print $2}' || true)"
	[[ -n ${v} ]] || v="0.1.0"
	printf '%s' "${v}"
}

# Write a minimal offline pacman.conf for pacstrap into the target.
write_offline_pacman_conf() {
	local target_dir=$1
	{
		printf '[options]\nArchitecture = auto\nHoldPkg = pacman glibc\nParallelDownloads = 5\nSigLevel = Optional TrustAll\nLocalFileSigLevel = Optional\nColor\nCheckSpace\n'
		printf '\n[astra-local]\nSigLevel = Optional TrustAll\nServer = file://%s/$arch\n' "${ASTRA_REPO_DIR}"
	} >"${target_dir}/etc/pacman.conf"
}

# Resolve a manifest file shipped with the installer to package names.
manifest_packages() {
	local file=$1
	[[ -r ${file} ]] || die "manifest not readable: ${file}"
	awk '!/^[[:space:]]*#/ && NF { print $1 }' "$file"
}
