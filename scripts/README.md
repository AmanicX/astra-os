# scripts

| Script | Status | Purpose |
|---|---|---|
| `scrub-check.sh` | Implemented | Scan the repo and Astra-owned ISO paths for secrets and personal identifiers |
| `build-repo.sh` | Planned | Compute the closure, fetch one Arch Archive snapshot, build AUR packages, sign and publish `astra-local` |
| `build-iso.sh` | Planned | Build the archiso image, run scrub checks, emit the ISO and SHA-256 |
| `promote-stable.sh` | Planned | Sign and publish a new `stable.json` after the QEMU suite passes |
| `vm-test.sh` | Planned | Boot the ISO in QEMU/OVMF and run the end-to-end checks |

Rules: `set -Eeuo pipefail`, shellcheck-clean, `shfmt`-formatted, no
`curl | sh`, deterministic inputs.
