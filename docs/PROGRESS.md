# AstraOS Progress

Updated: 2026-10-19

## Phase status

| Phase | Scope | Status |
|---|---|---|
| 0 | Read-only audit of the host; manifests; gate | **Audit complete; gate awaiting approval** |
| 1 | Decisions, include/exclude approval, repo skeleton | In progress |
| 2 | Package scaffolding and build tooling | Not started |
| 3 | Installer core and offline pacstrap path | Not started |
| 4 | Hardware detection and driver selection | Not started |
| 5 | Branding (logo, identity, fastfetch) | Not started |
| 6 | Offline repository and AUR build pipeline | Not started |
| 7 | ISO build | Not started |
| 8 | Live session | Not started |
| 9 | Installed desktop, offline pre-bake, SDDM | Not started |
| 10 | AstraUpdate CLI, GUI, polkit, stable channel | Not started |
| 11 | Automated tests | Not started |
| 12 | Documentation, scrub, release checks | Not started |
| 13 | Final verified/unverified report | Not started |

## Phase 0 checklist

- [x] Read-only host inspection (no config or disk changes).
- [x] Package inventory: 96 explicit, 3 foreign, 744 installed total.
- [x] Config inventory: niri, Noctalia, kitty, zsh, Neovim/LazyVim, SDDM,
      keybind overlay, Nautilus/dconf, mpv, btop, fastfetch, opencode, XDG.
- [x] `1_shell` identified with confidence as the upstream Oh My Posh theme
      `1_shell.omp.json` (SHA-256 matches upstream; MIT).
- [x] Service inventory (system and user).
- [x] Hardware inventory: HP ProBook 455R G6, AMD Ryzen 5 3500U, Radeon Vega,
      no NVIDIA GPU.
- [x] Wallpaper identified; license unresolved.
- [x] Secret scan of candidate configs. No credential copied.
- [x] `scripts/scrub-check.sh` initial implementation, shellcheck-clean,
      shfmt-clean, and passing on the repository.
- [x] Target and ISO manifests written; all 166 package names resolved
      (158 official, 8 AUR, 0 unresolved).
- [x] Proposed include/exclude list in `docs/AUDIT.md`.
- [ ] Owner approval of include/exclude list.
- [ ] Owner decisions from section 14 of the build brief.

## Blockers and constraints

1. **ISO builds are paused by the owner.** No ISO will be built until the owner
   explicitly says so. Repository/code work may continue; heavy downloads and
   builds are reported first.
2. `sudo` requires a password on the audit host. Package installation,
   loop-device setup, chroot builds and QEMU tests cannot start until the owner
   provides a non-interactive path (passwordless sudo for this workspace, or a
   prepared build environment). The agent must not ask for or store the
   password.
3. QEMU, OVMF, GRUB, snapper, gum and shellcheck are not installed. `/dev/kvm`
   exists.
4. The host has 128 GiB free. That is above the 60 GiB target but leaves
   limited headroom for an ISO, chroots, package cache and VM images. The owner
   must confirm before the heavy build starts.
5. Package manifests resolve cleanly on 2026-10-19 (158 official, 8 AUR, 0
   unresolved). Re-verify at build time because Arch is rolling.
6. No NVIDIA hardware is present. NVIDIA current and 580xx paths can only be
   fixture-tested here; real hardware must be verified by the owner.

## Verification log

| Item | How verified | Result |
|---|---|---|
| niri config syntax | `niri validate -c ~/.config/niri/config.kdl` | valid |
| Noctalia version | `pacman -Qi noctalia`, `noctalia --version` | 5.3.0-1, v5.3.0 |
| niri version | `pacman -Qi niri`, `niri --version` | 26.04-1, 26.04 |
| `1_shell` identity | SHA-256 comparison with upstream theme | exact match |
| SDDM active theme | `/etc/sddm.conf`, theme directory, running `sddm.service` | `sddm-astronaut-theme` active |
| GPU driver | `lspci -nnk`, `amdgpu` in use | AMD Vega only |
| Boot mode | `bootctl status` | UEFI, Secure Boot disabled |
| Wallpaper | `file`, `identify`, `sha256sum` | 7680x4320 JPEG; license unclear |
| Manifest names | `pacman -Si` + AUR RPC, 2026-10-19 | 158 official, 8 AUR, 0 unresolved |
| Repository scrub | `scripts/scrub-check.sh` | passes; no secret/personal identifiers |
| Script quality | `shellcheck`, `shfmt -d`, `bash -n` | clean |

## Next

After approval: Phase 1 decisions, then package scaffolding and the installer
core. No personal file will be copied before the gate is approved.
