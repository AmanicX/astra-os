# AstraOS Phase 0 Audit

Status: **read-only audit complete; gate approved with changes on 2026-10-19.**
The owner's decisions are summarized in `docs/PROGRESS.md` (Gate outcome) and
`docs/DECISIONS.md` (D-025). The audit itself remains the historical record.
Date: 2026-10-19
Method: inspection only (`pacman -Q*`, `find`, `sed`, `grep`, `fc-list`,
`lspci`, `bootctl`, `systemctl`, `niri validate`, package APIs). No host config,
package, service or disk was modified.

## 1. Host profile

| Item | Finding |
|---|---|
| Machine | HP ProBook 455R G6, chassis type 10 (notebook) |
| Firmware | UEFI 2.50, Secure Boot disabled, systemd-boot currently used |
| OS | Arch Linux rolling, kernel 7.2.11-arch1-1 |
| CPU | AMD Ryzen 5 3500U (4 cores / 8 threads) |
| GPU | AMD Radeon Vega (Picasso/Raven2), `amdgpu` in use; **no NVIDIA GPU** |
| RAM | 13 GiB total, 4 GiB zram swap active |
| Storage | 238.5 GB SSD; 128 GiB free; Btrfs root on `/dev/sda2`; separate vfat `/boot`; NTFS data partitions |
| Network | Realtek RTL8822BE Wi-Fi + Bluetooth, Realtek RTL8111 Ethernet |
| Session | niri 26.04 + Noctalia 5.3.0, Wayland, Xwayland via xwayland-satellite |
| Display manager | SDDM 0.21.0, enabled and running; active theme `sddm-astronaut-theme` |
| Battery | Battery present, currently discharging at 50% |

The audited machine is the development laptop, not the eventual target
hardware. It is sufficient for AMD-path verification. NVIDIA and Intel paths
must be tested with fixtures and QEMU; real hardware verification remains an
owner task.

## 2. Build-environment blockers

These do not affect the read-only audit, but they block later phases:

1. **`sudo` requires a password.** Package installation, `arch-chroot` with
   mounts, loop devices and QEMU image preparation cannot start. The agent
   will not ask for or store the password. A passwordless sudo rule for the
   workspace, or a prepared build environment, is required.
2. **Missing tools:** `qemu-system-x86_64`, `qemu-img`, OVMF, `grub`,
   `snapper`, `gum`, `shellcheck`, `sgdisk`. `/dev/kvm` exists, but `losetup`
   is denied without privilege.
3. **Disk headroom:** 128 GiB free. The brief estimates ~60 GiB. That is
   enough for one build with cache/chroot/VM images, but not comfortable for
   repeated ISO builds. The owner must confirm before the heavy build.
4. **Incomplete sync database:** the host's pacman DB reports some standard
   packages as missing. Availability was checked against the Arch package API
   and AUR RPC instead (see D-013).

## 3. Package audit

- 96 explicitly installed packages.
- 3 foreign packages: `cloudflare-warp-bin`, `yay-bin`, `yay-bin-debug`.
- 744 packages installed in total.
- Raw lists: `manifests/audit-explicit.txt`,
  `manifests/audit-foreign.txt`.
- Per-package classification: `manifests/audit-classification.tsv`.

### 3.1 Desktop stack actually present

| Component | Version | Repo | License |
|---|---|---|---|
| niri | 26.04-1 | extra | GPL-3.0-or-later |
| Noctalia | 5.3.0-1 | extra | MIT |
| Quickshell | 0.3.2-1 | extra | LGPL-3.0-only |
| kitty | 0.49.2-1 | extra | GPL-3.0-only |
| SDDM | 0.21.0-7 | extra | GPL-2.0-or-later |
| xwayland-satellite | 0.8.3-1 | extra | check upstream |
| NetworkManager | 1.58.1-2 | extra | GPL-2.0-or-later |
| BlueZ | 5.87-2 | extra | GPL-2.0-or-later |
| power-profiles-daemon | 0.30-1 | extra | GPL-3.0-or-later |
| UPower | 1.91.5-1 | extra | GPL-2.0-or-later |
| PipeWire / WirePlumber | 1.6.9 / 0.5.18 | extra | MIT |

Noctalia contains its own polkit agent, NetworkManager client, BlueZ agent,
PipeWire client and UPower integration (verified with `strings` and package
metadata). A separate `polkit-gnome` is not spawned by the audited niri
config.

### 3.2 Apps actually present

