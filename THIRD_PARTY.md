# Third-Party Components and Licenses

Status: **draft for Phase 0 gate.** Every asset must be cleared before it is
placed in the ISO. An unclear license is a release blocker, not a warning.

## Components installed or proposed from Arch repositories

| Component | Version / source | License | Redistributable | Notes |
|---|---|---|---|---|
| niri | 26.04-1, Arch extra | GPL-3.0-or-later | Yes | Window compositor |
| Noctalia | 5.3.0-1, Arch extra | MIT | Yes | Desktop shell |
| Quickshell | 0.3.2-1, Arch extra | LGPL-3.0-only | Yes | QML toolkit used by Noctalia and the keybind overlay |
| kitty | 0.49.2-1, Arch extra | GPL-3.0-only | Yes | Terminal |
| SDDM | 0.21.0-7, Arch extra | GPL-2.0-or-later | Yes | Display manager |
| PipeWire / WirePlumber | 1.6.9 / 0.5.18, Arch extra | MIT | Yes | Audio stack |
| NetworkManager | 1.58.1-2, Arch extra | GPL-2.0-or-later | Yes | Networking |
| BlueZ | 5.87-2, Arch extra | GPL-2.0-or-later | Yes | Bluetooth |
| power-profiles-daemon | 0.30-1, Arch extra | GPL-3.0-or-later | Yes | Power profiles |
| UPower | 1.91.5-1, Arch extra | GPL-2.0-or-later | Yes | Battery/device service |
| Firefox | 158.0-1, Arch extra | MPL-2.0 | Yes | Web browser |
| mpv | 0.41.0-6, Arch extra | GPL-2.0-or-later AND LGPL-2.1-or-later | Yes | Media player |
| btop | 1.4.7-1, Arch extra | Apache-2.0 | Yes | Resource monitor |
| fastfetch | 2.70.0-1, Arch extra | MIT | Yes | System info |
| opencode | 2.0.32-1, Arch extra | MIT | Yes | Coding agent |
| Neovim | 0.12.6-1, Arch extra | Apache-2.0 / Vim license | Yes | Editor |
| LazyVim | pinned in `lazy-lock.json` | Apache-2.0 | Yes | Neovim distribution |
| adw-gtk-theme | 6.5-1, Arch extra | LGPL-2.1-only | Yes | GTK theme |
| papirus-icon-theme | 20260801-1, Arch extra | GPL-3.0 | Yes | Icon theme |
| ttf-jetbrains-mono-nerd | 3.5.1-2, Arch extra | OFL-1.1-no-RFN | Yes | Terminal font |
| Noto fonts | Arch extra | OFL-1.1 | Yes | Proposed; not installed on the audit host |
| Liberation fonts | Arch extra | OFL-1.1 | Yes | Proposed |
| `linux-firmware` | Arch core | Mixed firmware licenses | Yes, under upstream terms | Includes proprietary firmware blobs |
| NVIDIA proprietary driver | Arch extra / AUR 580xx | NVIDIA license | Yes, under NVIDIA terms | Not on the audit host |

## Prompt/theme assets

