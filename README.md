# 🌌 AstraOS

**A kind of high-performance, design-driven Linux distribution focused on fluidity, minimalism, and a modern desktop experience.**

AstraOS is a curated Arch-based distribution built for developers and enthusiasts who demand a polished, cohesive environment without the bloat. By pairing the **Niri** tiling compositor with the **Noctalia** aesthetic, AstraOS delivers a workspace that feels alive, physical, and intentional.

![AstraOS Banner](https://raw.githubusercontent.com/AmanicX/astra/main/assets/banner.png) <!-- Placeholder for your banner -->

## ✨ Key Pillars

### 🛠️ The Desktop Stack
- **Compositor**: [Niri](https://github.com/YaLilihan/niri) — A scrollable tiling compositor that redefines how you manage windows.
- **Shell**: [Noctalia v5](https://github.com/ClementFombonne/sddm-noctalia-theme) — A curated visual identity with a focus on depth and translucency.
- **Terminal**: Kitty — GPU-accelerated, fast, and highly configurable.
- **Editor**: Neovim — Pre-baked with an Astra-optimized configuration for a seamless coding experience.

### 🚀 Technical Architecture
- **Kernel**: Linux (Optimized for modern hardware).
- **Bootloader**: GRUB (UEFI-only v1).
- **Filesystem**: Btrfs by default, with automatic snapshotting via Snapper.
- **GPU Support**: First-class support for NVIDIA Maxwell/Pascal/Volta via the 580xx proprietary stack.

### 🎨 Design Philosophy
AstraOS follows a strict "no-slop" design guide. Every pixel, animation curve, and spacing unit is audited to ensure the OS feels premium and cohesive.

## 💿 Installation

AstraOS is distributed as a Live ISO. The built-in **Astra Installer** provides a gum-powered TUI for a streamlined setup.

### Quick Start
1. Download the latest pre-release ISO from the [Releases](#) section.
2. Flash to USB: `dd if=astraos-*.iso of=/dev/sdX bs=4M status=progress`
3. Boot in UEFI mode and follow the installer prompts.

## 📦 Repository Structure

- `/packages`: The source for all `astra-*` branded packages.
- `/manifests`: Declarative lists of every package included in the OS.
- `/scripts`: The build pipeline for the local repository and the ISO.
- `/docs`: Technical specifications and design decisions.

## 🤝 Credits & Acknowledgments

AstraOS is built upon the shoulders of giants. A special thank you to:
- **The Niri Team**: For creating a revolutionary approach to tiling and window management.
- **Clement Fombonne**: For the stunning **Noctalia v5** design, which provides the visual foundation of the AstraOS identity.
- **The Arch Linux Community**: For providing the robust, rolling-release base that makes this possible.

## 📜 License
Distributed under the **MIT License**. See `LICENSE` for more details.

---
*Built with ❤️ by [AmanicX](https://github.com/AmanicX)*
