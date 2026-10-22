# AstraOS Branding

## Product name

The product name is **AstraOS**, always mixed case. Never write `ASTRAOS` or
`ASTRA OS` in a user-visible place. `Astra Linux` is acceptable as a long form
in prose. The only uppercase exception is a technical identifier that cannot
carry mixed case, such as the ISO9660 volume label `ASTRA_YYYYMM`; that value
must stay consistent with `archisolabel=`.

The identity is defined once in `config/brand.toml`. Build scripts read it
through `scripts/lib/brand.sh`; do not hardcode a different name in boot
entries, artwork or installer screens.

## Design philosophy: Astral Meridian

Astral Meridian treats the interface as a quiet instrument for navigation.
The visual language comes from celestial charts and precision optics: thin
meridians, measured rings, and a single star that acts as a fixed point. The
work should feel observed rather than decorated, as if every line was placed
after long study of how the eye moves across a dark field.

Space is the primary material. Large negative areas let windows, icons and
text breathe; the mark occupies one deliberate zone and never competes with
content. Form is geometric but not mechanical: a four-point star with softly
curved inner transitions, enclosed by an incomplete ring and a few calibrated
ticks. The silhouette must remain legible at 16 pixels and at wall size.

Color is restrained. Void navy and deep indigo establish depth; starlight
white carries the mark; a single cyan accent suggests an instrument glow; a
muted gold is reserved for the smallest celestial details. No rainbow
gradients, no glossy effects, no ornamental noise. Every value is chosen to
survive both a dark desktop and a dimmed lock screen.

Scale and rhythm come from repetition: concentric rings, radial ticks, and a
sparse field of stars. The pattern is systematic enough to read as a chart,
but its spacing is hand-tuned so the composition never feels generated. The
final asset should look meticulously crafted, the product of painstaking
alignment and many refinements by someone at the top of the field.

Typography is sparse and architectural. The wordmark uses Adwaita Sans with
moderate tracking and is set as **Astra** in bold off-white followed by **OS**
in the lighter cyan accent, with a single thin teal underline. Set it as a
quiet caption rather than a slogan. Text appears only where it anchors the
mark; the image does the work. The result should feel like an artifact from an
imaginary observatory: precise, calm, and quietly confident.

## Palette

| Token | Value | Use |
|---|---|---|
| Void | `#05070D` | Wallpaper base |
| Indigo | `#0B1220` | Wallpaper depth |
| Meridian | `#1E3A5F` | Chart lines |
| Starlight | `#E8EEF7` | Mark, wordmark |
| Cyan | `#67E8F9` | Instrument accent |
| Gold | `#D6B36A` | Sparse celestial detail |

## Assets

| Asset | Path | Notes |
|---|---|---|
| Mark | `packages/astra-branding/files/usr/share/astra/branding/astraos-mark.svg` | Four-point star + ring, transparent |
| Wordmark | `packages/astra-branding/files/usr/share/astra/branding/astraos-wordmark.svg` | Adwaita Sans, mixed-case `Astra` + `OS` |
| Lockup | `packages/astra-branding/files/usr/share/astra/branding/astraos-lockup.svg` | Mark + mixed-case wordmark |
| Wallpaper source | `packages/astra-branding/files/usr/share/astra/branding/astraos-wallpaper.svg` | 3840x2160 source |
| Wallpaper | `packages/astra-branding/files/usr/share/backgrounds/astraos/astraos-default.png` | Generated with `rsvg-convert` |
| Logo PNG | `packages/astra-branding/files/usr/share/icons/hicolor/512x512/apps/astraos-logo.png` | Generated from mark |

The wordmark uses Adwaita Sans (OFL-1.1, package `adwaita-fonts`), which is
already part of the desktop font set.

The current wallpaper is original generated work. Phase 3 replaces the single
default with a small original set plus curated, permissively licensed imports
(NASA/ESA/Webb public-domain or CC0/CC-BY sources). Every imported file must
have its license and credit recorded in `THIRD_PARTY.md` before it ships.

## Boot menus

`scripts/rebrand-archiso.sh` is the only place that changes the assembled
archiso menu text. It is called by `scripts/build-iso.sh` after the releng
profile is copied. It must not rename `archisobasedir=` or
`archisosearchuuid=`, and the archiso entry filenames stay functional. The
`tests/branding-test.sh` check fails if a visible Arch Linux install-medium
title survives.
