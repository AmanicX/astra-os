<p align="center">
  <img src="packages/astra-branding/files/usr/share/astra/branding/astraos-lockup.svg" alt="AstraOS" width="560">
</p>

<h1 align="center">AstraOS</h1>

<p align="center">
  A focused, design-driven, cosmic Linux desktop experience built around
  <strong>Niri</strong> and <strong>Noctalia v5</strong>.
</p>

<p align="center">
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Base-Arch%20Linux-1793d1?logo=archlinux&logoColor=white&style=flat-square" alt="Arch Linux"></a>
  <a href="https://github.com/YaLixDee/niri"><img src="https://img.shields.io/badge/Compositor-Niri-67e8f9?style=flat-square" alt="Niri"></a>
  <a href="https://github.com/noctalia-dev/noctalia"><img src="https://img.shields.io/badge/Shell-Noctalia%20v5-2dd4bf?style=flat-square" alt="Noctalia v5"></a>
  <a href="https://github.com/AmanicX/astra-os"><img src="https://img.shields.io/badge/Setup-Interactive%20Bash-f59e0b?logo=gnubash&logoColor=white&style=flat-square" alt="Interactive Setup"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-38bdf8?style=flat-square" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/Status-Active-2ea043?style=flat-square" alt="Active">
</p>

---

## 🌌 Overview

**AstraOS** transforms a minimal Arch Linux installation into a fully configured, coherent, and distraction-free desktop computing environment. 

Instead of presenting an empty window manager or bloated generic desktop, AstraOS harmoniously pairs the innovative scrollable tiling model of **Niri** with the refined, modern Wayland shell of **Noctalia v5**. Every detail is pre-configured:
- **Terminal & Prompt:** GPU-accelerated **Kitty** with the transparent Noctalia palette, paired with **Zsh** and the **Oh-My-Posh** (`1_shell`) cosmic prompt.
- **Developer Suite:** **Neovim** pre-configured with **LazyVim** and custom base16 theme synchronization, plus the **OpenCode** terminal AI coding agent.
- **Cosmic Theming:** Custom 1080p cosmic **GRUB** theme, a 24-frame pulsing star **Plymouth** boot splash, and **SilentSDDM** login greeter with 7 celestial presets.
- **Hardware Integration:** Automatic detection and configuration of CPU microcode, GPU stacks (NVIDIA, AMD, Intel), and Virtual Machine guest additions (VirtualBox, VMware, QEMU/KVM).

---

## ⚡ Quick Installation

Install a minimal Arch Linux base system (using the standard `archinstall` script or manual bootstrap), reboot into your new installation as a regular user with `sudo` permissions, and run:

```bash
# 1. Clone the AstraOS repository
git clone https://github.com/AmanicX/astra-os.git
cd astra-os

# 2. Run the setup script
./setup.sh
```

*(You can also run `./install.sh`, which acts as an entrypoint wrapper).*

---

## 🛠️ What `setup.sh` Does (Detailed Breakdown)

The setup script executes a structured, 9-stage installation pipeline:

### 1. Pre-flight Environment Checks
- **User Validation:** Verifies the script is run by a regular user with `sudo` privileges (preventing root execution so `makepkg` and AUR helpers build safely).
- **Distribution Detection:** Confirms an Arch Linux base via `/etc/arch-release` or `/etc/os-release`.
- **Sudo Session Keep-Alive:** Authenticates once and maintains an unprivileged background keep-alive process, preventing password prompts during long package downloads.
- **Network Check:** Verifies internet connectivity to Arch Linux package repositories.

### 2. Base Tooling & AUR Helper Setup
- Installs essential compilation tools: `base-devel`, `git`, `curl`, and `wget`.
- Enables the `[multilib]` repository in `/etc/pacman.conf` if commented.
- **AUR Helper Selection:**
  - `paru` *(Default)*: Automatically clones and compiles `paru-bin` from the AUR via `makepkg`.
  - `yay`: Clones and compiles `yay-bin` from the AUR.
  - `skip`: Skips helper installation if you already have one or manage AUR packages manually.

