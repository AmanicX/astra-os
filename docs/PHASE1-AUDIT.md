# AstraOS Phase 1 audit — naming and boot branding

Date: 2026-10-22
Scope: read-only inspection first, followed by the Phase 1 source changes.
No disk, partition table or host bootloader was touched.

## Repository state

- Git repository: `D:\backup-linux\astraos`, branch `main`, remote
  `git@github.com:AmanicX/astra-os.git`.
- The working tree already contained uncommitted installer, build and test
  work. Those changes were preserved.
- WSL build environment: Arch Linux WSL2 distro `AstraOS`, build tree
  `/root/astraos-build`, source checkout `/mnt/d/backup-linux/astraos`.
- The checked-in `iso/` directory contains documentation only. The real
  archiso profile is assembled at build time from
  `/usr/share/archiso/configs/releng` by `scripts/build-iso.sh`.

## What the generated ISO actually contained

The last generated profile was inspected at
`/root/astraos-build/build/iso/profile`. Its user-visible boot strings were:

| Location | Old text |
|---|---|
| systemd-boot `01-archiso-linux.conf` | `Arch Linux install medium (%ARCH%, UEFI)` |
| systemd-boot `02-archiso-speech-linux.conf` | `Arch Linux install medium (%ARCH%, UEFI) with speech` |
| systemd-boot `03-archiso-memtest86+x64.conf` | `Memtest86+` |
| GRUB `grub.cfg` | `Arch Linux install medium (...)` and `... with speakup screen reader` |
| GRUB `loopback.cfg` | same two entries, plus `Run Memtest86+` and `UEFI Shell` |
| syslinux | `MENU TITLE Arch Linux`, `Arch Linux install medium`, `install Arch Linux` |
| `profiledef.sh` | `iso_name=astraos`, label `ASTRA_YYYYMM`, publisher and application already AstraOS |

Functional archiso tokens were present and must remain:
`archisobasedir=`, `archisosearchuuid=`, `%INSTALL_DIR%`, `%ARCH%`,
`%ARCHISO_UUID%`, `default 01-archiso-linux.conf`, and the entry filenames.

## Branding assets

- `astraos-wordmark.svg` used `ASTRA` (bold) + `OS` (light cyan). This was the
  main all-caps violation.
- `astraos-lockup.svg` used the same all-caps wordmark.
- `generate-assets.py` wrote `ASTRAOS` on the default wallpaper, and the
  checked-in `astraos-default.png` carried that text.
- The star mark itself was already correct and is unchanged.
- The live installer header said `UEFI • Arch Linux • <version>`, which is a
  user-visible Arch Linux label. The niri config comment also said
  `Arch Linux`, although it is not user-visible.

## Other findings recorded for later phases

- `docs/PROGRESS.md` and `README.md` describe the old live-user/SDDM flow,
  the old Astronaut SDDM theme and offline-only assumptions. They are stale
  relative to the current master prompt and the owner's updates.
- The build currently bundles `repo/x86_64` into the live image. The owner has
  removed the offline requirement, so this can be dropped in a later phase
  when the installer no longer needs the bundled repository.
- The default wallpaper is an original generated asset and is being replaced
  in Phase 3 with a small original set plus licensed imports.
- The installed-system SDDM theme is being replaced by SilentSDDM with a
  theme-switching script and a different wallpaper per theme.
- The installer is still the Bash/gum script. The Rust/Tauri installer is a
  later phase.

## Phase 1 changes made

1. Added `config/brand.toml` as the single identity source and
   `scripts/lib/brand.sh` to read it.
2. Added `scripts/rebrand-archiso.sh`, called by `scripts/build-iso.sh` after
   the releng profile is copied. It rebrands systemd-boot, GRUB/loopback and
   syslinux menu text while preserving functional tokens.
3. Added `tests/branding-test.sh` and wired it into `tests/run-all.sh`.
4. Changed the wordmark and lockup to mixed-case `Astra` + `OS`.
5. Changed the wallpaper caption and regenerated the 3840×2160 PNG.
6. Changed the installer header to `UEFI • AstraOS • <version>` and the niri
   comment to AstraOS.
7. Updated the storage floor to 35 GiB total / 34 GiB root and adjusted the
   loopback tests and static guard.
8. Recorded the owner's new decisions in `docs/DECISIONS.md`.

## Verification status

Verified statically in WSL:

- `bash -n` on the modified scripts.
- `tests/branding-test.sh` passes against the installed archiso releng profile:
  no Arch Linux boot titles, branded systemd-boot/GRUB/syslinux entries,
  preserved archiso search tokens, mixed-case wordmark/lockup/wallpaper.
- The regenerated wallpaper is a 3840×2160 PNG.

Not yet verified:

- The actual rebuilt ISO boot menu and QEMU/OVMF boot. This needs an approved
  privileged ISO build.