Firefox, Nautilus (installed as a dependency, not explicit), file-roller, mpv,
btop, fastfetch, opencode, Neovim, lazygit, kitty, zsh with
autosuggestions/syntax-highlighting, fzf, fd, nodejs/npm, tree-sitter-cli,
python-pynvim/json5/tomlkit.

### 3.3 Not installed but named in the build brief

`grub`, `snapper`, `snap-pac`, `grub-btrfs`, `gum`, `cups` stack,
`noto-fonts*`, `ttf-liberation`, `gvfs-mtp`, `gvfs-smb`,
`ffmpegthumbnailer`, `qt6-5compat`, `steam` and its 32-bit stack,
`loupe`, `gimp`, a PDF viewer, calculator, text editor and disk utility.

These become manifest candidates, not audit facts. Availability was verified
against the Arch package API where the local sync DB was unreliable.

### 3.4 Packages that look like leftovers or personal extras

These are installed explicitly but are not referenced by the audited niri,
Noctalia, kitty, zsh or Neovim configs:

`fuzzel`, `mako`, `waybar`, `swaybg`, `swayidle`, `swaylock`,
`network-manager-applet`, `nwg-look`, `seatd`, `htop`, `nano`, `vim`,
`tor-browser-launcher`, `cloudflare-warp-bin`, `yay-bin`, `yay-bin-debug`.

They are proposed for exclusion from the target unless the owner says
otherwise. `archinstall` and `archiso` are build/maintenance tools and are not
target desktop apps. `base-devel`, `cmake`, `make`, `python-pip` are dev/build
tools; the target keeps a small development baseline for LazyVim and package
building, not the full audited set.

### 3.5 Hardware-specific packages

The host has both AMD and Intel open-source graphics packages installed
(`vulkan-radeon`, `vulkan-intel`, `intel-media-driver`, `libva-intel-driver`,
`libvpl`, `vpl-gpu-rt`, `vulkan-nouveau`, `xf86-video-amdgpu/ati/nouveau`).
Only the AMD path is relevant to this laptop. Intel/NVIDIA packages belong in
the offline repository and in fixtures, not in this machine's installed set.

Current package reality, verified against the Arch API:

- `mesa` now provides `libva-mesa-driver`; the separate package is gone.
- `mesa-vdpau` and `lib32-mesa-vdpau` are absent from current repositories.
- `nvidia-580xx-*` exists only in the AUR:
  `nvidia-580xx-dkms` 580.178.04-4, `nvidia-580xx-utils` 580.178.04-4,
  `lib32-nvidia-580xx-utils` 580.178.04-1, `nvidia-580xx-settings`
  580.178.04-1, plus the OpenCL variants.
- `paru` is AUR-only; `oh-my-posh-bin` 31.8.0-1 is AUR and matches the
  audited binary version.

### 3.6 Manifest verification

All non-comment package names in the target and ISO manifests were checked on
2026-10-19. The local sync database resolved 158 of 166 names; the remaining 8
resolved through the AUR RPC. There are **no unresolved package names**.

| Source | Count | Details |
|---|---|---|
| Arch official repositories | 158 | resolved with `pacman -Si` |
| AUR | 8 | `paru`, `oh-my-posh-bin`, and the six `nvidia-580xx`/OpenCL packages |
| Unresolved | 0 | — |

The AUR versions match `manifests/aur.txt` (paru 2.1.0-2, oh-my-posh-bin
31.8.0-1, the 580xx set at 580.178.04-4 or -1). Own `astra-*` packages are
built from this repository and were excluded from the lookup. The full dated
result is in `manifests/package-verification-2026-10-19.tsv`.

## 4. Configuration inventory

All paths are relative to the audit user's home unless absolute.