### 3. Hardware & Driver Detection
- **CPU Microcode:** Inspects `/proc/cpuinfo` and installs `intel-ucode` for Intel CPUs or `amd-ucode` for AMD CPUs.
- **Virtual Machine Guest Integration:** Probes virtualization via `systemd-detect-virt`:
  - **VirtualBox:** Installs `virtualbox-guest-utils` and enables `vboxservice.service` for seamless display resizing, clipboard sharing, and time sync.
  - **VMware:** Installs `open-vm-tools` and enables `vmtoolsd.service`.
  - **QEMU / KVM:** Installs `qemu-guest-agent` and `spice-vdagent`.
- **GPU Graphics Stack:** Probes display controllers via PCI IDs:
  - **NVIDIA (`10de:`):** Installs `nvidia-open`, `nvidia-utils`, `lib32-nvidia-utils`, `nvidia-settings`, enables `nvidia-suspend`/`resume` services, and appends `nvidia-drm.modeset=1 nvidia_drm.fbdev=1` to the kernel bootline.
  - **AMD (`1002:`):** Installs `mesa`, `vulkan-radeon`, `lib32-mesa`, `lib32-vulkan-radeon`, and `libva-utils`.
  - **Intel (`8086:`):** Installs `mesa`, `vulkan-intel`, `lib32-mesa`, `lib32-vulkan-intel`, `intel-media-driver`, and `libva-utils`.
  - **Fallback:** Installs universal `mesa` and `lib32-mesa`.

### 4. Desktop Packages & Applications
- **Wayland Session:** `niri`, `noctalia`, `quickshell`, `xwayland-satellite`, `xorg-xwayland`, `wl-clipboard`, `brightnessctl`, `playerctl`, `grim`, `slurp`.
- **Terminal & Shell:** `kitty`, `zsh`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, and `oh-my-posh-bin` (from AUR).
- **Developer Tools:** `neovim`, `opencode`, `nodejs`, `npm`, `python-pynvim`, `python-json5`, `python-tomlkit`, `tree-sitter-cli`, `fzf`, `ripgrep`, `fd`, `bat`, `eza`, `zoxide`, `lazygit`, `btop`, `fastfetch`.
- **Audio & Media:** `pipewire`, `wireplumber`, `pipewire-audio`, `pipewire-pulse`, `pipewire-alsa`, `pipewire-jack`, `pavucontrol`, `mpv`.
- **File Management & Utilities:** `nautilus`, `file-roller`, `gvfs`, `gvfs-mtp`, `gvfs-smb`, `ffmpegthumbnailer`, `loupe`, `gnome-text-editor`, `gnome-calculator`, `gnome-disk-utility`.
- **Qt6 Runtime:** `qt5-wayland`, `qt6-wayland`, `qt6-svg`, `qt6-declarative`, `qt6-5compat`, `qt6-virtualkeyboard`, `qt6-multimedia-ffmpeg`.
- **Typography & Icons:** `ttf-jetbrains-mono-nerd`, `noto-fonts`, `noto-fonts-emoji`, `ttf-liberation`, `adwaita-fonts`, `adw-gtk-theme`, `papirus-icon-theme`.
- **Browser Selection:**
  - `Firefox` *(Default)*: Official repository.
  - `Helium Browser`: Lightweight modern browser (`helium-browser-bin` from AUR).
  - `Chromium`: Official repository.
  - `Brave`: Privacy browser (`brave-bin` from AUR).

### 5. AstraOS System Branding
- Creates `/usr/lib/astraos-release` and symlinks `/etc/os-release` with AstraOS distribution identity:
  ```ini
  NAME="AstraOS"
  PRETTY_NAME="AstraOS"
  ID=astraos
  ID_LIKE=arch
  BUILD_ID=rolling
  ANSI_COLOR="38;2;94;230;242"
  LOGO=astraos-logo
  ```
- Installs AstraOS high-resolution icons into `/usr/share/icons/hicolor/` and rebuilds the icon cache.
- Deploys cosmic wallpapers into `/usr/share/backgrounds/astraos/`.

