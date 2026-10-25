#!/usr/bin/env bash
# ==============================================================================
#  ✦ Astra Linux — Quick Bootstrap Installer
#  https://github.com/AmanicX/astra-os
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/AmanicX/astra-os/main/install.sh | bash
#    or:
#    bash -c "$(curl -fsSL https://raw.githubusercontent.com/AmanicX/astra-os/main/install.sh)"
# ==============================================================================

set -Eeuo pipefail

# Re-attach standard input to terminal if piped through curl
if [[ ! -t 0 && -e /dev/tty ]]; then
	exec < /dev/tty
fi

# Palette
if [[ -t 1 ]]; then
	C_CYAN="\033[38;2;94;230;242m"
	C_GOLD="\033[38;2;230;164;90m"
	C_RESET="\033[0m"
	C_BOLD="\033[1m"
	C_RED="\033[38;2;240;80;80m"
	C_MUTED="\033[38;2;142;158;169m"
else
	C_CYAN=""
	C_GOLD=""
	C_RESET=""
	C_BOLD=""
	C_RED=""
	C_MUTED=""
fi

# 1. Root check
if [[ ${EUID} -eq 0 && -z ${SUDO_USER:-} ]]; then
	printf "${C_RED}${C_BOLD}Error:${C_RESET} Do not run this installer directly as root.\nPlease run as your regular user with sudo permissions:\n  curl -fsSL https://raw.githubusercontent.com/AmanicX/astra-os/main/install.sh | bash\n" >&2
	exit 1
fi

# 2. Local repository detection (if cloned locally)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P || true)"
if [[ -n "${SCRIPT_DIR}" && -f "${SCRIPT_DIR}/setup.sh" && -d "${SCRIPT_DIR}/packages" ]]; then
	exec bash "${SCRIPT_DIR}/setup.sh" "$@"
fi

# 3. Remote execution banner
cat <<EOF

${C_CYAN}${C_BOLD}   ___       __             ____  _____ ${C_RESET}
${C_CYAN}${C_BOLD}  /   | ___ / /_________ _ / __ \/ ___/ ${C_RESET}
${C_CYAN}${C_BOLD} / /| |/ __/ __/ __/ __ \`// / / /\__ \  ${C_RESET}
${C_CYAN}${C_BOLD}/ ___ /\_ \/ /_/ / / /_/ // /_/ /___/ /  ${C_RESET}
${C_CYAN}${C_BOLD}/_/  |_/___/\__/_/  \__,_/ \____//____/   ${C_RESET}
${C_GOLD}   ✦  A S T R A L   M E R I D I A N  ✦   ${C_RESET}
${C_MUTED}   Arch Linux Desktop Environment Installer${C_RESET}

EOF

printf "${C_CYAN}✦${C_RESET} Preparing Astra Linux setup environment...\n"

TARGET_DIR="/tmp/astra-os"
rm -rf "${TARGET_DIR}"

if command -v git >/dev/null 2>&1; then
	printf "${C_CYAN}✦${C_RESET} Fetching repository via Git...\n"
	git clone --depth 1 https://github.com/AmanicX/astra-os.git "${TARGET_DIR}"
elif command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
	printf "${C_CYAN}✦${C_RESET} Git not found; downloading archive via curl...\n"
	mkdir -p "${TARGET_DIR}"
	curl -fsSL https://github.com/AmanicX/astra-os/archive/refs/heads/main.tar.gz | tar -xz -C "${TARGET_DIR}" --strip-components=1
else
	printf "${C_RED}${C_BOLD}Error:${C_RESET} Neither git nor curl+tar was found. Please install git or curl:\n  sudo pacman -S --needed git\n" >&2
	exit 1
fi

chmod +x "${TARGET_DIR}/setup.sh"
cd "${TARGET_DIR}"
exec ./setup.sh "$@"
