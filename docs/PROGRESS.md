# AstraOS Progress

Updated: 2026-10-22

## Current status

Phase 1 (naming, boot-menu rebrand and mixed-case wordmark) is implemented and
statically tested. The actual rebuilt ISO and QEMU/OVMF boot verification are
pending an explicitly approved privileged build.

The owner has removed the offline requirement and replaced the earlier
Astronaut/Noctalia SDDM theme with SilentSDDM. The installer is still the
Bash/gum script; it will be replaced by the Rust/Tauri app in a later phase.
The source tree is ahead of the old README and installer docs.

## Master-prompt phases

| Phase | Scope | Status |
|---|---|---|
| 1 | Audit; brand identity source; boot menus; mixed-case wordmark | Source complete; static tests pass; ISO boot pending |
| 2 | Live session: no SDDM, root autologin, installer autostart | Pending |
| 3 | Wallpapers and shared design tokens; SilentSDDM switcher | Pending |
| 4 | Installer core and storage safety engine | Pending |
| 5 | Installer GUI pages 1–5 with Playwright loop | Pending |
| 6 | Storage pages and projected layouts | Pending |
| 7 | Bootloader pages and GRUB/Limine configs | Pending |
| 8 | Packages page and btop theme | Pending |
| 9 | Summary, progress, done and engine integration | Pending |
| 10 | Updater and release tooling | Pending |
| 11 | Full QEMU/OVMF matrix and ISO rebuild commands | Pending |

## Phase 1 record

- Audit: `docs/PHASE1-AUDIT.md`.
- Identity source: `config/brand.toml`, read by `scripts/lib/brand.sh`.
- Boot rebrand: `scripts/rebrand-archiso.sh`, called from
  `scripts/build-iso.sh` after the releng profile is copied.
- Wordmark/lockup changed to mixed-case `Astra` + `OS`.
- Wallpaper caption changed to `AstraOS`; 3840×2160 PNG regenerated.
- Installer header changed to `UEFI • AstraOS • <version>`.
- Static check: `tests/branding-test.sh` passes against the installed archiso
  releng profile; no Arch Linux boot titles remain and the archiso search
  tokens are preserved.

## Installer verification (2026-10-21; rerun 2026-10-22)

Environment: Arch Linux WSL2 (`AstraOS`), real `gum` 2.0.2, loopback images
under `/var/tmp` only. Host disks were never addressed by the tests. The
2026-10-22 rerun includes the 35 GiB storage floor and Phase 1 branding test.

| Test | Command | Result |
|---|---|---|
| Syntax | `bash -n` on all installer, build and test scripts | pass |
| Shell lint | `shellcheck -x -a` | clean |
| Formatting | `shfmt -d` | clean |
| Static invariants | `tests/static-guards.sh` | pass; 35 GiB floor enforced |
| Boot branding | `tests/branding-test.sh` | pass; no Arch Linux boot titles, archiso tokens kept |
| Deterministic wizard | `tests/wizard-dry-run.sh` | pass; all four storage modes |
| Real UI success path | `tests/real-gum.sh` | pass |
| Real UI back path | `tests/real-gum.sh` (Esc and Ctrl-C at hostname) | pass; returns to storage, then to welcome, confirmed exit |
| Free space, new ESP | `tests/storage-loop-test.sh` | pass; existing partition, marker and first-MiB hash kept; new ESP + root verified |
| Free space, existing ESP | `tests/storage-loop-test.sh` | pass; existing ESP and data kept; root created |
| Manual partitioning | `tests/storage-loop-test.sh` | pass; ESP untouched; root reformatted Btrfs |
| Too-small whole disk | `tests/storage-loop-test.sh` | pass; refused before any GPT write |
| Whole disk | `tests/storage-loop-test.sh` | pass; ESP + root created and verified |

The free-space tests snapshot every original GPT entry (number, start, end,
size, type GUID, type code, unique GUID, name, filesystem UUID, first-MiB
SHA-256). They also mount the preserved data partition and read a marker after
the installer has run.

## ISO build and QEMU verification

- Previous build: 2026-10-22, WSL2 Arch Linux, ext4 working copy at
  `/root/astraos-build`, snapshot `2026/10/18`. That ISO predates the Phase 1
  branding changes and the owner's later requirements.
- Phase 1 rebuild: pending explicit owner approval. The source changes are
  ready; `scripts/build-iso.sh --plan` passes and the boot-menu rebrand test
  passes against the installed releng profile.
- After approval: rebuild, boot in QEMU/OVMF, and verify every AstraOS-boot
  entry. This is the only remaining Phase 1 verification.

## Historical Phase 0 record

The original audit, package inventory and gate decisions are preserved in
`docs/AUDIT.md`, `docs/DECISIONS.md` and the repository history. Key facts:

- HP ProBook 455R G6, AMD Ryzen 5 3500U, Radeon Vega, no NVIDIA GPU.
- 96 explicit packages, 3 foreign, 744 installed at audit time.
- Target/ISO manifests resolved 158 official + 8 AUR packages, 0 unresolved on
  2026-10-19.
- Owner approved Steam (target-only), excluded GIMP, chose the Noctalia SDDM
  theme (later superseded by SilentSDDM, D-034), original branding, no LTS
  kernel, and passwordless sudo.
- ISO builds were paused by D-021 until the owner's explicit approval.

## Remaining work

1. Get approval, rebuild the ISO, and verify the AstraOS-boot entries in
   QEMU/OVMF.
2. Phase 2: remove SDDM from the live image, autologin root on tty1 into
   niri + Noctalia, and auto-open the installer.
3. Phase 3: replace the default wallpaper with the licensed set, add shared
   design tokens, and implement the SilentSDDM theme switcher.
4. Phase 4 onward: Rust/Tauri installer core and GUI, then updater and the full
   QEMU test matrix.
5. Real-hardware checks for NVIDIA/Intel paths and the audit laptop remain owner
   tasks.
