# astra-install — Modern Terminal Installer for AstraOS

Status: **Archinstall-based Textual TUI (v2.0)**  
License: **GPL-3.0** (derived from and integrating upstream `archinstall` 4.5-1)

## Architecture

- **Engine**: Upstream `archinstall` 4.5-1 library (`archinstall.lib.installer.Installer`, `DiskLayoutConfiguration`, `DeviceModification`, `PartitionModification`, `btrfs_options`, `genfstab`, `add_bootloader`, and user management).
- **Presentation**: `python-textual` (v8.2.8) true-color TUI wizard featuring a sequential 17-screen workflow with a strict Back/Next stack.
- **Brand Palette**:
  - Deep Navy background (`#0c1017`)
  - Off-white text (`#e8edf7`)
  - Cyan accent (`#5ee6f2` - selection, progress, active items)
  - Amber highlight (`#e6a45a` - warnings, attention)
  - Slate-teal hairlines (`#3b4c58` - borders, subtle text)
  - Red (`#f26b6b` - destructive actions)
  - Green (`#6be6a8` - preserved, untouched partitions)
- **Unattended Mode**: Full compatibility with `astra-install --config <file.json> --creds <creds.json> --silent`.
- **Fallback**: Graceful fallback to sequential text prompts if terminal capabilities or window dimensions prevent rich TUI initialization.

## The 17 Screens (Strict Sequential Order)

1. **Welcome**: Logo / ASCII star-mark, system health check (UEFI, internet, Secure Boot warning, RAM, usable disk). Next is blocked until network is active.
2. **Keyboard layout**: Searchable list with live testing field.
3. **Locale**: Searchable UTF-8 locale selection (default `en_US.UTF-8`).
4. **Timezone**: Searchable region/city list with NTP sync enabled.
5. **Repository region**: Mirror region selector with background speed ranking.
6. **multilib**: Informational screen noting multilib, parallel downloads, and color enabled automatically.
7. **Swap**: zram (recommended default), swap partition (custom size), or no swap.
8. **Hostname**: Default `astraos` or custom RFC 1123 validated name.
9. **Root password**: Masked input with verification and strength indicator.
10. **User account**: Username and password with verification.
11. **Sudo mode**: Standard account (no sudo) vs Administrator (`wheel` with user password). No `NOPASSWD`.
12. **Mounting / Partitioning**: Safe storage planner (Erase disk, Use free space, Manual / pre-mounted).
13. **Extra boot entries (os-prober)**: Automatic dual-boot OS detection via GRUB.
14. **Additional packages**: Curated base inventory display, search/validator, browser and AUR helper pickers.
15. **Summary**: Grouped review with jump-back edit actions, before/after disk layout bar, and typed confirmation.
16. **Installation**: Phase progress bar, package counter, live streaming log pane.
17. **Finished**: Completion summary with "Reboot now?" (Yes / No).


No disk write happens before the final **INSTALL** confirmation. The one
exception is `cfdisk`, which the user operates directly in free-space and
manual modes; the installer reads the resulting table.

## Storage rules

GPT only. The installer refuses to write to a disk that is not GPT (free-space
and manual modes) and refuses a mounted disk in free-space mode.

### Whole disk

- Deletes every partition on the selected disk; the UI requires an explicit
  confirmation plus typing `ERASE`.
- Rechecks the disk size **before** erasing: at least 35 GiB total capacity
  (normally a 1 GiB ESP plus a 34 GiB root), plus 2 MiB GPT/alignment overhead.
  A too-small disk is refused without changing the table.
- Creates a 1 GiB FAT32 ESP (`EF00`) and a Btrfs root (`8300`), formats both,
  and verifies the type and filesystem before proceeding.

### Free space

- Existing partitions are never formatted, mounted, unmounted, or written to.
- The installer records every original GPT entry before `cfdisk`: partition
  number, start, end, size, type GUID, type code, unique GUID, name, filesystem
  UUID and a SHA-256 hash of the partition's first MiB. It also writes a GPT
  backup file.
- After `cfdisk`, the user selects a contiguous free region and either an
  existing ESP or a new 1 GiB ESP. New partitions are created only inside the
  selected region.
- The new ESP and root are checked for location, type, size and filesystem.
  Every original GPT entry and its first-MiB hash is then compared with the
  pre-`cfdisk` snapshot. A whole-table checksum is not compared because adding
  a partition legitimately changes the table.
- Root minimum is 34 GiB; 40 GiB or more is recommended. A new ESP adds 1 GiB
  plus 2 MiB of GPT/alignment overhead, so the minimum free region is 35 GiB.
  The installer rejects a root smaller than 34 GiB or a new-ESP region smaller
  than 35 GiB before creating anything.