| Area | Real location | Finding | Proposed action |
|---|---|---|---|
| niri | `~/.config/niri/config.kdl` | Valid; spawns `noctalia` and `qs -c keybinds -d`; includes `keybinds.kdl`, `noctalia.kdl`, `kitty-appearance.kdl`; specific monitor output block is commented out | Include, template XKB, remove personal monitor assumptions |
| niri keybinds | `~/.config/niri/keybinds.kdl` | 190+ binds; Noctalia IPC, kitty, Nautilus, browser wrapper, keybind toggle | Include as-is after path de-personalization |
| Noctalia package config | `~/.config/noctalia/noctalia-integration.toml` | Wallpaper, backdrop, hot corners, clipboard, lockscreen, theme source | Include sanitized |
| Noctalia runtime settings | `~/.local/state/noctalia/settings.toml` | Live settings; city name, `eDP-1` monitor keys, absolute wallpaper path, bar layout, theme Ayu/Oxocarbon | Include a sanitized profile; exclude raw state |
| Noctalia caches | `~/.local/state/noctalia/community-*`, `clipboard/` | Downloaded palettes/templates and encrypted clipboard entries | Exclude entirely |
| kitty | `~/.config/kitty/kitty.conf`, `themes/noctalia.conf`, `posh-font.conf` | No shader files; animation is the cursor trail configuration; JetBrainsMono Nerd Font | Include, regenerate theme through Noctalia |
| zsh | `~/.zshrc` | No `.zshenv`, no `~/.config/zsh`; official zsh-autosuggestions and zsh-syntax-highlighting packages; no plugin manager | Include |
| `1_shell` | `~/.config/ohmyposh/1_shell.omp.json` | SHA-256 matches upstream Oh My Posh theme; MIT | Include with attribution |
| Oh My Posh binary | `~/.local/bin/oh-my-posh` | Manual binary 31.8.0 | Package from pinned AUR source; do not copy the binary |
| Neovim | `~/.config/nvim` | LazyVim starter clone, Apache-2.0; 33 plugins pinned by `lazy-lock.json`; custom `kitty-theme.lua`; `checker.enabled = true` | Include config/lock; pre-bake plugins/parsers/Mason; disable update checker |
| Neovim data | `~/.local/share/nvim/{lazy,mason,site}` | Installed plugins, parsers, Mason tools | Rebuild at ISO time; do not copy personal data |
| SDDM config | `/etc/sddm.conf` | `Current=sddm-astronaut-theme`; no `/etc/sddm.conf.d/` | Replace with Astra config and chosen theme |
| SDDM themes | `/usr/share/sddm/themes/sddm-astronaut-theme`, `sddm-noctalia-theme` | Both GPLv3 code; astronaut active; astronaut assets have unknown origins; Noctalia theme has a bundled wallpaper and Tabler font license | **Owner decision blocked by licensing** |
| Keybind overlay | `~/.config/quickshell/keybinds/{gen-keybinds.py,shell.qml,keybinds.json}`, `~/.local/bin/keybinds-toggle` | Quickshell + Python; JSON is generated and contains an absolute home path | Package generator/QML; generate JSON at build/login; no absolute path |
| Nautilus | `~/.config/nautilus` empty; dconf `org/gnome/nautilus/*` | List view, zoom, window size; no scripts/extensions/bookmarks | Include dconf subset; add gvfs extras per brief |
| GTK/dconf | `~/.config/gtk-3.0`, `gtk-4.0`, `~/.config/dconf/user` | `adw-gtk3-dark`, `Papirus-Dark`, cursor Adwaita 24, Adwaita Sans 11 / Mono 11; Noctalia-generated color CSS | Ship defaults; exclude generated per-user state |
| mpv | none | No `~/.config/mpv` | Ship a minimal Astra default or use upstream defaults |
| btop | `~/.config/btop/themes/noctalia.theme` only | No `btop.conf` | Ship theme; generate main config |
| fastfetch | `~/.config/fastfetch/themes/noctalia.jsonc` only | No `config.jsonc` | Ship Astra branding config |
| XDG | `~/.config/user-dirs.dirs` | Standard dirs plus `Projects`; no `mimeapps.list`; default browser `firefox.desktop` | Include generic user-dirs; set browser default explicitly |
| opencode | `~/.config/opencode/{opencode.json,cli.json,tui.json,themes/matugen.json,commands/}` | Theme/config present; `service.json` contains a credential; config launches `npx ...@latest`; no `auth.json` | Include theme/config; exclude `service.json`, DB, logs, skills; remove/replace network MCP |
| Fonts | system packages only | 189 font files; JetBrainsMono Nerd Font; no user-installed fonts; Noto absent | Add Noto/emoji/CJK/Liberation to manifest |
| Wallpaper | `~/Pictures/Wallpapers/` | One 7680x4320 JPEG; active in Noctalia; filename suggests a wallpaper-download site | **License unclear; owner must confirm rights** |
| Backups | `~/backup`, `~/.config/*backup*`, `~/.config/desktop-backup-*` | Copies of niri/Noctalia configs with personal paths | Exclude entirely |

## 5. Services

System units enabled on the audit host:

