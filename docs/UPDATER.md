# AstraUpdate

Status: **design only; implementation starts after the Phase 0 gate.**

## Stable channel

- A signed `stable.json` is published by the project. Proposed default:
  `{ "snapshot": "YYYY/MM/DD", "astra_repo": "...", "notes": "...",
  "requires_manual": [] }` hosted in a GitHub repository. The owner must
  confirm hosting (D-018).
- The signature key comes from `astra-keyring`.
- Clients pin Arch packages to
  `https://archive.archlinux.org/repos/YYYY/MM/DD/$repo/os/$arch` through
  `/etc/pacman.d/astra-stable.mirrorlist`, rewritten when the pointer moves.
- The `[astra]` repository is versioned in lockstep with the snapshot.
- Maintainers promote a snapshot with `scripts/promote-stable.sh` only after
  the QEMU suite passes.
- The mirror regions chosen at install time remain as an opt-in rolling
  channel, with a warning. The Arch Archive is not a mass-distribution CDN;
  `docs/UPDATER.md` will describe the migration path to an AstraOS-hosted
  snapshot mirror.

## Update flow

Fetch and verify stable.json, never move backward except rollback, preview the
package diff and Arch news, take a snapper snapshot, download everything with
`-Sw` before applying, always do a full upgrade, list `.pacnew` files without
auto-merging, notify about reboot when kernel/NVIDIA/Mesa/systemd changed, and
support `astra-update --rollback` plus GRUB snapshots.

## Safety checks

Battery at least 30% or on AC, no pacman lock, at least 5 GiB free, skip
silently when offline, defer while a game is running (gamemode/Steam).

## Interfaces

- CLI: `astra-update --check --apply --rollback --status --json`.
- GUI: GTK4 + libadwaita (Python/PyGObject), never root; privileged work goes
  through a polkit helper or a small system service.
- Notifications through `notify-send`; optional Noctalia bar indicator if the
  shell supports it.
- Desktop entry and icon. Log to `/var/log/astra-update.log`.
- Modes: Automatic (daily timer, installs when idle), Notify only, Manual.
- The updater updates through the `[astra]` repository.
