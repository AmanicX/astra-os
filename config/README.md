# Configuration

| File | Purpose |
|---|---|
| `brand.toml` | Single source for the AstraOS name, id, ISO label prefix and tagline |
| `snapshot` | Pinned Arch Linux Archive date used for official packages |
| `pacman.conf.in` | Pacman configuration template for build chroots and downloads |
| `live/airootfs` | Live-session files overlaid into the archiso profile |

The snapshot is deliberately pinned for reproducible builds. Network access is
allowed; the offline-only requirement was removed on 2026-10-22. Bump the
snapshot only as a release action.