`bluetooth`, `NetworkManager`, `NetworkManager-dispatcher`,
`NetworkManager-wait-online`, `power-profiles-daemon`, `sddm`, `seatd`,
`systemd-timesyncd`, `warp-svc`, `getty@`, `systemd-userdbd.socket`,
`remote-fs.target`.

User units enabled:

`wireplumber`, `xdg-user-dirs`, `gnome-keyring-daemon.socket`,
`p11-kit-server.socket`, `pipewire-pulse.socket`, `pipewire.socket`.

Four TPM-related systemd units are failed on this host. They are host-specific
and not part of the AstraOS design; the target must be checked with
`systemctl --failed` after install.

## 6. Fonts, themes, wallpaper

- GTK theme: `adw-gtk3-dark` (package `adw-gtk-theme`, LGPL-2.1-only).
- Icon theme: `Papirus-Dark` (package `papirus-icon-theme`, GPL-3.0).
- Cursor: Adwaita, size 24.
- Interface font: Adwaita Sans 11; monospace: Adwaita Mono 11.
- Terminal font: JetBrainsMono Nerd Font (OFL-1.1-no-RFN).
- No Noto fonts, emoji font, CJK font or Liberation font installed.
- Wallpaper: 7680x4320 progressive JPEG, 1.6 MB, active in Noctalia. Source
  filename points at a public wallpaper site; no license or author metadata
  was found. **Not cleared for redistribution.**
- Both SDDM themes are third-party; see the licensing section.

## 7. Secrets and personal data found

These are **never copied**:

| Source | Why |
|---|---|
| `~/.config/opencode/service.json` | Contains a service password/token |
| `~/.local/share/opencode/opencode.db`, `opencode.log`, shell state | Session data and possible credentials |
| `~/.local/share/keyrings/`, `login.keyring`, `user.keystore` | Keyring secrets |
| `~/.local/share/vitest/.vitest-secret-token` | Test token |
| `~/.local/state/noctalia/clipboard/` | Encrypted clipboard history |
| Firefox profiles under `~/.config/mozilla/firefox/` | Cookies, logins, history, bookmarks, saved sessions |
| `~/.bash_history`, `~/.zsh_history`, `.zcompdump`, `.viminfo` | Shell/editor history |
| `.netrc`, `.env`, SSH/GPG keys, git credentials | Not present in the audit, but always excluded |
| `~/Pictures/Screenshots`, personal Documents/Downloads | Personal media/data |
| Backup directories listed in section 4 | Copies of personal configs |

No SSH or GPG key directories were found. The audit made no attempt to read
credential contents beyond identifying the files; the one opencode service
file was detected by filename and structure, not copied.

Personal identifiers also appear in configuration values: a city name in
Noctalia settings, a specific monitor output name, the wallpaper path, and a
home path inside the generated keybind JSON. These will be replaced by
defaults or runtime values.

## 8. Licensing summary

See `THIRD_PARTY.md` for the table. The release blockers are:

1. The active SDDM astronaut theme includes wallpapers and fonts whose
   upstream README says the original creators are unknown. It is **not
   redistributable as-is** without owner confirmation or replacement.
2. The wallpaper's license is unknown.
3. The Noctalia SDDM theme is GPLv3 and has a bundled wallpaper; provenance is
   clearer but should still be confirmed by the owner.
4. `1_shell` is MIT and matches upstream exactly; no blocker.
5. Noctalia, Quickshell, niri, kitty and the font/icon/GTK packages are under
   known free licenses.

## 9. Proposed include/exclude gate

### Include after sanitization

