#!/usr/bin/env bash
# ==============================================================================
#  ✦ Astra Linux — Desktop Setup & Configuration Script
#  https://github.com/AmanicX/astra-os
#
#  Transforms a minimal Arch Linux installation into a fully-configured
#  Astra Linux desktop featuring Niri, Noctalia, Kitty, LazyVim, Opencode,
#  Oh-My-Posh Zsh, SilentSDDM, Plymouth, and cosmic GRUB theming.
# ==============================================================================

set -Eeuo pipefail
# shellcheck disable=SC2059

# --- Palette & Styling (Astral Meridian) --------------------------------------
if [[ -t 1 ]]; then
	readonly C_RESET="\033[0m"
	readonly C_BOLD="\033[1m"
	readonly C_DIM="\033[2m"
	# Void / Accent Cyan (#5ee6f2)
	readonly C_CYAN="\033[38;2;94;230;242m"
	# Solar Gold (#e6a45a)
	readonly C_GOLD="\033[38;2;230;164;90m"
	# Starlight (#e8edf7)
	readonly C_STAR="\033[38;2;232;237;247m"
	# Muted Slate (#8e9ea9)
	readonly C_MUTED="\033[38;2;142;158;169m"
	# Status Colors
	readonly C_GREEN="\033[38;2;80;227;145m"
	readonly C_RED="\033[38;2;240;80;80m"
	readonly C_YELLOW="\033[38;2;245;200;80m"
else
	readonly C_RESET=""
	readonly C_BOLD=""
	readonly C_DIM=""
	readonly C_CYAN=""
	readonly C_GOLD=""
	readonly C_STAR=""
	readonly C_MUTED=""
	readonly C_GREEN=""
	readonly C_RED=""
	readonly C_YELLOW=""
fi

# --- Global Paths & Directory Discovery ---------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly REPO_ROOT="${SCRIPT_DIR}"
readonly PACKAGES_DIR="${REPO_ROOT}/packages"

TARGET_USER="${SUDO_USER:-${USER}}"
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
readonly TARGET_USER TARGET_HOME

# --- Options / State ----------------------------------------------------------
OPT_AUR="paru"        # paru | yay | skip
OPT_BROWSER="firefox" # firefox | helium | chromium | brave | none
OPT_DRIVERS="yes"     # yes | no
OPT_REBRAND="yes"     # yes | no
OPT_GRUB="yes"        # yes | no
OPT_PLYMOUTH="yes"    # yes | no
OPT_SDDM="yes"        # yes | no
OPT_DOTFILES="yes"    # yes | no
OPT_NONINTERACTIVE=0

