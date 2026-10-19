# iso

The archiso profile, based on `releng`, will live here.

Planned profile settings:

- `iso_name=astraos`, label `ASTRAOS`, zstd squashfs.
- Packages from `manifests/`.
- Boot menu entries: default, basic graphics, copy-to-RAM.
- One pinned Arch Linux Archive date for all official packages.
- Live user `liveuser` with passwordless sudo, autologin on tty1, and a
  welcome prompt that leads either to the desktop or to `astra-install`.

No ISO is built until the owner explicitly says so (D-021).