| Area | Files / packages | Sanitization |
|---|---|---|
| niri | `config.kdl`, `keybinds.kdl`, `noctalia.kdl`, `kitty-appearance.kdl` | XKB layout as template; no personal output names; keep generic output rules |
| Noctalia | `noctalia-integration.toml` plus a minimal default settings profile | Remove city, monitor keys, absolute wallpaper path; pin wallpaper via `/usr/share/backgrounds/astraos/` |
| kitty | `kitty.conf`, `themes/noctalia.conf`, `posh-font.conf` | Regenerate theme via Noctalia; no shader files exist |
| zsh | `.zshrc`, `1_shell.omp.json` | Use `$HOME`; vendor plugin packages; disable Oh My Posh notices/update checks |
| Neovim | `init.lua`, `lua/`, `lazy-lock.json`, `stylua.toml`, `README.md` | Set update checker off; pre-bake plugins/parsers/Mason; no user data |
| Keybind overlay | `gen-keybinds.py`, `shell.qml`, `keybinds-toggle` | Generate JSON at build/login; no absolute home path |
| GTK/dconf | theme/icon/font/cursor values, Nautilus list view, file-roller prefs | Exclude nm-applet connection UUID and any per-device state |
| opencode | `opencode.json`, `cli.json`, `tui.json`, `themes/matugen.json`, `commands/` | Remove `service.json`, DB/logs, skills; remove/replace `npx ...@latest` MCP |
| Fonts/themes | `noto-fonts`, `noto-fonts-emoji`, `noto-fonts-cjk`, `ttf-liberation`, `ttf-jetbrains-mono-nerd`, `adw-gtk-theme`, `papirus-icon-theme` | Install from pinned repositories |
| ISO-only tools | `arch-install-scripts`, `gum`, `parted`, `gptfdisk`, `jq`, `pciutils`, `usbutils`, `nano` | Live environment only; not part of the target by default |
| Wallpaper | one image, if rights confirmed | Install to `/usr/share/backgrounds/astraos/` |
| SDDM | chosen theme only, if rights confirmed | New `/etc/sddm.conf.d/astra.conf`; default session niri |

### Exclude

| Area | Why |
|---|---|
| `service.json`, auth files, keyrings, tokens, browser profiles, histories, clipboard | Secrets/personal data |
| `~/.config/mozilla`, `~/Pictures/Screenshots`, Documents, Downloads, personal media | Personal data |
| Noctalia community palettes/templates caches, state `settings.toml` raw | Personal/device state and downloaded assets |
| Backup directories (`~/backup`, `*backup*`, `desktop-backup-*`) | Stale copies, personal paths |
| `cloudflare-warp-bin`, `warp-svc` | Personal VPN service; not part of AstraOS |
| `yay-bin`, `yay-bin-debug` | Replaced by paru; build artifacts |
| `archinstall`, `archiso` | Build/maintenance tools, not target apps |
| `fuzzel`, `mako`, `waybar`, `swaybg`, `swayidle`, `swaylock`, `network-manager-applet`, `nwg-look`, `seatd` | Not referenced by the live desktop; likely leftovers (pending owner confirmation) |
| `tor-browser-launcher`, `htop`, `nano`, `vim` | Optional/personal; pending owner confirmation |
| Astronaut SDDM theme | Asset licensing unclear; do not ship unless owner confirms |
| Personal location, monitor name, home path, username, hostname | Privacy; scrub gate |

### Needs owner decision

1. Approval of the include/exclude list above.
2. Steam: add or omit?
3. Cloudflare WARP and Tor Browser: keep as personal apps or exclude?
4. `1_shell`: confirmed as the Oh My Posh theme; any further changes?
5. SDDM theme: astronaut (active, licensing unclear) or Noctalia theme
   (GPLv3, matches desktop), or a new Astra theme?
6. Wallpaper rights.
7. Stable channel hosting: Arch Archive + GitHub `stable.json` (default) or
   self-hosted snapshot mirror?
8. Fallback `linux-lts` kernel: ship or not?
9. Image viewer/editor: loupe + GIMP, or the owner's alternatives?
10. Logo direction.

## 10. Verification summary

| Claim | Verified? | Evidence |
|---|---|---|
| Host is AMD-only, no NVIDIA | Yes | `lspci -nnk` |
| Manifest package names resolve | Yes | 158 official via `pacman -Si`; 8 AUR via RPC; 0 unresolved |
| niri config is valid | Yes | `niri validate` |
| Noctalia is official 5.3.0 | Yes | `pacman -Qi`, `noctalia --version` |
| `1_shell` is an Oh My Posh theme | Yes | SHA-256 equals upstream |
| SDDM active theme is astronaut | Yes | `/etc/sddm.conf`, theme dir, running service |
| Astronaut assets are not clearly licensed | Yes | upstream README says creators unknown |
| Wallpaper license is unknown | Yes | filename/metadata only; no license found |
| `sudo` is non-interactive | No | password required |
| QEMU/OVMF/GRUB/snapper/gum/shellcheck usable | No | absent |
| NVIDIA paths work | No | no NVIDIA hardware; will be fixture-tested |
| Intel path works | Not on this host | Intel packages present, hardware absent |
| Offline install works | No | not built yet |

## 11. Next

Approve or amend the include/exclude list. After approval, Phase 1 records the
owner decisions and Phase 2 starts the package/build scaffolding. No personal
file will be copied before that approval.
