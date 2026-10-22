# AstraOS — Upstream Credits & Attributions

AstraOS is built upon the ingenuity, craft, and generosity of the open-source community. This document formally recognizes and thanks the creators, maintainers, and contributors whose projects make AstraOS possible.

---

## 1. Core Desktop & Window Management

### [Niri](https://github.com/YaLixDee/niri)
- **Author / Maintainers:** YaLixDee and contributors
- **License:** GPL-3.0-or-later
- **Role in AstraOS:** Window Compositor
- **Contribution:** Niri provides the groundbreaking scrollable tiling window manager architecture that defines the window layout and fluid interaction model of AstraOS.

### [Noctalia](https://github.com/noctalia-dev/noctalia) (v5)
- **Author / Maintainers:** Clement Fombonne and the Noctalia development team
- **License:** MIT
- **Role in AstraOS:** Desktop Shell & UI Environment
- **Contribution:** Noctalia v5 provides the sleek, modern top bar, system controls, quick settings, workspace visualizer, and notification center.

### [Quickshell](https://github.com/outfoxxed/quickshell)
- **Author / Maintainers:** outfoxxed and contributors
- **License:** LGPL-3.0-only
- **Role in AstraOS:** QML Shell Toolkit
- **Contribution:** Powers Noctalia's native Wayland QML interface and the AstraOS keybinding cheat sheet overlay.

---

## 2. Bootloader, Display & Session Greeter

### [SilentSDDM](https://github.com/uiriansan/SilentSDDM)
- **Author / Maintainers:** uiriansan and contributors
- **License:** GPL-3.0-only
- **Role in AstraOS:** Display Manager Greeter Theme
- **Contribution:** Provides the minimalist, calm login interface used in installed AstraOS systems, customized with 7 AstraOS wallpaper presets and an automated preset switcher (`astra-sddm-theme`).

### [GNU GRUB](https://www.gnu.org/software/grub/)
- **Author / Maintainers:** Free Software Foundation and the GNU GRUB team
- **License:** GPL-3.0-or-later
- **Role in AstraOS:** Installed System Bootloader
- **Contribution:** Reliable UEFI bootloader providing Btrfs subvolume boot capability and automated multi-boot OS detection via `os-prober`.

### [systemd-boot](https://systemd.io/) & [archiso](https://gitlab.archlinux.org/archlinux/archiso)
- **Author / Maintainers:** The systemd project & Arch Linux team
- **License:** LGPL-2.1-or-later / GPL-3.0
- **Role in AstraOS:** Live ISO Bootloader & Image Builder
- **Contribution:** Powers the clean, branded UEFI boot menu on the live installer medium.

---

## 3. Terminal & Shell Experience

### [Kitty](https://github.com/kovidgoyal/kitty)
- **Author / Maintainers:** Kovid Goyal and contributors
- **License:** GPL-3.0-only
- **Role in AstraOS:** GPU-Accelerated Terminal Emulator
- **Contribution:** Provides lightning-fast terminal rendering, true color, and font glyph support configured with the AstraOS palette.

### [Oh My Posh](https://github.com/JanDeDobbeleer/oh-my-posh)
- **Author / Maintainers:** Jan De Dobbeleer and contributors
- **License:** MIT
- **Role in AstraOS:** Shell Prompt Engine
- **Contribution:** Powers the responsive, informative `1_shell` prompt across Zsh sessions.

### [Zsh](https://www.zsh.org/) & Plugins
- **Author / Maintainers:** Zsh Development Group, zsh-users
- **License:** MIT-like / GPL
- **Role in AstraOS:** Interactive Login Shell
- **Contribution:** Enhanced with fast-syntax-highlighting, zsh-autosuggestions, and history-substring-search.

---

## 4. Development & Editing

### [LazyVim](https://github.com/LazyVim/LazyVim) & [Neovim](https://github.com/neovim/neovim)
- **Author / Maintainers:** Folke Lemaitre (LazyVim), Neovim core team and community
- **License:** Apache-2.0 / Vim License
- **Role in AstraOS:** Default Code & Configuration Editor
- **Contribution:** Pre-baked, pinned, zero-delay LazyVim installation with full LSP, Treesitter, and custom AstraOS Kitty color coordination.

---

## 5. Visual Artwork & Astronomy Imagery

### Original AstraOS Artwork
- **Author / Designer:** AmanicX (AstraOS Project)
- **License:** MIT / Project License
- **Assets:** AstraOS star mark, wordmark, lockup SVG, and the orbital 4K wallpapers (`astraos-default.png`, `astraos-aurora.png`, `astraos-ember.png`, `astraos-lunar.png`).

### [NASA](https://www.nasa.gov/) Imagery
- **Earthrise (Apollo 8):** NASA / William Anders (`as08-14-2383`) — Public Domain
- **Carina Nebula:** NASA / ESA / CSA / STScI (James Webb Space Telescope) — Public Domain / CC-BY-4.0
- **Hubble Deep Field:** NASA / ESA (`PIA12110`) — Public Domain

---

## 6. Distribution Foundation

### [Arch Linux](https://archlinux.org/) & Arch Linux Archive (ALA)
- **Maintainers:** The Arch Linux team and Aaron Griffin, Judd Vinet
- **License:** Various open-source licenses
- **Role in AstraOS:** Operating System Base
- **Contribution:** Provides the lightweight, rolling base packages pinned to reproducible daily snapshots for rock-solid stability.

---

*Thank you to all authors, maintainers, and community members who build the free and open-source software that AstraOS is proud to ship.*
