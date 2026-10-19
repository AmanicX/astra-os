# AstraOS

AstraOS is an Arch-based, UEFI-only Linux distribution built around a
niri + Noctalia Wayland desktop. It ships:

- an offline TUI installer (`astra-install`),
- a live ISO with the real desktop,
- an installed system with the owner's desktop configuration,
- `astra-update`, a stable-channel updater.

## Status

**Phase 0 audit complete; the include/exclude gate is awaiting owner approval.**
No personal configuration has been copied into this repository yet.

The audit is in [`docs/AUDIT.md`](docs/AUDIT.md). The phase checklist is in
[`docs/PROGRESS.md`](docs/PROGRESS.md). Non-obvious choices are recorded in
[`docs/DECISIONS.md`](docs/DECISIONS.md).

## Safety rules

- Phase 0 is read-only with respect to the host.
- Nothing is ever written to a real block device. Installer and upgrade tests
  use QEMU disk images.
- Credentials, browser profiles, keyrings, shell history, clipboard data and
  personal media are never copied into the repository or the ISO.
- `scripts/scrub-check.sh` scans the repository and the Astra-owned parts of an
  ISO tree. The build fails on a finding.
- The installer writes nothing until the final confirmation.

## Repository layout

```
docs/        PROGRESS, DECISIONS, AUDIT, BUILD, INSTALLER, UPDATER, HARDWARE-TEST
manifests/   base, desktop, apps, drivers, fonts, ISO-only, AUR and audit manifests
packages/    astra-* PKGBUILDs
installer/   astra-install plus installer/lib/*.sh and fixtures
updater/     astra-update CLI, GUI, polkit policy and systemd units
iso/         archiso profile based on releng
scripts/     build-repo, build-iso, scrub-check, promote-stable, vm-test
```

## Build

The build entry points are not implemented yet. They will be:

```sh
./scripts/build-repo.sh
./scripts/build-iso.sh
```

Both will be deterministic and will emit `astraos-YYYY.MM.DD-x86_64.iso`
plus a SHA-256 file.

## Licensing

Third-party components and assets are tracked in
[`THIRD_PARTY.md`](THIRD_PARTY.md). Unclear asset licenses block ISO release
until the owner resolves them.