# --- Helper Functions ---------------------------------------------------------
print_banner() {
	clear 2>/dev/null || true
	cat <<EOF

${C_CYAN}${C_BOLD}   ___       __             ____  _____ ${C_RESET}
${C_CYAN}${C_BOLD}  /   | ___ / /_________ _ / __ \/ ___/ ${C_RESET}
${C_CYAN}${C_BOLD} / /| |/ __/ __/ __/ __ \`// / / /\__ \  ${C_RESET}
${C_CYAN}${C_BOLD}/ ___ /\_ \/ /_/ / / /_/ // /_/ /___/ /  ${C_RESET}
${C_CYAN}${C_BOLD}/_/  |_/___/\__/_/  \__,_/ \____//____/   ${C_RESET}
${C_GOLD}   ✦  A S T R A L   M E R I D I A N  ✦   ${C_RESET}
${C_MUTED}   Arch Linux Desktop Environment Setup  ${C_RESET}

EOF
}

step_header() {
	local step="$1"
	local total="$2"
	local title="$3"
	printf "\n${C_CYAN}${C_BOLD}╭─ [${step}/${total}] ${C_STAR}%s${C_RESET}\n" "${title}"
}

step_info() {
	printf "${C_CYAN}│${C_RESET}  ${C_MUTED}%s${C_RESET}\n" "$*"
}

step_item() {
	printf "${C_CYAN}│${C_RESET}  ${C_GOLD}✦${C_RESET} %s\n" "$*"
}

step_success() {
	printf "${C_CYAN}│${C_RESET}  ${C_GREEN}✓${C_RESET} %s\n" "$*"
}

step_warn() {
	printf "${C_CYAN}│${C_RESET}  ${C_YELLOW}▲${C_RESET} %s\n" "$*"
}

step_error() {
	printf "${C_CYAN}│${C_RESET}  ${C_RED}✗ %s${C_RESET}\n" "$*" >&2
}

step_end() {
	printf "${C_CYAN}╰───────────────────────────────────────────────────────────${C_RESET}\n"
}

die() {
	step_error "$*"
	step_end
	exit 1
}

# Keep sudo alive during script execution
keep_sudo_alive() {
	while true; do
		sudo -n true
		sleep 60
		kill -0 "$$" 2>/dev/null || exit
	done 2>/dev/null &
	SUDO_PID=$!
	trap 'kill -9 ${SUDO_PID} 2>/dev/null || true' EXIT
}

# --- Pre-flight Checks --------------------------------------------------------
check_environment() {
	step_header 1 9 "Checking System Environment"

	# 1. Root check
	if [[ ${EUID} -eq 0 && -z ${SUDO_USER:-} ]]; then
		die "Do NOT run this script directly as root! Makepkg and AUR helpers refuse to run as root.\nPlease run as your regular user with sudo permissions: ./setup.sh"
	fi
	step_success "Running as non-root user (${TARGET_USER}) with target home ${TARGET_HOME}"

	# 2. Arch Linux check
	if [[ ! -f /etc/arch-release ]] && ! grep -qiE 'arch|astra' /etc/os-release 2>/dev/null; then
		die "Astra Linux setup requires an Arch Linux base system. /etc/arch-release was not found."
	fi
	step_success "Arch Linux base detected"

	# 3. Sudo privileges
	step_info "Testing sudo authentication..."
	if ! sudo -v; then
		die "Sudo authentication failed. Please ensure ${TARGET_USER} is in the wheel group."
	fi
	keep_sudo_alive
	step_success "Sudo privileges confirmed"

	# 4. Network check
	step_info "Testing network connectivity..."
	if ! curl -Is --connect-timeout 5 https://archlinux.org >/dev/null 2>&1 && \
	   ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
		step_warn "Network test failed or unstable. Ensure you have an active internet connection."
	else
		step_success "Network connectivity established"
	fi

	step_end
}

# --- Interactive Prompts ------------------------------------------------------
show_menu() {
	if [[ ${OPT_NONINTERACTIVE} -eq 1 ]]; then
		return 0
	fi

	printf "${C_CYAN}${C_BOLD}╭─ Configure Your Astra Linux Experience ───────────────────────${C_RESET}\n"
	printf "${C_CYAN}│${C_RESET} Please choose your preferred components:\n"
	printf "${C_CYAN}│${C_RESET}\n"

	# 1. AUR Helper
	printf "${C_CYAN}│${C_RESET} ${C_BOLD}Select AUR Helper:${C_RESET}\n"
	printf "${C_CYAN}│${C_RESET}   ${C_GOLD}1)${C_RESET} paru      ${C_MUTED}(Default — Fast, written in Rust, feature-rich)${C_RESET}\n"
	printf "${C_CYAN}│${C_RESET}   ${C_GOLD}2)${C_RESET} yay       ${C_MUTED}(Classic Go-based AUR helper)${C_RESET}\n"
	printf "${C_CYAN}│${C_RESET}   ${C_GOLD}3)${C_RESET} skip      ${C_MUTED}(Already installed or manage AUR manually)${C_RESET}\n"
	read -r -p "Select [1-3] (Default: 1): " choice_aur
	case "${choice_aur}" in
		2) OPT_AUR="yay" ;;
		3) OPT_AUR="skip" ;;
		*) OPT_AUR="paru" ;;
	esac
	printf "${C_CYAN}│${C_RESET}   ${C_GREEN}→ Selected AUR Helper:${C_RESET} ${OPT_AUR}\n"
	printf "${C_CYAN}│${C_RESET}\n"

	# 2. Web Browser
	printf "${C_CYAN}│${C_RESET} ${C_BOLD}Select Default Web Browser:${C_RESET}\n"
	printf "${C_CYAN}│${C_RESET}   ${C_GOLD}1)${C_RESET} Firefox        ${C_MUTED}(Default — Official Arch repo, privacy-focused)${C_RESET}\n"
	printf "${C_CYAN}│${C_RESET}   ${C_GOLD}2)${C_RESET} Helium Browser ${C_MUTED}(helium-browser-bin — AUR lightweight modern browser)${C_RESET}\n"
	printf "${C_CYAN}│${C_RESET}   ${C_GOLD}3)${C_RESET} Chromium       ${C_MUTED}(Official Arch repo)${C_RESET}\n"
	printf "${C_CYAN}│${C_RESET}   ${C_GOLD}4)${C_RESET} Brave Browser  ${C_MUTED}(brave-bin — AUR privacy browser)${C_RESET}\n"
	printf "${C_CYAN}│${C_RESET}   ${C_GOLD}5)${C_RESET} None / Skip    ${C_MUTED}(Do not install a browser)${C_RESET}\n"
	read -r -p "Select [1-5] (Default: 1): " choice_browser
	case "${choice_browser}" in
		2) OPT_BROWSER="helium" ;;
		3) OPT_BROWSER="chromium" ;;
		4) OPT_BROWSER="brave" ;;
		5) OPT_BROWSER="none" ;;
		*) OPT_BROWSER="firefox" ;;
	esac
	printf "${C_CYAN}│${C_RESET}   ${C_GREEN}→ Selected Browser:${C_RESET} ${OPT_BROWSER}\n"
	printf "${C_CYAN}│${C_RESET}\n"

	# 3. Hardware Drivers
	read -r -p "Detect hardware and install GPU / CPU / VM drivers? [Y/n]: " choice_drv
	if [[ "${choice_drv}" =~ ^[Nn] ]]; then
		OPT_DRIVERS="no"
	fi
	printf "${C_CYAN}│${C_RESET}   ${C_GREEN}→ Hardware Drivers:${C_RESET} ${OPT_DRIVERS}\n"

	# 4. System Rebranding
	read -r -p "Rebrand system to Astra Linux (/etc/os-release & logo)? [Y/n]: " choice_rebrand
	if [[ "${choice_rebrand}" =~ ^[Nn] ]]; then
		OPT_REBRAND="no"
	fi
	printf "${C_CYAN}│${C_RESET}   ${C_GREEN}→ Rebranding:${C_RESET} ${OPT_REBRAND}\n"

	# 5. GRUB Theming
	read -r -p "Install Astra Linux cosmic GRUB Theme & 1080p styling? [Y/n]: " choice_grub
	if [[ "${choice_grub}" =~ ^[Nn] ]]; then
		OPT_GRUB="no"
	fi
	printf "${C_CYAN}│${C_RESET}   ${C_GREEN}→ GRUB Theming:${C_RESET} ${OPT_GRUB}\n"

	# 6. Plymouth Boot Splash
	read -r -p "Install Astra Linux Plymouth boot splash (cosmic star animation)? [Y/n]: " choice_ply
	if [[ "${choice_ply}" =~ ^[Nn] ]]; then
		OPT_PLYMOUTH="no"
	fi
	printf "${C_CYAN}│${C_RESET}   ${C_GREEN}→ Plymouth Boot Splash:${C_RESET} ${OPT_PLYMOUTH}\n"

	# 7. SDDM Theme
	read -r -p "Install Astra Linux SilentSDDM login theme and enable SDDM? [Y/n]: " choice_sddm
	if [[ "${choice_sddm}" =~ ^[Nn] ]]; then
		OPT_SDDM="no"
	fi
	printf "${C_CYAN}│${C_RESET}   ${C_GREEN}→ SDDM Theme:${C_RESET} ${OPT_SDDM}\n"

	# 8. Desktop Dotfiles
	read -r -p "Deploy Astra Linux desktop dotfiles (Niri, Noctalia, Kitty, LazyVim, Opencode)? [Y/n]: " choice_dot
	if [[ "${choice_dot}" =~ ^[Nn] ]]; then
		OPT_DOTFILES="no"
	fi
	printf "${C_CYAN}│${C_RESET}   ${C_GREEN}→ Desktop Dotfiles:${C_RESET} ${OPT_DOTFILES}\n"

	printf "${C_CYAN}╰───────────────────────────────────────────────────────────${C_RESET}\n\n"

	read -r -p "Begin Astra Linux installation with the above settings? [Y/n]: " confirm
	if [[ "${confirm}" =~ ^[Nn] ]]; then
		printf "\nInstallation cancelled by user.\n"
		exit 0
	fi
}

# --- Shared Library & ALPM Compatibility -------------------------------------
fix_libalpm() {
	local target_alpm=""
	# Find real file (not symlink) first
	target_alpm="$(find /usr/lib -maxdepth 1 -name 'libalpm.so.*' ! -type l 2>/dev/null | sort -V | tail -n 1)"
	if [[ -z "${target_alpm}" ]]; then
		target_alpm="$(find /usr/lib -maxdepth 1 -name 'libalpm.so*' 2>/dev/null | sort -V | tail -n 1)"
	fi
	if [[ -n "${target_alpm}" && -e "${target_alpm}" ]]; then
		# Ensure compatibility symlinks exist for all common ALPM versions (13, 14, 15, 16, 17)
		for ver in 13 14 15 16 17; do
			if [[ ! -e "/usr/lib/libalpm.so.${ver}" ]]; then
				sudo ln -sf "${target_alpm}" "/usr/lib/libalpm.so.${ver}" 2>/dev/null || true
			fi
		done
	fi
}

is_helper_functional() {
	local h="$1"
	command -v "${h}" >/dev/null 2>&1 && "${h}" --version >/dev/null 2>&1
}

# --- Core Dependencies & AUR Helper Setup -------------------------------------
setup_aur_helper() {
	step_header 2 9 "Configuring Base Tools & AUR Helper"

	# 1. Base devel & git
	step_info "Installing base development tools via pacman..."
	sudo pacman -S --needed --noconfirm base-devel git curl wget

	# 2. Enable multilib in /etc/pacman.conf if commented
	if grep -q "^#[multilib]" /etc/pacman.conf 2>/dev/null; then
		step_info "Enabling multilib repository in /etc/pacman.conf..."
		sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
		sudo pacman -Sy
	fi

	# 3. Fix any libalpm library version mismatches
	fix_libalpm

	# 4. Bootstrap selected AUR helper
	if [[ "${OPT_AUR}" == "paru" ]]; then
		if is_helper_functional paru; then
			step_success "paru is already installed and verified functional"
		else
			step_info "Building and installing paru-bin from AUR..."
			rm -rf /tmp/paru-bin /tmp/paru
			if git clone --depth 1 https://aur.archlinux.org/paru-bin.git /tmp/paru-bin && \
			   (cd /tmp/paru-bin && makepkg -si --noconfirm --skippgpcheck); then
				step_success "paru-bin installed successfully"
			elif git clone --depth 1 https://aur.archlinux.org/paru.git /tmp/paru && \
			     (cd /tmp/paru && makepkg -si --noconfirm --skippgpcheck); then
				step_success "paru installed from source"
			else
				step_warn "Could not build paru; attempting yay-bin..."
				if git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && \
				   (cd /tmp/yay-bin && makepkg -si --noconfirm --skippgpcheck); then
					OPT_AUR="yay"
					step_success "yay installed as fallback"
				fi
			fi
			rm -rf /tmp/paru-bin /tmp/paru /tmp/yay-bin
			fix_libalpm
		fi
	elif [[ "${OPT_AUR}" == "yay" ]]; then
		if is_helper_functional yay; then
			step_success "yay is already installed and verified functional"
		else
			step_info "Building and installing yay-bin from AUR..."
			rm -rf /tmp/yay-bin /tmp/yay
			if git clone --depth 1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && \
			   (cd /tmp/yay-bin && makepkg -si --noconfirm --skippgpcheck); then
				step_success "yay-bin installed successfully"
			elif git clone --depth 1 https://aur.archlinux.org/yay.git /tmp/yay && \
			     (cd /tmp/yay && makepkg -si --noconfirm --skippgpcheck); then
				step_success "yay installed from source"
			fi
			rm -rf /tmp/yay-bin /tmp/yay
			fix_libalpm
		fi
	else
		step_info "Skipping AUR helper installation as requested."
	fi

	step_end
}

# Helper to run AUR install command with error isolation and makepkg fallback
aur_install() {
	local pkgs=("$@")
	fix_libalpm

	local installed_via_helper=0
	if is_helper_functional paru; then
		step_info "Installing via paru: ${pkgs[*]}..."
		if paru -S --needed --noconfirm --mflags "--skippgpcheck" "${pkgs[@]}" 2>/dev/null || paru -S --needed --noconfirm "${pkgs[@]}"; then
			installed_via_helper=1
		else
			step_warn "paru encountered an issue; falling back to direct makepkg..."
		fi
	elif is_helper_functional yay; then
		step_info "Installing via yay: ${pkgs[*]}..."
		if yay -S --needed --noconfirm --mflags "--skippgpcheck" "${pkgs[@]}" 2>/dev/null || yay -S --needed --noconfirm "${pkgs[@]}"; then
			installed_via_helper=1
		else
			step_warn "yay encountered an issue; falling back to direct makepkg..."
		fi
	fi

	# Fallback if helper was unavailable or failed
	if [[ ${installed_via_helper} -eq 0 ]]; then
		for pkg in "${pkgs[@]}"; do
			if pacman -Q "${pkg}" >/dev/null 2>&1; then
				step_info "Package ${pkg} is already installed."
				continue
			fi
			step_info "Building AUR package ${pkg} directly via makepkg..."
			local build_dir="/tmp/astra-build-${pkg}"
			rm -rf "${build_dir}"
			if git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "${build_dir}"; then
				(cd "${build_dir}" && makepkg -si --noconfirm --skippgpcheck) || step_warn "makepkg failed for ${pkg}"
				rm -rf "${build_dir}"
			else
				step_warn "Could not clone AUR repository for ${pkg}"
			fi
		done
	fi
}

# --- Hardware & Driver Detection Engine ---------------------------------------
detect_and_install_drivers() {
	if [[ "${OPT_DRIVERS}" != "yes" ]]; then
		return 0
	fi

	step_header 3 9 "Detecting Hardware & Installing Drivers"

	local DRIVER_PKGS=()

	# 1. CPU Microcode Detection
	if [[ -r /proc/cpuinfo ]]; then
		if grep -q "AuthenticAMD" /proc/cpuinfo; then
			step_info "Detected AMD processor -> adding amd-ucode"
			DRIVER_PKGS+=("amd-ucode")
		elif grep -q "GenuineIntel" /proc/cpuinfo; then
			step_info "Detected Intel processor -> adding intel-ucode"
			DRIVER_PKGS+=("intel-ucode")
		fi
	fi

	# 2. Virtual Machine Guest Tools
	local virt
	virt="$(systemd-detect-virt 2>/dev/null || true)"
	case "${virt}" in
		oracle)
			step_info "Detected VirtualBox environment -> adding virtualbox-guest-utils"
			DRIVER_PKGS+=("virtualbox-guest-utils")
			;;
		vmware)
			step_info "Detected VMware environment -> adding open-vm-tools"
			DRIVER_PKGS+=("open-vm-tools")
			;;
		kvm|qemu|bochs)
			step_info "Detected QEMU/KVM environment -> adding qemu-guest-agent spice-vdagent"
			DRIVER_PKGS+=("qemu-guest-agent" "spice-vdagent")
			;;
		*)
			;;
	esac

	# 3. GPU Display Controller Detection
	local has_gpu=0
	if command -v lspci >/dev/null 2>&1; then
		# Check NVIDIA
		if lspci -nn 2>/dev/null | grep -Eiq '(VGA compatible controller|3D controller|Display controller).*\[10de:'; then
			step_info "Detected NVIDIA graphics controller -> adding nvidia-open & utils"
			DRIVER_PKGS+=("nvidia-open" "nvidia-utils" "lib32-nvidia-utils" "nvidia-settings")
			has_gpu=1
		fi
		# Check AMD
		if lspci -nn 2>/dev/null | grep -Eiq '(VGA compatible controller|3D controller|Display controller).*\[1002:'; then
			step_info "Detected AMD graphics controller -> adding mesa & vulkan-radeon"
			DRIVER_PKGS+=("mesa" "vulkan-radeon" "lib32-mesa" "lib32-vulkan-radeon" "libva-utils")
			has_gpu=1
		fi
		# Check Intel
		if lspci -nn 2>/dev/null | grep -Eiq '(VGA compatible controller|3D controller|Display controller).*\[8086:'; then
			step_info "Detected Intel graphics controller -> adding mesa, vulkan-intel & intel-media-driver"
			DRIVER_PKGS+=("mesa" "vulkan-intel" "lib32-mesa" "lib32-vulkan-intel" "intel-media-driver" "libva-utils")
			has_gpu=1
		fi
	fi

	# Fallback if no specific GPU detected
	if [[ ${has_gpu} -eq 0 ]]; then
		step_info "Generic / standard graphics -> ensuring mesa is installed"
		DRIVER_PKGS+=("mesa" "lib32-mesa")
	fi

	# Install detected driver packages
	if [[ ${#DRIVER_PKGS[@]} -gt 0 ]]; then
		step_info "Installing hardware packages: ${DRIVER_PKGS[*]}..."
		sudo pacman -S --needed --noconfirm "${DRIVER_PKGS[@]}"
		step_success "Hardware drivers installed"
	fi

	# Enable VM services if installed
	if [[ "${virt}" == "oracle" ]]; then
		sudo systemctl enable vboxservice.service 2>/dev/null || true
	elif [[ "${virt}" == "vmware" ]]; then
		sudo systemctl enable vmtoolsd.service 2>/dev/null || true
	elif [[ "${virt}" =~ ^(kvm|qemu)$ ]]; then
		sudo systemctl enable qemu-guest-agent.service 2>/dev/null || true
	fi

	# Enable NVIDIA services if installed
	if command -v lspci >/dev/null 2>&1 && lspci -nn 2>/dev/null | grep -Eiq '(VGA compatible controller|3D controller|Display controller).*\[10de:'; then
		sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service 2>/dev/null || true
	fi

	step_end
}

# --- Package Installation Engine ----------------------------------------------
install_system_packages() {
	step_header 4 9 "Installing Desktop Packages & Dependencies"

	step_info "Synchronizing pacman package databases..."
	sudo pacman -Sy --noconfirm

	# List of official Arch packages required by AstraOS
	local OFFICIAL_PKGS=(
		# Window Management & Session
		niri
		noctalia
		quickshell
		xwayland-satellite
		xorg-xwayland
		wl-clipboard
		brightnessctl
		playerctl
		grim
		slurp

		# Terminal & Shell
		kitty
		zsh
		zsh-autosuggestions
		zsh-syntax-highlighting

		# Developer Tools & Editors
		neovim
		opencode
		nodejs
		npm
		python-pynvim
		python-json5
		python-tomlkit
		tree-sitter-cli
		fzf
		ripgrep
		fd
		bat
		eza
		zoxide
		lazygit
		btop
		fastfetch

		# Audio & Bluetooth
		pipewire
		pipewire-alsa
		pipewire-pulse
		pipewire-jack
		wireplumber
		rtkit
		bluez
		bluez-utils

		# System Integration, Files & Portals
		networkmanager
		power-profiles-daemon
		upower
		polkit
		gnome-keyring
		xdg-desktop-portal-gnome
		xdg-desktop-portal-gtk
		xdg-user-dirs
		xdg-utils
		dconf
		nautilus
		file-roller
		gvfs
		gvfs-mtp
		gvfs-smb
		ffmpegthumbnailer
		p7zip
		unzip

		# GUI Apps & Media
		loupe
		mpv
		pavucontrol
		gnome-text-editor
		gnome-calculator
		gnome-disk-utility

		# Qt6 Runtime & Wayland Compatibility
		qt5-wayland
		qt6-wayland
		qt6-svg
		qt6-declarative
		qt6-5compat
		qt6-virtualkeyboard
		qt6-multimedia-ffmpeg

		# Fonts & Themes
		ttf-jetbrains-mono-nerd
		noto-fonts
		noto-fonts-emoji
		noto-fonts-cjk
		ttf-liberation
		adwaita-fonts
		adw-gtk-theme
		papirus-icon-theme

		# Display & Boot
		sddm
		plymouth
		grub
		efibootmgr
		os-prober
	)

	step_info "Installing core packages via pacman..."
	# Filter packages: check which exist in repos, install in batch
	local AVAILABLE_PKGS=()
	for pkg in "${OFFICIAL_PKGS[@]}"; do
		if pacman -Si "${pkg}" >/dev/null 2>&1; then
			AVAILABLE_PKGS+=("${pkg}")
		else
			step_warn "Package ${pkg} not found in official repositories; will attempt via AUR"
		fi
	done

	sudo pacman -S --needed --noconfirm "${AVAILABLE_PKGS[@]}"
	step_success "Official repository packages installed"

	# AUR Packages: oh-my-posh-bin is mandatory for the 1_shell AstraOS prompt
	step_info "Installing AUR packages..."
	local AUR_PKGS=("oh-my-posh-bin")

	# Check if opencode was installed via pacman or needs AUR
	if ! command -v opencode >/dev/null 2>&1; then
		AUR_PKGS+=("opencode-bin")
	fi

	aur_install "${AUR_PKGS[@]}"
	step_success "AUR base packages installed"

	# Install Chosen Web Browser
	step_info "Installing chosen browser: ${OPT_BROWSER}..."
	case "${OPT_BROWSER}" in
		firefox)
			sudo pacman -S --needed --noconfirm firefox
			;;
		chromium)
			sudo pacman -S --needed --noconfirm chromium
			;;
		helium)
			aur_install "helium-browser-bin"
			;;
		brave)
			aur_install "brave-bin"
			;;
		none)
			step_info "Skipping web browser installation."
			;;
	esac
	step_success "Browser configuration ready"

	step_end
}

# --- System Rebranding --------------------------------------------------------
setup_branding() {
	if [[ "${OPT_REBRAND}" != "yes" ]]; then
		return 0
	fi

	step_header 5 9 "Applying Astra Linux System Branding"

	# 1. Update /etc/os-release and /usr/lib/os-release
	step_info "Configuring /etc/os-release..."
	sudo mkdir -p /usr/lib
	sudo tee /usr/lib/astralinux-release >/dev/null <<'EOF'
NAME="Astra Linux"
PRETTY_NAME="Astra Linux"
ID=astralinux
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;94;230;242"
LOGO=astraos-logo
HOME_URL="https://github.com/AmanicX/astra-os"
SUPPORT_URL="https://github.com/AmanicX/astra-os"
EOF

	sudo cp /usr/lib/astralinux-release /usr/lib/os-release
	if [[ -L /etc/os-release ]]; then
		sudo ln -sfn /usr/lib/os-release /etc/os-release
	else
		sudo cp /usr/lib/astralinux-release /etc/os-release
	fi
	step_success "Branded OS to Astra Linux in os-release"

	# 2. Install Astra Branding Assets (Fastfetch ASCII, marks, SVGs)
	if [[ -d "${PACKAGES_DIR}/astra-branding/files/usr/share/astra/branding" ]]; then
		step_info "Installing Astra branding assets..."
		sudo mkdir -p /usr/share/astra/branding
		sudo cp -a "${PACKAGES_DIR}/astra-branding/files/usr/share/astra/branding/." /usr/share/astra/branding/
		step_success "Astra branding assets installed to /usr/share/astra/branding"
	fi

	# 3. Install Astra Icons
	if [[ -d "${PACKAGES_DIR}/astra-branding/files/usr/share/icons/hicolor" ]]; then
		step_info "Installing Astra icons..."
		sudo cp -a "${PACKAGES_DIR}/astra-branding/files/usr/share/icons/hicolor/." /usr/share/icons/hicolor/
		sudo gtk-update-icon-cache -q -t /usr/share/icons/hicolor 2>/dev/null || true
		step_success "Astra logo icons installed"
	fi

	# 4. Install Wallpapers
	if [[ -d "${PACKAGES_DIR}/astra-branding/files/usr/share/backgrounds/astraos" ]]; then
		step_info "Installing high-resolution wallpapers..."
		sudo mkdir -p /usr/share/backgrounds/astraos
		sudo cp -a "${PACKAGES_DIR}/astra-branding/files/usr/share/backgrounds/astraos/." /usr/share/backgrounds/astraos/
		step_success "Wallpapers installed to /usr/share/backgrounds/astraos"
	fi

	step_end
}

# --- GRUB Theming -------------------------------------------------------------
setup_grub() {
	if [[ "${OPT_GRUB}" != "yes" ]]; then
		return 0
	fi

	step_header 6 9 "Installing Astra Linux GRUB Theme"

	local GRUB_SRC="${PACKAGES_DIR}/astra-branding/files/usr/share/grub/themes/astra"
	if [[ -d "${GRUB_SRC}" ]]; then
		step_info "Deploying GRUB theme to /boot/grub/themes/astra..."
		sudo mkdir -p /boot/grub/themes/astra /usr/share/grub/themes/astra
		sudo cp -r --no-preserve=ownership "${GRUB_SRC}/." /boot/grub/themes/astra/ 2>/dev/null || \
		sudo cp -r "${GRUB_SRC}/." /boot/grub/themes/astra/ 2>/dev/null || true

		sudo cp -r --no-preserve=ownership "${GRUB_SRC}/." /usr/share/grub/themes/astra/ 2>/dev/null || \
		sudo cp -r "${GRUB_SRC}/." /usr/share/grub/themes/astra/ 2>/dev/null || true

		if [[ -f /etc/default/grub ]]; then
			step_info "Configuring /etc/default/grub..."
			# Set distributor
			if grep -q '^GRUB_DISTRIBUTOR=' /etc/default/grub; then
				sudo sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Astra Linux"/' /etc/default/grub
			else
				echo 'GRUB_DISTRIBUTOR="Astra Linux"' | sudo tee -a /etc/default/grub >/dev/null
			fi

			# Set theme
			if grep -q '^GRUB_THEME=' /etc/default/grub; then
				sudo sed -i 's|^GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/astra/theme.txt"|' /etc/default/grub
			else
				echo 'GRUB_THEME="/boot/grub/themes/astra/theme.txt"' | sudo tee -a /etc/default/grub >/dev/null
			fi

			# Set gfxmode
			if grep -q '^GRUB_GFXMODE=' /etc/default/grub; then
				sudo sed -i 's/^GRUB_GFXMODE=.*/GRUB_GFXMODE="1920x1080,auto"/' /etc/default/grub
			else
				echo 'GRUB_GFXMODE="1920x1080,auto"' | sudo tee -a /etc/default/grub >/dev/null
			fi

			# Set smooth quiet splash boot
			if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
				if ! grep -q 'splash' /etc/default/grub; then
					sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&quiet splash loglevel=3 rd.udev.log_priority=3 vt.global_cursor_default=0 /' /etc/default/grub
				fi
				# NVIDIA modeset parameters if NVIDIA is detected
				if command -v lspci >/dev/null 2>&1 && lspci -nn 2>/dev/null | grep -Eiq '(VGA compatible controller|3D controller|Display controller).*\[10de:'; then
					if ! grep -q 'nvidia-drm.modeset=1' /etc/default/grub; then
						sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&nvidia-drm.modeset=1 nvidia_drm.fbdev=1 /' /etc/default/grub
					fi
				fi
			fi

			# Enable os-prober if dual boot
			if grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
				sudo sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
			else
				echo 'GRUB_DISABLE_OS_PROBER=false' | sudo tee -a /etc/default/grub >/dev/null
			fi

			# Regenerate grub.cfg
			step_info "Generating GRUB configuration (grub-mkconfig)..."
			sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
			step_success "Astra Linux GRUB theme applied"
		else
			step_warn "/etc/default/grub not found. Skipped grub-mkconfig."
		fi
	else
		step_warn "GRUB theme source not found at ${GRUB_SRC}."
	fi

	step_end
}

# --- Plymouth Boot Splash -----------------------------------------------------
setup_plymouth() {
	if [[ "${OPT_PLYMOUTH}" != "yes" ]]; then
		return 0
	fi

	step_header 7 9 "Configuring Plymouth Cosmic Boot Splash"

	local PLY_SRC="${PACKAGES_DIR}/astra-branding/files/usr/share/plymouth/themes/astra"
	if [[ -d "${PLY_SRC}" ]]; then
		step_info "Deploying Plymouth theme to /usr/share/plymouth/themes/astra..."
		sudo mkdir -p /usr/share/plymouth/themes/astra /etc/plymouth
		sudo cp -a "${PLY_SRC}/." /usr/share/plymouth/themes/astra/

		sudo tee /etc/plymouth/plymouthd.conf >/dev/null <<'EOF'
[Daemon]
Theme=astra
ShowDelay=0
DeviceTimeout=8
EOF

		# Add plymouth to mkinitcpio HOOKS
		if [[ -f /etc/mkinitcpio.conf ]]; then
			if grep -q '^HOOKS=' /etc/mkinitcpio.conf && ! grep -q 'plymouth' /etc/mkinitcpio.conf; then
				step_info "Adding plymouth hook to /etc/mkinitcpio.conf..."
				sudo sed -i -E 's/(systemd|udev)/\1 plymouth/' /etc/mkinitcpio.conf
			fi

			step_info "Regenerating initramfs with mkinitcpio -P..."
			sudo mkinitcpio -P
			step_success "Plymouth cosmic boot splash installed and active"
		fi
	else
		step_warn "Plymouth theme source not found at ${PLY_SRC}."
	fi

	step_end
}

# --- SDDM Display Manager Theming ---------------------------------------------
setup_sddm() {
	if [[ "${OPT_SDDM}" != "yes" ]]; then
		return 0
	fi

	step_header 8 9 "Configuring SDDM Login Manager & Theme"

	local SDDM_THEME_DIR="/usr/share/sddm/themes/silent"
	sudo mkdir -p "${SDDM_THEME_DIR}"

	# Check local files first
	if [[ -d "${PACKAGES_DIR}/astra-sddm-theme/files/usr/share/sddm/themes/silent" ]]; then
		step_info "Copying SilentSDDM theme files..."
		sudo cp -a "${PACKAGES_DIR}/astra-sddm-theme/files/usr/share/sddm/themes/silent/." "${SDDM_THEME_DIR}/"
	elif [[ -d "${PACKAGES_DIR}/astra-sddm-theme/src/silent-sddm" ]]; then
		step_info "Deploying SilentSDDM from src..."
		sudo cp -a "${PACKAGES_DIR}/astra-sddm-theme/src/silent-sddm/." "${SDDM_THEME_DIR}/"
	else
		step_info "Fetching SilentSDDM theme..."
		rm -rf /tmp/silent-sddm
		git clone --depth 1 https://github.com/uiriansan/SilentSDDM.git /tmp/silent-sddm
		sudo cp -a /tmp/silent-sddm/. "${SDDM_THEME_DIR}/"
		rm -rf /tmp/silent-sddm
	fi

	# Copy Astra presets into the theme configs
	sudo mkdir -p "${SDDM_THEME_DIR}/configs" "${SDDM_THEME_DIR}/backgrounds"
	if [[ -d "${PACKAGES_DIR}/astra-sddm-theme/presets" ]]; then
		sudo cp -a "${PACKAGES_DIR}/astra-sddm-theme/presets/"*.conf "${SDDM_THEME_DIR}/configs/"
	fi

	# Link AstraOS wallpapers to the SDDM backgrounds folder
	if [[ -d /usr/share/backgrounds/astraos ]]; then
		for wall in /usr/share/backgrounds/astraos/*; do
			if [[ -f "${wall}" ]]; then
				sudo ln -sf "${wall}" "${SDDM_THEME_DIR}/backgrounds/$(basename "${wall}")"
			fi
		done
	fi

	# Configure SDDM
	step_info "Writing /etc/sddm.conf.d/astra.conf..."
	sudo mkdir -p /etc/sddm.conf.d /var/lib/sddm
	sudo tee /etc/sddm.conf.d/astra.conf >/dev/null <<'EOF'
[General]
DisplayServer=x11
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
Numlock=on
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent
ConfigFile=configs/astra-orbital.conf
CursorTheme=Adwaita
CursorSize=24
Font=Adwaita Sans
EnableAvatars=true

[Users]
RememberLastUser=true
RememberLastSession=true

[Autologin]
Session=niri.desktop

[Last]
Session=/usr/share/wayland-sessions/niri.desktop

[X11]
MinimumVT=7
EOF

	# Pre-seed last session so SDDM defaults immediately to Niri
	sudo tee /var/lib/sddm/state.conf >/dev/null <<'EOF'
[Last]
Session=/usr/share/wayland-sessions/niri.desktop
EOF
	sudo chmod 0644 /var/lib/sddm/state.conf 2>/dev/null || true

	# Install theme switcher utility
	if [[ -f "${PACKAGES_DIR}/astra-sddm-theme/astra-sddm-theme" ]]; then
		sudo install -Dm755 "${PACKAGES_DIR}/astra-sddm-theme/astra-sddm-theme" /usr/local/bin/astra-sddm-theme
		sudo ln -sf /usr/local/bin/astra-sddm-theme /usr/bin/astra-sddm-theme 2>/dev/null || true
	fi

	# Enable sddm service
	step_info "Enabling sddm.service..."
	sudo systemctl enable sddm.service 2>/dev/null || true
	step_success "Astra Linux SilentSDDM configured and enabled"

	step_end
}

# --- Desktop Dotfiles, Kitty, LazyVim, Opencode, Zsh --------------------------
setup_desktop_dotfiles() {
	if [[ "${OPT_DOTFILES}" != "yes" ]]; then
		return 0
	fi

	step_header 9 9 "Deploying Dotfiles & Desktop Configuration"

	local SKEL_SRC="${PACKAGES_DIR}/astra-desktop-config/files/etc/skel"

	# 1. User & Skel directories setup
	step_info "Creating user directories..."
	mkdir -p "${TARGET_HOME}/.config" "${TARGET_HOME}/.local/share" "${TARGET_HOME}/.local/state" \
	         "${TARGET_HOME}/Pictures/Screenshots" "${TARGET_HOME}/Pictures/Wallpapers" \
	         "${TARGET_HOME}/.local/bin"
	sudo mkdir -p /etc/skel/.config /etc/skel/.local/share /etc/skel/.local/state \
	              /etc/skel/Pictures/Screenshots /etc/skel/Pictures/Wallpapers

	# 2. Deploy Skel Configurations (Niri, Noctalia, Kitty, LazyVim, Opencode, OhMyPosh, Fastfetch, Btop)
	step_info "Deploying configs to ${TARGET_HOME} and /etc/skel..."
	cp -a "${SKEL_SRC}/." "${TARGET_HOME}/"
	sudo cp -a "${SKEL_SRC}/." /etc/skel/

	# 3. Deploy Keybind overlay
	local KEYBINDS_SRC="${PACKAGES_DIR}/astra-keybinds/files"
	if [[ -d "${KEYBINDS_SRC}" ]]; then
		step_info "Installing keybind overlay and helpers..."
		cp -a "${KEYBINDS_SRC}/etc/skel/.config/quickshell" "${TARGET_HOME}/.config/"
		sudo cp -a "${KEYBINDS_SRC}/etc/skel/.config/quickshell" /etc/skel/.config/

		sudo mkdir -p /usr/share/astra/keybinds
		sudo cp -a "${KEYBINDS_SRC}/usr/share/astra/keybinds/." /usr/share/astra/keybinds/
		sudo install -Dm755 "${KEYBINDS_SRC}/usr/bin/astra-keybinds-start" /usr/local/bin/astra-keybinds-start
		sudo install -Dm755 "${KEYBINDS_SRC}/usr/bin/astra-keybinds-toggle" /usr/local/bin/astra-keybinds-toggle
		sudo ln -sf /usr/local/bin/astra-keybinds-start /usr/bin/astra-keybinds-start 2>/dev/null || true
		sudo ln -sf /usr/local/bin/astra-keybinds-toggle /usr/bin/astra-keybinds-toggle 2>/dev/null || true
	fi

	# 4. Browser launcher script
	if [[ -f "${PACKAGES_DIR}/astra-desktop-config/files/usr/bin/astra-default-browser" ]]; then
		sudo install -Dm755 "${PACKAGES_DIR}/astra-desktop-config/files/usr/bin/astra-default-browser" /usr/local/bin/astra-default-browser
		sudo ln -sf /usr/local/bin/astra-default-browser /usr/bin/astra-default-browser 2>/dev/null || true
	fi

	# 4b. Wayland VM & Quickshell Compatibility
	step_info "Configuring Wayland VM environment variables and helpers..."
	sudo mkdir -p /etc/environment.d "${TARGET_HOME}/.config/environment.d"
	if ! grep -q 'WLR_NO_HARDWARE_CURSORS' /etc/environment 2>/dev/null; then
		echo 'WLR_NO_HARDWARE_CURSORS=1' | sudo tee -a /etc/environment >/dev/null
	fi
	if ! grep -q 'WLR_RENDERER_ALLOW_SOFTWARE' /etc/environment 2>/dev/null; then
		echo 'WLR_RENDERER_ALLOW_SOFTWARE=1' | sudo tee -a /etc/environment >/dev/null
	fi
	tee "${TARGET_HOME}/.config/environment.d/10-astra.conf" >/dev/null <<'EOF'
WLR_NO_HARDWARE_CURSORS=1
WLR_RENDERER_ALLOW_SOFTWARE=1
EOF

	# Ensure qs symlink is available for astra-keybinds-start and quickshell CLI
	if command -v quickshell >/dev/null 2>&1; then
		sudo ln -sf "$(command -v quickshell)" /usr/local/bin/qs 2>/dev/null || true
		sudo ln -sf "$(command -v quickshell)" /usr/bin/qs 2>/dev/null || true
	fi

	# 5. Dconf database update
	if [[ -d "${PACKAGES_DIR}/astra-desktop-config/files/etc/dconf" ]]; then
		step_info "Applying GNOME / GTK dconf profiles..."
		sudo cp -a "${PACKAGES_DIR}/astra-desktop-config/files/etc/dconf/." /etc/dconf/
		sudo dconf update 2>/dev/null || true
	fi

	# 6. Bootstrap LazyVim
	step_info "Bootstrapping Neovim LazyVim..."
	local LAZY_NVIM_DIR="${TARGET_HOME}/.local/share/nvim/lazy/lazy.nvim"
	if [[ ! -d "${LAZY_NVIM_DIR}" ]]; then
		rm -rf "${LAZY_NVIM_DIR}"
		git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git "${LAZY_NVIM_DIR}" 2>/dev/null || true
	fi

	# 7. Configure Mimeapps for selected browser
	local DESKTOP_FILE="firefox.desktop"
	case "${OPT_BROWSER}" in
		helium) DESKTOP_FILE="helium-browser.desktop" ;;
		chromium) DESKTOP_FILE="chromium.desktop" ;;
		brave) DESKTOP_FILE="brave-browser.desktop" ;;
		firefox) DESKTOP_FILE="firefox.desktop" ;;
	esac
	if [[ -f "${TARGET_HOME}/.config/mimeapps.list" ]]; then
		sed -i "s/firefox\.desktop/${DESKTOP_FILE}/g" "${TARGET_HOME}/.config/mimeapps.list"
		sudo sed -i "s/firefox\.desktop/${DESKTOP_FILE}/g" /etc/skel/.config/mimeapps.list 2>/dev/null || true
	fi

	# 8. Set Default Wallpaper & populate user wallpapers
	if [[ -d /usr/share/backgrounds/astraos ]]; then
		mkdir -p "${TARGET_HOME}/Pictures/Wallpapers"
		cp -n /usr/share/backgrounds/astraos/* "${TARGET_HOME}/Pictures/Wallpapers/" 2>/dev/null || true
		if [[ -f /usr/share/backgrounds/astraos/astra-daylight-mountain.png ]]; then
			cp /usr/share/backgrounds/astraos/astra-daylight-mountain.png "${TARGET_HOME}/Pictures/Wallpapers/default.png" 2>/dev/null || true
		elif [[ -f /usr/share/backgrounds/astraos/astraos-default.png ]]; then
			cp /usr/share/backgrounds/astraos/astraos-default.png "${TARGET_HOME}/Pictures/Wallpapers/default.png" 2>/dev/null || true
		fi
	fi

	# 9. Set Default Shell to Zsh
	step_info "Setting default login shell to Zsh..."
	if command -v zsh >/dev/null 2>&1; then
		sudo chsh -s "$(command -v zsh)" "${TARGET_USER}" 2>/dev/null || true
	fi

	# 10. Enable Essential Services
	step_info "Enabling systemd services..."
	sudo systemctl enable NetworkManager.service 2>/dev/null || true
	sudo systemctl enable bluetooth.service 2>/dev/null || true
	sudo systemctl enable power-profiles-daemon.service 2>/dev/null || true
	sudo systemctl enable fstrim.timer 2>/dev/null || true
	sudo systemctl enable systemd-timesyncd.service 2>/dev/null || true
	sudo systemctl set-default graphical.target 2>/dev/null || true

	# 11. Normalize user home permissions
	step_info "Finalizing permissions for ${TARGET_USER}..."
	sudo chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}"

	step_success "Desktop dotfiles, LazyVim, Opencode, Kitty and Noctalia deployed"

	step_end
}

# --- Completion Summary -------------------------------------------------------
show_completion() {
	cat <<EOF

${C_CYAN}${C_BOLD}╭───────────────────────────────────────────────────────────╮
│  ✦ Astra Linux Setup Complete! Welcome to the Stars ✦     │
╰───────────────────────────────────────────────────────────╯${C_RESET}

  ${C_GOLD}✦ Compositor:${C_RESET}    Niri ${C_MUTED}(Scrollable tiling Wayland compositor)${C_RESET}
  ${C_GOLD}✦ Shell / Bar:${C_RESET}   Noctalia ${C_MUTED}(Control Center, App Launcher & Bar)${C_RESET}
  ${C_GOLD}✦ Terminal:${C_RESET}      Kitty ${C_MUTED}(Noctalia transparent palette)${C_RESET}
  ${C_GOLD}✦ Shell:${C_RESET}         Zsh + Oh-My-Posh ${C_MUTED}(1_shell cosmic prompt)${C_RESET}
  ${C_GOLD}✦ Editor:${C_RESET}        Neovim (LazyVim) + Opencode AI Agent
  ${C_GOLD}✦ Display:${C_RESET}       SilentSDDM ${C_MUTED}(Astra Orbital Theme)${C_RESET}
  ${C_GOLD}✦ Bootloader:${C_RESET}    GRUB ${C_MUTED}(Astra Cosmic 1080p) + Plymouth Splash${C_RESET}

${C_CYAN}${C_BOLD}Key Shortcuts to Get Started:${C_RESET}
  ${C_STAR}Super + Return${C_RESET}         Open Kitty Terminal
  ${C_STAR}Super + Space${C_RESET}          Open Noctalia App Launcher
  ${C_STAR}Super + S${C_RESET}              Toggle Noctalia Control Center
  ${C_STAR}Super + B${C_RESET}              Launch Default Web Browser (${OPT_BROWSER})
  ${C_STAR}Super + E${C_RESET}              Open Nautilus File Manager
  ${C_STAR}Super + Shift + /${C_RESET}      Toggle Interactive Keybind Cheatsheet

${C_MUTED}A system reboot is recommended to activate all themes and services.${C_RESET}

EOF

	if [[ ${OPT_NONINTERACTIVE} -eq 0 ]]; then
		read -r -p "Would you like to reboot now? [y/N]: " reboot_choice
		if [[ "${reboot_choice}" =~ ^[Yy] ]]; then
			printf "\nRebooting into Astra Linux...\n"
			sudo systemctl reboot
		fi
	fi
}

# --- CLI Argument Parsing -----------------------------------------------------
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--aur)
				OPT_AUR="$2"
				shift 2
				;;
			--browser)
				OPT_BROWSER="$2"
				shift 2
				;;
			-y|--yes|--non-interactive)
				OPT_NONINTERACTIVE=1
				shift
				;;
			--no-drivers)
				OPT_DRIVERS="no"
				shift
				;;
			--no-rebrand)
				OPT_REBRAND="no"
				shift
				;;
			--no-grub)
				OPT_GRUB="no"
				shift
				;;
			--no-plymouth)
				OPT_PLYMOUTH="no"
				shift
				;;
			--no-sddm)
				OPT_SDDM="no"
				shift
				;;
			--no-dotfiles)
				OPT_DOTFILES="no"
				shift
				;;
			-h|--help)
				cat <<EOF
Usage: ./setup.sh [OPTIONS]

Options:
  --aur <paru|yay|skip>     Select AUR helper (default: paru)
  --browser <name>          Select web browser (firefox|helium|chromium|brave|none)
  -y, --yes                 Non-interactive mode with default answers
  --no-drivers              Skip automatic hardware & GPU driver installation
  --no-rebrand              Skip /etc/os-release rebranding
  --no-grub                 Skip GRUB theme installation
  --no-plymouth             Skip Plymouth boot splash installation
  --no-sddm                 Skip SDDM theme installation
  --no-dotfiles             Skip desktop dotfiles deployment
  -h, --help                Show this help message
EOF
				exit 0
				;;
			*)
				die "Unknown option: $1"
				;;
		esac
	done
}

# --- Main Entrypoint ----------------------------------------------------------
main() {
	parse_args "$@"
	print_banner
	check_environment
	show_menu
	setup_aur_helper
	detect_and_install_drivers
	install_system_packages
	setup_branding
	setup_grub
	setup_plymouth
	setup_sddm
	setup_desktop_dotfiles
	show_completion
}

main "$@"