### 6. GRUB Cosmic Theming
- Installs the AstraOS GRUB theme into `/boot/grub/themes/astra/`.
- Configures `/etc/default/grub` with:
  - `GRUB_DISTRIBUTOR="AstraOS"`
  - `GRUB_THEME="/boot/grub/themes/astra/theme.txt"`
  - `GRUB_GFXMODE="1920x1080,auto"`
  - Kernel parameters: `quiet splash loglevel=3 rd.udev.log_priority=3 vt.global_cursor_default=0`
  - Dual-boot detection via `os-prober`.
- Executes `grub-mkconfig -o /boot/grub/grub.cfg`.

### 7. Plymouth Boot Splash
- Installs the `astra` Plymouth theme (featuring a 24-frame pulsing cosmic star animation) into `/usr/share/plymouth/themes/astra/`.
- Configures `/etc/plymouth/plymouthd.conf` with `Theme=astra` and `ShowDelay=0`.
- Adds the `plymouth` hook to `HOOKS=(... udev plymouth ...)` in `/etc/mkinitcpio.conf`.
- Rebuilds all initramfs images via `mkinitcpio -P` for smooth, flicker-free boot transitions.

### 8. SilentSDDM Display Manager & Presets
- Deploys the minimalist SilentSDDM greeter into `/usr/share/sddm/themes/silent/`.
- Links AstraOS wallpapers and installs seven orbital/space presets into `/usr/share/sddm/themes/silent/configs/`.
- Writes `/etc/sddm.conf.d/astra.conf` with `Current=silent` and `ConfigFile=configs/astra-orbital.conf`.
- Installs the `astra-sddm-theme` preset switcher utility into `/usr/local/bin/`.
- Enables `sddm.service` for automatic graphical login.

### 9. Desktop Dotfiles & User Configuration
- Deploys configurations to both `$HOME` and `/etc/skel` (ensuring existing and future users receive the full setup):
  - `~/.config/niri/`: Scrollable tiling layout, keybindings, window rules, and appearance.
  - `~/.config/noctalia/` & `~/.local/state/noctalia/`: Desktop shell bar, control center, and settings.
  - `~/.config/kitty/`: GPU-accelerated terminal config, transparent styling, and font settings.
  - `~/.config/nvim/`: Full LazyVim starter with automatic lazy.nvim bootstrap and dynamic Noctalia color synchronization.
  - `~/.config/opencode/`: OpenCode AI assistant settings and Matugen theme (`tui.json`, `cli.json`).
  - `~/.config/ohmyposh/`: Cosmic `1_shell.omp.json` prompt theme.
  - `~/.config/quickshell/`: Interactive keybind overlay widget (`Super + Shift + /`).
  - `~/.config/fastfetch/` & `~/.config/btop/`: Customized system monitors.
  - `~/.zshrc`: Shell history, compinit, autosuggestions, and Oh-My-Posh integration.
- Updates GNOME/GTK `dconf` databases.
- Sets the default login shell to `/bin/zsh` via `chsh`.
- Enables essential system services (`NetworkManager`, `bluetooth`, `power-profiles-daemon`, `fstrim`, `systemd-timesyncd`).
- Sets default systemd target to `graphical.target`.

---

## ⌨️ Essential Keyboard Shortcuts

| Shortcut | Action | Description |
|---|---|---|
| `Super + Return` | Open Terminal | Launches Kitty terminal with transparent Noctalia theme. |
| `Super + Space` | App Launcher | Toggles Noctalia application launcher panel. |
| `Super + S` | Control Center | Toggles Noctalia quick settings, audio, and network panel. |
| `Super + B` | Web Browser | Launches default web browser (configured during setup). |
| `Super + E` | File Manager | Opens Nautilus file manager. |
| `Super + Shift + /` | Keybind Cheatsheet | Toggles interactive Quickshell keybinding overlay. |
| `Super + Left / Right` | Navigate Columns | Moves focus left and right along Niri's infinite ribbon. |
| `Super + 1` .. `9` | Switch Workspace | Focuses workspace 1 through 9. |
| `Super + Shift + 1` .. `9` | Move Window | Moves the focused window to workspace 1 through 9. |
| `Super + Alt + L` | Lock Screen | Locks the session with Noctalia lockscreen. |
| `Super + Alt + Space` | Wallpaper Picker | Opens Noctalia interactive wallpaper selector. |
| `Super + Alt + Return` | Noctalia Settings | Opens Noctalia desktop customization interface. |

