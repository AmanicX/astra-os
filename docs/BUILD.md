# Building AstraOS

Status: **owner-approved build in progress on 2026-10-21.** Earlier builds were
paused by D-021; the addendum in `docs/DECISIONS.md` records the approval.

## Host requirements

- Arch Linux x86_64 build host (or WSL2 Arch) with `base-devel`, `archiso`,
  `git`, `squashfs-tools`, `libisoburn`, `mtools`, `erofs-utils`,
  `dosfstools`, `qemu-system-x86`, OVMF, `shellcheck`, `shfmt`, `gum`,
  `parted`, `sgdisk` and `btrfs-progs`.
- Root (or passwordless sudo) for `mkarchiso`.
- `python` (3.11+ for `tomllib`) and `rsvg-convert` only when regenerating
  branding assets with `scripts/render-branding.sh`.
- Free disk: budget ~15 GiB for the profile, chroot, work directory and ISO.
  The 2026-10-21 build used a 955 GiB ext4 WSL volume and a 546 MiB working
  copy.
- Network access to the date-pinned Arch Linux Archive and to the pinned
  LazyVim plugin repositories.

## Build commands

```sh
ASTRA_ISO_APPROVED=1 ./scripts/build-iso.sh --build
```

`--plan` prints the live package set and checks the local repository without
building. The build refuses to run unless `ASTRA_ISO_APPROVED=1` is set.

The script:

1. Creates `build/iso/live-packages.txt` from the manifests.
2. Pre-bakes the pinned LazyVim tree into `build/iso/nvim-lazy` (cached between
   runs).
3. Builds an archiso profile from the releng profile and reads the identity
   from `config/brand.toml` through `scripts/lib/brand.sh`.
4. Rebrands the systemd-boot, GRUB and syslinux menu text with
   `scripts/rebrand-archiso.sh`; functional `archisobasedir=` and
   `archisosearchuuid=` tokens are preserved.
5. Replaces the live package list and pacman configuration with the AstraOS
   versions pinned to `config/snapshot`.
6. Stages the **current** installer sources from `packages/astra-installer/`
   under `/root/astra-installer-overlay`; `customize_airootfs.sh` copies them
   into place after `pacstrap`, so a stale package in `repo/x86_64` cannot ship
   an old installer and `mkarchiso` does not hit file conflicts.
7. Bundles `repo/x86_64` as `/usr/share/astra/repo`. This is a transition
   artifact: the owner removed the offline requirement, and this copy will be
   dropped when the installer no longer needs it.
8. Runs `mkarchiso` and writes the ISO to `out/`.

Re-running `--build` removes the previous `build/iso/profile` and `work` trees
first, so an interrupted build can be retried without file-conflict errors.

### WSL2 note

`mkarchiso` needs a normal Linux filesystem. Building directly on `/mnt/d`
(drvfs) is slow and can break permissions. Copy the checkout to ext4 first:

```sh
rm -rf /root/astraos-build
mkdir -p /root/astraos-build
tar -C /mnt/d/backup-linux/astraos \
  --exclude=.git --exclude=work --exclude=out --exclude=build \
  --exclude=iso --exclude=release -cf - . |
  tar -C /root/astraos-build -xf -
cd /root/astraos-build
ASTRA_ISO_APPROVED=1 scripts/build-iso.sh --build
```

The script derives `REPO_ROOT` from its own location, so the local repository
and all generated files stay inside the ext4 copy. Copy the finished ISO back
to the Windows release directory afterwards.

## Determinism

- All official packages come from one Arch Linux Archive date.
- AUR packages are built from pinned commit hashes in a clean chroot.
- `SOURCE_DATE_EPOCH` is set for `repo-add` and `mkarchiso`.
- The generated source lock and package versions are committed with the build.
- The repository closure includes `multilib` because Steam is approved
  (D-031). The build fails if the closure is incomplete.

## Manifest roles

The manifest files are repository payload lists, not one install list
(D-030):

- **Target install**: base + desktop + detected driver set + apps + fonts +
  `astra-*`.
- **Live ISO**: base + desktop + curated apps + ISO-only tools.
- **Repository payload**: all driver branches, guest tools and conditional
  packages needed for installations on other hardware. The payload is no
  longer required as an offline guarantee (D-033).

Steam is target-only. The NVIDIA proprietary stack is target-only; the live
ISO uses the open kernel drivers.

## QEMU verification

The installer logic tests run in WSL. The built ISO needs a separate boot test
in QEMU/OVMF, using image files only:

- boot the ISO in UEFI mode (OVMF), with no host block device;
- confirm systemd-boot reaches the live environment;
- use `console=ttyS0,115200` (set by the build) and the enabled
  `serial-getty@ttyS0` for a headless login when a graphical console is not
  available;
- confirm `astra-install` starts with real `gum` and that its screens render;
- confirm `Esc`/`Ctrl-C` returns to the previous step and the welcome-screen
  exit still needs confirmation;
- run the storage screens against an empty qcow2 disk, never a host disk;
- capture logs and screenshots as evidence.

A full install (pacstrap + GRUB + first boot) is a second test and must use a
throwaway qcow2 image. It requires network access for the package download.

## Release checks

1. `scripts/scrub-check.sh` passes on the repository.
2. `scripts/scrub-check.sh --iso <iso-root>` passes on the extracted ISO tree.
3. `namcap` passes on every PKGBUILD.
4. `shellcheck` and `shfmt -d` pass on every script.
5. The checksum file matches the produced ISO.
6. `THIRD_PARTY.md` has no unresolved release blockers.
7. Installer suite (`tests/run-all.sh`) passes.
8. QEMU UEFI boot and storage dry-run pass.
