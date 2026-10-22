<p align="center">
  <img src="packages/astra-branding/files/usr/share/astra/branding/astraos-lockup.svg" alt="AstraOS" width="560">
</p>

<h1 align="center">AstraOS</h1>

<p align="center">
  A focused, design-driven, quiet Linux distribution built around
  <strong>Niri</strong> and <strong>Noctalia v5</strong>.
</p>

<p align="center">
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Base-Arch%20Linux-1793d1?logo=archlinux&logoColor=white&style=flat-square" alt="Arch Linux"></a>
  <a href="https://github.com/YaLixDee/niri"><img src="https://img.shields.io/badge/Compositor-Niri-67e8f9?style=flat-square" alt="Niri"></a>
  <a href="https://github.com/noctalia-dev/noctalia"><img src="https://img.shields.io/badge/Shell-Noctalia%20v5-2dd4bf?style=flat-square" alt="Noctalia v5"></a>
  <a href="https://tauri.app"><img src="https://img.shields.io/badge/Installer-Rust%20%2B%20Tauri%202-ffc131?logo=tauri&logoColor=black&style=flat-square" alt="Rust + Tauri 2"></a>
  <img src="https://img.shields.io/badge/Boot-UEFI%20Only-2ea043?style=flat-square" alt="UEFI Only">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-38bdf8?style=flat-square" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/Status-Release%20Candidate-f59e0b?style=flat-square" alt="Release Candidate">
</p>

---

## 🌌 Overview

**AstraOS** is an Arch-based Linux distribution crafted for developers, creators, and enthusiasts who desire a coherent, aesthetic, and distraction-free computing experience out of the box. 

Instead of presenting an empty window manager or bloated desktop environment, AstraOS harmoniously pairs the innovative scrollable tiling model of **Niri** with the refined, modern Wayland shell of **Noctalia v5**. It handles the essential details often left incomplete: a daily-pinned Arch Linux Archive snapshot, pre-baked LazyVim with instant startup, GPU-accelerated Kitty terminal with Oh My Posh, a live desktop environment with automatic installer launch, and SilentSDDM login presets featuring high-resolution space imagery.

> [!IMPORTANT]
> **UEFI Systems Only:** AstraOS is engineered strictly for modern UEFI hardware with GPT disk partitioning. Legacy BIOS/CSM and Secure Boot must be disabled.

---

## ✨ Features & Architecture

