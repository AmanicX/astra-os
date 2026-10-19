# Configuration

| File | Purpose |
|---|---|
| `snapshot` | Pinned Arch Linux Archive date used for all official packages |
| `pacman.conf.in` | Pacman configuration template for build chroots and downloads |

The snapshot is deliberately pinned. Bump it only as a release action, not as
part of an ordinary build. A build must fail if the snapshot URL is missing or
if the package closure cannot be resolved from it.
