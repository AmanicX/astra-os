# Building AstraOS

Status: **planned; no ISO may be built until the owner explicitly says so
(D-021).**

## Host requirements

- Arch Linux x86_64 build host with `base-devel`, `archiso`, `devtools`,
  `qemu-system-x86`, OVMF, `shellcheck`, `shfmt`, `gum`, `parted`, `sgdisk`,
  `btrfs-progs`, `libisoburn`.
- A working `sudo` path. The current audit host requires a password and cannot
  run privileged phases yet (D-012).
- Free disk: budget ~60 GiB for repository payload, chroots, work directory and
  VM images. The audit host has 128 GiB free; confirm before the heavy build.

## One command per artifact

```sh
./scripts/build-repo.sh   # astra-local repository + AUR packages
./scripts/build-iso.sh    # astraos-YYYY.MM.DD-x86_64.iso + SHA-256
```

Both scripts are not implemented yet.

## Determinism

- All official packages come from one Arch Linux Archive date.
- AUR packages are built from pinned commit hashes in a clean chroot.
- `SOURCE_DATE_EPOCH` is set for `repo-add` and `mkarchiso`.
- The generated source lock and package versions are committed with the build.

## Release checks

1. `scripts/scrub-check.sh` passes on the repository.
2. `scripts/scrub-check.sh --iso <iso-root>` passes on the extracted ISO tree.
3. `namcap` passes on every PKGBUILD.
4. `shellcheck` and `shfmt -d` pass on every script.
5. The checksum file matches the produced ISO.
6. `THIRD_PARTY.md` has no unresolved release blockers.
