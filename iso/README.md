# iso

The archiso profile is assembled from `/usr/share/archiso/configs/releng` by
`scripts/build-iso.sh`; it is not checked in here.

Build settings:

- `iso_name=astraos` and a technical `ASTRA_YYYYMM` label, zstd squashfs.
- Packages from `manifests/`.
- The boot menus are rebranded by `scripts/rebrand-archiso.sh`, which keeps
  `archisobasedir=` and `archisosearchuuid=` functional.
- The current build mode is UEFI systemd-boot only.
- One pinned Arch Linux Archive date is used for official packages; network
  access is allowed and the old offline-only rule is removed (D-033).

ISO builds require explicit owner approval. The build command is in
`docs/BUILD.md`.
