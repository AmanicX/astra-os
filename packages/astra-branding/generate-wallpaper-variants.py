#!/usr/bin/env python3
"""Generate colour variants of the original AstraOS wallpaper.

The base SVG is the orbital/cyan artwork. Variants only change the accent and
background hues, so the star field, charts, mark and typography stay exactly
the same. This keeps the set coherent and avoids shipping unrelated art.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent
BRANDING = ROOT / "files/usr/share/astra/branding"
BASE = BRANDING / "astraos-wallpaper.svg"

# accent (cyan), deep-blue line, gold detail
VARIANTS = {
    "aurora": ("#5EEAD4", "#123B3A", "#A7F3D0"),
    "ember": ("#FB923C", "#3B1D12", "#FDE68A"),
    "lunar": ("#C4B5FD", "#2A2140", "#E9D5FF"),
}


def main() -> None:
    base = BASE.read_text(encoding="utf-8")
    for name, (accent, deep, gold) in VARIANTS.items():
        svg = (
            base.replace("#67E8F9", accent)
            .replace("#1E3A5F", deep)
            .replace("#D6B36A", gold)
        )
        out = BRANDING / f"astraos-wallpaper-{name}.svg"
        out.write_text(svg, encoding="utf-8")
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