| Component | Upstream Choice | Description |
|---|---|---|
| **Base System** | Arch Linux | Pinned to Arch Linux Archive (`2026/10/18`) for predictable, reproducible builds. |
| **Window Compositor** | [Niri](https://github.com/YaLixDee/niri) | Scrollable tiling Wayland compositor arranging windows in an infinite horizontal ribbon. |
| **Desktop Shell** | [Noctalia](https://github.com/noctalia-dev/noctalia) (v5) | Contemporary status bar, quick settings, workspace overview, and notifications. |
| **Display Manager** | [SilentSDDM](https://github.com/uiriansan/SilentSDDM) | Minimalist login greeter featuring 7 AstraOS orbital & deep space presets. |
| **Terminal** | Kitty + Zsh | GPU-accelerated terminal paired with Oh My Posh (`1_shell`) and autosuggestions. |
| **Editor** | Neovim + [LazyVim](https://github.com/LazyVim/LazyVim) | Pre-baked, zero-wait editor environment tailored with custom AstraOS color scheme. |
| **Filesystem** | Btrfs | Standard subvolumes (`@`, `@home`, `@log`, `@pkg`, `@snapshots`) with zstd compression. |
| **Bootloader** | GNU GRUB (Target) / systemd-boot (Live) | UEFI bootloader with automatic multi-boot OS detection via `os-prober`. |
| **Installer** | Rust + Tauri 2 | Read-only storage planning GUI over an unprivileged-to-root non-interactive Bash engine. |

---

## 🚀 The Live ISO Experience

The AstraOS installation image is a fully functional desktop session:
- **Direct Live Session:** Autologins `root` on `tty1` straight into the **Niri + Noctalia** environment—no display manager delay or intermediate rescue shell.
- **Auto-Running GUI Installer:** The AstraOS installer window launches automatically once the desktop initializes.
- **Live Network Management:** NetworkManager with `iwd` backend; manage connections via `nmtui` or `iwctl`.
- **Keyboard Shortcuts:**
  - `Super + Return`: Open Kitty Terminal
  - `Super + Space`: Application Launcher
  - `Super + Shift + /`: Interactive Keybinding Cheat Sheet
  - `Super + Left / Right`: Scroll across Niri columns

---

## 🛠️ The AstraOS Installer (Rust + Tauri 2)

AstraOS ships a purpose-built installer built with **Rust** and **Tauri 2**:
- **Strict Read-Only Planning:** Disk inspection and partition calculations never write or modify partition tables while browsing or configuring options.
- **Storage Modes:** Supports **Whole Disk Erase** (automatic 1 GiB ESP + 34+ GiB Btrfs root), **Free Space Partitioning**, **Manual Partition Assignment**, and **Pre-mounted Filesystems**.
- **Hardware Validation:** Enforces the documented 35 GiB total floor (1 GiB ESP + 34 GiB root) in both pure Rust and Bash verification engines.
- **Safety Guarantee:** Passwords and plan configurations are handled strictly in `/run/astra-install/plan.json` (mode `0600`), parsed and instantly deleted before any destructive writes begin.

---

## 🎨 SilentSDDM Wallpaper Presets & Switcher

AstraOS installs [SilentSDDM](https://github.com/uiriansan/SilentSDDM) customized with seven distinctive themes. Switch them instantly using the `astra-sddm-theme` command:

```bash
# List all installed presets and assigned wallpapers
astra-sddm-theme list

# View current preset
astra-sddm-theme current

# Switch to a preset (requires root)
sudo astra-sddm-theme set astra-carina
```

### Available Presets:
1. `astra-orbital` — Original AstraOS 4K cyan-orbital artwork (Default)
2. `astra-aurora` — Generated teal aurora spectrum
3. `astra-ember` — Generated warm amber celestial field
4. `astra-lunar` — Generated deep violet lunar glow
5. `astra-earthrise` — NASA Apollo 8 Earthrise (`as08-14-2383`)
6. `astra-carina` — NASA/ESA/CSA James Webb Space Telescope Cosmic Cliffs
7. `astra-deepfield` — NASA/ESA Hubble Deep Field (`PIA12110`)

---

## 📋 System Requirements

- **Processor:** 64-bit x86_64 CPU (Intel / AMD)
- **RAM:** 4 GiB minimum (8 GiB recommended)
- **Storage:** Minimum 35 GiB available disk space (1 GiB FAT32 ESP + 34 GiB Btrfs root)
- **Firmware:** UEFI (Legacy BIOS / CSM disabled; Secure Boot disabled)
- **Network:** Active internet connection during installation for package downloads

---

## 📦 Building From Source

Building the complete ISO requires an Arch Linux host or WSL2 Arch distribution:

```bash
# Clone the repository
git clone https://github.com/AmanicX/astra-os.git astraos
cd astraos

# 1. Build the local offline package repository (repo/x86_64)
sudo ./scripts/build-repo.sh --build

# 2. Build the Rust / Tauri 2 installer release binary
./scripts/build-installer.sh --build

# 3. Build the final bootable ISO image
sudo ASTRA_ISO_APPROVED=1 ./scripts/build-iso.sh --build
```

The compiled bootable ISO is generated in the `out/` directory (e.g. `out/astraos-YYYY.MM.DD-x86_64.iso`).

---

## 🤝 Upstream Credits & Attributions

AstraOS stands proudly on the shoulders of brilliant open-source creators and engineers:

- **[Niri](https://github.com/YaLixDee/niri)** by **YaLixDee and contributors** (GPL-3.0-or-later)  
  *For designing and implementing the fluid, scrollable tiling window compositor that defines AstraOS.*

- **[Noctalia](https://github.com/noctalia-dev/noctalia)** (v5) by **Clement Fombonne and the Noctalia team** (MIT)  
  *For the elegant Wayland desktop shell, status bar, and modern control interface.*

- **[SilentSDDM](https://github.com/uiriansan/SilentSDDM)** by **uiriansan and contributors** (GPL-3.0)  
  *For the clean, minimalist display manager theme adapted with AstraOS presets and switcher.*

- **[GNU GRUB](https://www.gnu.org/software/grub/)** by the **Free Software Foundation** (GPL-3.0-or-later)  
  *For the reliable UEFI bootloader providing Btrfs root snapshot booting and automated multi-boot discovery.*

- **[LazyVim](https://github.com/LazyVim/LazyVim)** by **Folke Lemaitre** and **[Neovim](https://github.com/neovim/neovim)** (Apache-2.0 / Vim License)  
  *For the high-performance, pre-configured development and editing foundation.*

- **[Arch Linux](https://archlinux.org/)** and the **Arch Linux Archive** (GPL)  
  *For the flexible, cutting-edge distribution base and daily snapshot reproducibility.*

- **[Kitty](https://github.com/kovidgoyal/kitty)** by **Kovid Goyal** (GPL-3.0)  
  *For the GPU-accelerated terminal emulator providing silky smooth text rendering.*

- **[Oh My Posh](https://github.com/JanDeDobbeleer/oh-my-posh)** by **Jan De Dobbeleer** (MIT)  
  *For the responsive, customized shell prompt engine.*

- **[Quickshell](https://github.com/outfoxxed/quickshell)** by **outfoxxed** (LGPL-3.0)  
  *For the Wayland QML toolkit powering shell overlays and keybinding helpers.*

- **[NASA](https://www.nasa.gov/) / ESA / CSA / STScI** (Public Domain)  
  *For the historic Apollo 8 Earthrise, James Webb Space Telescope Carina Nebula, and Hubble Deep Field imagery.*

---

## 📄 License

AstraOS is open-source software licensed under the **[MIT License](LICENSE)**.  
Third-party upstream projects, libraries, and images retain their respective licenses (see [`THIRD_PARTY.md`](THIRD_PARTY.md)).

---

<p align="center">
  Crafted with care by <a href="https://github.com/AmanicX"><strong>AmanicX</strong></a> and the AstraOS contributors.
</p>
