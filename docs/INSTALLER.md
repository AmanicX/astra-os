# astra-install

Status: **skeleton planned; implementation starts after the Phase 0 gate.**

## Shape

- Bash + `gum`, runnable on a bare TTY and inside kitty.
- One function per step in `installer/lib/*.sh`.
- State in an associative array, dumped to `/run/astra-install/answers.json`
  without passwords. Passwords move only through pipes to `chpasswd`.
- `--answers file.json --yes` for unattended runs.
- Log to `/var/log/astra-install.log`; never log secrets; copy the log to the
  target at the end. An ERR trap unmounts cleanly and prints the log path.
- Branded header on every screen, back navigation, Ctrl-C confirmation.

## Prompt order (fixed)

1. Keyboard layout
2. Mirror regions
3. Storage (whole disk / dual-boot free space)
4. Hostname
5. Root password
6. User account and sudo
7. Additional packages
8. Timezone
9. Summary and final confirmation
10. Install with progress UI

No disk write happens before the final confirmation.

## Storage rules

- GPT only. Whole-disk mode uses 1 GiB FAT32 ESP plus Btrfs root.
- Dual-boot mode creates partitions only inside the selected free region,
  requires at least 25 GiB, and proves existing partitions were not written to
  by comparing every original GPT entry (start, end, type GUID, unique GUID,
  name) and filesystem UUID before and after. It also backs up the GPT table
  and never issues a write to an existing partition. A whole-table checksum is
  not compared, because adding a partition legitimately changes the table.
  QEMU tests also verify a known data pattern inside a dummy existing
  partition (D-024).
- Btrfs subvolumes: `@ @home @log @pkg @snapshots`, mounted with
  `noatime,compress=zstd:1,space_cache=v2,discard=async`.
- ESP at `/boot/efi`; kernels live in Btrfs `/boot` (D-003).
- zram swap via `zram-generator`; no swap partition.
- No LUKS in v1; the storage layer keeps a seam for it.

## Offline install

`pacstrap -K -C /etc/astra/pacman-offline.conf` uses only the local
`astra-local` repository. The target receives the real `pacman.conf` with
`[multilib]` enabled (Steam requires it) and the mirrorlist chosen in step 2.
Packages unavailable offline are queued for the first online boot through
`astra-pending-packages.service`.

The installer selects packages from the manifests rather than installing
every line: base + desktop + the detected driver set + approved apps + fonts +
`astra-*`. Steam is installed on the target but is not part of the live ISO
(D-030).

## Hardware detection

`installer/lib/hw.sh` is data-driven and unit-tested against `lspci -nnk`
fixtures: AMD, Intel, NVIDIA current (Turing and newer, including GTX 16xx),
NVIDIA 580xx (Maxwell/Pascal/Volta), hybrid Intel+NVIDIA, hybrid AMD+NVIDIA,
pre-Maxwell, and virtio. See `manifests/drivers-*.txt`.

## Tests

Installer end-to-end runs in QEMU/OVMF with `-nic none` and `--answers`:
whole-disk, dual-boot preservation, offline package queue, installed-system
boot. Details in `docs/BUILD.md` and the future `installer/tests/`.