| Component | Source | License | Redistributable | Notes |
|---|---|---|---|---|
| `1_shell.omp.json` | Upstream Oh My Posh theme | MIT | Yes | Byte-identical to upstream; verified by SHA-256 |
| Oh My Posh binary | AUR `oh-my-posh-bin` 31.8.0 / upstream | MIT | Yes | Pinned package; no update notice |
| Noctalia integration TOML | Owner-authored, based on Noctalia docs | MIT | Yes | Shipped in astra-desktop-config |
| niri config and keybinds | Owner-authored/modified | MIT | Yes | Shipped in astra-desktop-config |
| kitty config/theme | Owner-authored/modified plus Noctalia-generated palette | MIT | Yes | Shipped in astra-desktop-config |
| keybind overlay (`gen-keybinds.py`, `shell.qml`, `keybinds-toggle`) | Owner-authored | MIT | Yes | Shipped in astra-keybinds |
| Neovim config | LazyVim starter derivative, Apache-2.0 | Apache-2.0 | Yes | Custom `kitty-theme.lua` is owner-authored |
| Neovim plugins | 33 plugins pinned by `lazy-lock.json` | MIT / Apache-2.0 / GPL-3.0; generated in `manifests/nvim-plugins.tsv` | Yes, with source URLs and license files recorded | Includes GPL-3.0 `bufferline.nvim` and `nvim-lint`; unmodified upstream plugins |
| Noctalia SDDM theme | GitHub `ClementFombonne/sddm-noctalia-theme`, commit `92bf8e6` | GPLv3 code; Tabler icons MIT | Superseded | Superseded by SilentSDDM (D-034); not shipped |
| SDDM astronaut theme | GitHub `keyitdev/sddm-astronaut-theme`, commit `abb3163c` | GPL-3.0-or-later code | Superseded | Superseded by SilentSDDM (D-034); not shipped |
| SilentSDDM | GitHub `uiriansan/SilentSDDM`, commit `d477613b07ca13729af20cb4699b308ac7348d2f` | GPL-3.0 | Yes, with license and notices | Installed under `/usr/share/sddm/themes/silent/`; upstream demo media removed; configured via AstraOS presets and `/etc/sddm.conf.d/astra.conf` |
| Original Wallpapers | Original AstraOS orbital artwork and generated variants (`astraos-default.png`, `astraos-aurora.png`, `astraos-ember.png`, `astraos-lunar.png`) | MIT / Project License | Yes | 4K assets generated from SVG sources under `packages/astra-branding/` |
| archinstall | Arch Linux upstream package `archinstall` 4.5-1 | GPL-3.0-only | Yes | Upstream installation engine and disk partition models |
| python-textual | Textualize upstream package `python-textual` 8.2.8-2 | MIT | Yes | Terminal UI framework for the AstraOS installer |
| astra-installer | AstraOS terminal installer package | GPL-3.0-only | Yes | Uses and derives from archinstall; licensed under GPL-3.0. Rest of AstraOS remains MIT. |
| NASA Earthrise | NASA Apollo 8, image `as08-14-2383` (`astraos-earthrise.jpg`) | Public Domain (NASA) | Yes | Retrieved 2026-10; NASA public domain imagery policy |
| NASA Carina Nebula | NASA/ESA/CSA James Webb Space Telescope (`astraos-carina.png`) | Public Domain / CC-BY-4.0 | Yes | Retrieved 2026-10; STScI/NASA/ESA/CSA |
| NASA Hubble Deep Field | NASA/ESA Hubble Space Telescope, `PIA12110` (`astraos-deepfield.jpg`) | Public Domain (NASA/ESA) | Yes | Retrieved 2026-10; NASA JPL/STScI public domain |
| Steam | `steam` 1.0.0.87-3, Arch multilib | LicenseRef-steam-subscriber-agreement | Yes, under Valve's terms | Owner-approved; target-only; multilib closure required |

## Explicitly not shipped

- Browser profiles, cookies, logins, bookmarks and history.
- Keyrings, tokens, SSH/GPG keys, `.netrc`, `.env`, git credentials.
- Shell/editor history, clipboard entries, recent files.
- Personal Documents, Downloads, Pictures, Screenshots and NTFS data.
- Noctalia community palette/template caches.
- Backup directories.
- Cloudflare WARP client and service (unless owner explicitly requests it).

## Release gate

Before an ISO is published:

1. Every row above must have a final license and a redistributable decision.
2. The chosen SDDM theme's removed wallpaper/screenshot must be absent from the
   package. For the astronaut theme, the bundled backgrounds, previews and
   fonts are removed; only GPL code, components and icons are shipped.
3. The wallpaper must be original AstraOS art or carry a written license
   confirmation. The unknown-license image is never shipped.
4. The Neovim plugin licenses must be generated from the pinned plugin tree.
5. `scripts/scrub-check.sh` must pass on the repository and the ISO tree.
