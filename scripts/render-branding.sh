#!/usr/bin/env bash
# Regenerate the AstraOS wallpaper SVG and its PNG renders.
#
# Requires python3 (3.11+ for tomllib) and rsvg-convert. Run from anywhere in
# the checkout; the script resolves the repository root itself.
set -Eeuo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly root
# shellcheck source=scripts/lib/common.sh
source "${root}/scripts/lib/common.sh"

require_tools python3 rsvg-convert

python3 "${root}/packages/astra-branding/generate-assets.py"
rsvg-convert -w 3840 -h 2160 \
	-o "${root}/packages/astra-branding/files/usr/share/backgrounds/astraos/astraos-default.png" \
	"${root}/packages/astra-branding/files/usr/share/astra/branding/astraos-wallpaper.svg"
rsvg-convert -w 1920 -h 1080 \
	-o "${root}/docs/screens/branding/astraos-wallpaper-1920.png" \
	"${root}/packages/astra-branding/files/usr/share/astra/branding/astraos-wallpaper.svg"

chmod 0644 \
	"${root}/packages/astra-branding/files/usr/share/backgrounds/astraos/astraos-default.png" \
	"${root}/docs/screens/branding/astraos-wallpaper-1920.png"
log "regenerated wallpaper assets"
