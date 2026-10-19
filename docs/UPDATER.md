# AstraUpdate

Status: **design; the Phase 0 gate approved two update tracks. The OS track is
defined; the app track needs one owner clarification (D-026). No updater code
has been written or run.**

## Two tracks

AstraUpdate separates OS updates from application updates so that a bad app
release does not force a new OS or drag in unplanned system libraries.

### OS track

- A signed `stable.json` is published on GitHub. Proposed shape:
  `{ "snapshot": "YYYY/MM/DD", "astra_repo": "...", "notes": "...",
  "requires_manual": [] }`.
- The signature key comes from `astra-keyring`.
- Clients pin Arch packages to
  `https://archive.archlinux.org/repos/YYYY/MM/DD/$repo/os/$arch` through
  `/etc/pacman.d/astra-stable.mirrorlist`, rewritten when the pointer moves.
- The `[astra]` repository is versioned in lockstep with the snapshot.
- Maintainers promote a snapshot with `scripts/promote-stable.sh` only after
  the QEMU suite passes.
- The mirror regions chosen at install time remain as an opt-in rolling
  channel, with a warning. The Arch Archive is not a mass-distribution CDN; the
  long-term path is an AstraOS-hosted snapshot mirror.

### App track

The owner wants app updates to follow actual upstream stable releases and stay
independent of OS releases. The recommended mechanism is a second signed file,
`apps.json`, and an `[astra-apps]` repository built from pinned upstream stable
tags. The updater:

- refreshes app metadata without changing the OS snapshot;
- refuses an app update whose package metadata requires a newer OS snapshot,
  and offers the OS update first;
- never enables a rolling repository just to satisfy an app;
- keeps app packages signed and available offline in the ISO's local repo until
  the first successful online update.

This is still a native Arch package layer. It isolates release cadence, not
libraries: an app and the OS can still share a library package. The updater's
compatibility gate is therefore mandatory. If the owner wants hard isolation,
Flatpak is the alternative: OS and core desktop stay native, optional apps run
in sandboxed Flatpak runtimes that update separately. Directly installing
Debian, Fedora or other distributions' binary packages on the Arch base is not
proposed because of glibc/ABI mismatch and package-manager conflicts.

**Open question for the owner:** does "actual stable release" mean (a) upstream
stable versions built by AstraOS for the installed OS (recommended), or
(b) another distribution's binary packages? Option (b) needs a container or
Flatpak layer and a different support model.

## Update flow

Fetch and verify the relevant metadata, never move backward except rollback,
preview the package diff and Arch news, take a snapper snapshot, download
everything with `-Sw` before applying, always do a full upgrade, list
`.pacnew` files without auto-merging, notify about reboot when
kernel/NVIDIA/Mesa/systemd changed, and support `astra-update --rollback` plus
GRUB snapshots.

## Safety checks

Battery at least 30% or on AC, no pacman lock, at least 5 GiB free, skip
silently when offline, defer while a game is running (Steam). When both tracks
have updates, apply the OS track first, reboot if required, then the app track.

## Interfaces

- CLI: `astra-update --check --apply --rollback --status --json`, with
  `--os` and `--apps` selectors.
- GUI: GTK4 + libadwaita (Python/PyGObject), never root; privileged work goes
  through a polkit helper or a small system service.
- Notifications through `notify-send`; optional Noctalia bar indicator if the
  shell supports it.
- Desktop entry and icon. Log to `/var/log/astra-update.log`.
- Modes: Automatic (daily timer, installs when idle), Notify only, Manual.

## Verification required before release

- The signed metadata rejects tampering and rollback.
- A pinned OS snapshot installs and upgrades in QEMU with no network.
- An app update that requires a newer OS is held with a clear message.
- A bad app package can be rolled back without touching the OS snapshot.
- The updater never runs the GUI as root.