---

## 🎨 SilentSDDM Preset Switcher

AstraOS includes seven pre-configured presets for the SilentSDDM login greeter. You can switch presets anytime using the `astra-sddm-theme` command:

```bash
# List all available presets
astra-sddm-theme list

# View the current active preset
astra-sddm-theme current

# Switch to a preset (requires root)
sudo astra-sddm-theme set astra-carina
```

### Available Presets:
1. `astra-orbital` — Original AstraOS 4K cyan-orbital artwork *(Default)*
2. `astra-aurora` — Vibrant teal aurora spectrum
3. `astra-ember` — Warm amber celestial dust field
4. `astra-lunar` — Deep violet lunar twilight
5. `astra-earthrise` — NASA Apollo 8 Earthrise (`as08-14-2383`)
6. `astra-carina` — James Webb Space Telescope Cosmic Cliffs
7. `astra-deepfield` — Hubble Deep Field (`PIA12110`)

---

## ⚙️ CLI Options & Non-Interactive Automation

The setup script supports automated, non-interactive installations via command-line arguments:

```bash
Usage: ./setup.sh [OPTIONS]

Options:
  --aur <paru|yay|skip>     Select AUR helper (default: paru)
  --browser <name>          Select browser (firefox|helium|chromium|brave|none)
  -y, --yes                 Non-interactive mode (accepts all defaults)
  --no-drivers              Skip automatic hardware & GPU driver installation
  --no-rebrand              Skip /etc/os-release rebranding
  --no-grub                 Skip GRUB theme installation
  --no-plymouth             Skip Plymouth boot splash installation
  --no-sddm                 Skip SDDM theme installation
  --no-dotfiles             Skip desktop dotfiles deployment
  -h, --help                Show help message
```

*Example non-interactive run:*
```bash
./setup.sh --aur paru --browser firefox --yes
```

---

## 🤝 Upstream Credits & Attributions

AstraOS is made possible by these outstanding open-source projects:

- **[Niri](https://github.com/YaLixDee/niri)** by YaLixDee and contributors *(Scrollable tiling Wayland compositor)*
- **[Noctalia](https://github.com/noctalia-dev/noctalia)** (v5) by Clement Fombonne and the Noctalia team *(Desktop shell, status bar, and control center)*
- **[SilentSDDM](https://github.com/uiriansan/SilentSDDM)** by uiriansan *(Clean, minimalist SDDM greeter)*
- **[LazyVim](https://github.com/LazyVim/LazyVim)** by Folke Lemaitre & **[Neovim](https://github.com/neovim/neovim)** *(High-performance development environment)*
- **[OpenCode](https://opencode.ai)** *(Open-source terminal AI coding assistant)*
- **[Kitty](https://github.com/kovidgoyal/kitty)** by Kovid Goyal *(GPU-accelerated terminal emulator)*
- **[Oh My Posh](https://github.com/JanDeDobbeleer/oh-my-posh)** by Jan De Dobbeleer *(Prompt theme engine)*
- **[Quickshell](https://github.com/outfoxxed/quickshell)** by outfoxxed *(Wayland QML desktop widget toolkit)*
- **[GNU GRUB](https://www.gnu.org/software/grub/)** & **[Plymouth](https://www.freedesktop.org/wiki/Software/Plymouth/)** *(Bootloader and graphical boot splash)*
- **[Arch Linux](https://archlinux.org/)** *(The simple, lightweight, flexible base)*
- **NASA / ESA / CSA / STScI** *(Historic Apollo 8 Earthrise, JWST Carina Nebula, and Hubble Deep Field imagery)*

---

## 📄 License

AstraOS is open-source software licensed under the **[MIT License](LICENSE)**.  
Third-party upstream projects retain their respective open-source licenses (see [`THIRD_PARTY.md`](THIRD_PARTY.md)).