- The storage summary states exactly what is kept, created, and erased.

### Manual partitioning

- The user creates the table in `cfdisk`, then selects an existing root and
  ESP. The root must be at least 34 GiB and must not be mounted.
- The root is reformatted as Btrfs; the existing ESP is only checked for a
  vfat filesystem and is never formatted.
- The selected entries are recorded and shown in the summary before the final
  confirmation.

### Pre-mounted

- The user mounts root and ESP themselves, then enters the root mountpoint
  (default `/mnt`).
- ESP detection is limited to the selected root: `<root>/boot/efi`,
  `<root>/boot` and `<root>/efi` (with the default `/mnt`, those are
  `/mnt/boot/efi`, `/mnt/boot` and `/mnt/efi`). Root and ESP must be on
  different devices.
- The installer never partitions, formats, mounts or unmounts anything in this
  mode. It leaves the mounts in place at the end.

### Filesystems and boot

- Btrfs subvolumes: `@ @home @log @pkg @snapshots`, mounted with
  `noatime,compress=zstd:1,space_cache=v2,discard=async`.
- ESP at `/boot/efi`; kernels live in Btrfs `/boot` (D-003).
- zram swap via `zram-generator`; no swap partition.
- GRUB is the target bootloader (D-022).
- No LUKS in v1; the storage layer keeps a seam for it.

## Installation

- `build_pkg_list` selects base + desktop + detected drivers + apps + fonts +
  `astra-*` from the manifests, plus CPU microcode. It honors
  `target-exclude.txt`, deduplicates, and resolves the NVIDIA conflict in
  favour of DKMS.
- `pacstrap -C <generated conf> -M` downloads official packages from the
  selected Arch Linux Archive snapshot or regional mirrors. It deliberately
  does **not** pass `-c`: the package cache must live on the target root
  (`/mnt/var/cache/pacman/pkg`), not on the live ISO's small overlay. This is
  what lets a large desktop transaction (~2 GiB download) succeed on a 35 GiB
  or larger disk. The bundled `astra-local` repository supplies Astra and
  approved AUR packages. The live ISO is not an offline-only installer.
- Before `pacstrap`, the installer verifies that `/mnt` is backed by the
  selected root device and has at least 10 GiB free. A mis-mounted or tiny
  target is refused before any package is written.
- Extra packages are installed inside `arch-chroot`; a failure asks whether to
  continue without them.
- `genfstab -U` captures the actual Btrfs subvolume and ESP layout.
- Target configuration runs in `arch-chroot`: timezone, locale, hostname,
  passwords, user and sudo, zram, services, LazyVim seed, initramfs, GRUB and
  `grub-mkconfig`. `os-prober` is enabled for dual-boot layouts when present.
- Mounts are cleaned up on failure. Pre-mounted installs are deliberately left
  mounted and the completion screen says so.

## Tests

Run the aggregate suite as root inside an Arch environment (WSL or the live
ISO):

```sh
ASTRA_TEST_LOG_DIR=/home/astra/astraos-tests bash tests/run-all.sh
```

| Test | What it proves |
|---|---|
| `tests/static-guards.sh` | Invariants: no `set -e`, approved ESP paths, safe defaults, no host-disk writes in tests. |
| `tests/wizard-dry-run.sh` | Deterministic full wizard, including all four storage modes and the final dry-run gate. |
| `tests/real-gum.sh` | Real `gum` 2.0.2: success path, Esc/back navigation, Ctrl-C back navigation, confirmed exit from the welcome screen, no silent exit. |
| `tests/storage-loop-test.sh` | Real destructive storage tests on sparse loopback images only: free space with a new ESP, free space with an existing ESP, manual root reformat, a too-small whole disk (refused without touching GPT), and a full whole-disk install. Existing data markers and first-MiB hashes survive. |
| `tests/run-all.sh` | Runs syntax checks, shellcheck, shfmt, static guards, dry run, real gum, and (when root) storage. |

The storage tests use `/dev/loop*` images under `/var/tmp`; they never open a
host disk. The exact commands, logs and outcomes are recorded in
`docs/PROGRESS.md`.

## Known limitations and next verification

- The built ISO still needs a QEMU/OVMF boot test and a real installed-system
  boot test. Those are separate from the WSL logic tests above.
- NVIDIA and Intel driver paths are fixture-tested; real hardware verification
  remains an owner task.
- No LUKS, no BIOS/legacy boot, and no unattended `--answers` mode in v1.
- The QEMU test must use a disk image, never a host block device.
