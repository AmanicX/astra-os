#!/usr/bin/env python3
"""Create the AstraOS SilentSDDM presets from the upstream default config."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent
BASE = ROOT / "presets/base.conf"

PRESETS = {
    "astra-orbital": ("astraos-default.png", 0.0),
    "astra-aurora": ("astraos-aurora.png", 0.0),
    "astra-ember": ("astraos-ember.png", 0.0),
    "astra-lunar": ("astraos-lunar.png", 0.0),
    "astra-earthrise": ("astraos-earthrise.jpg", -0.30),
    "astra-carina": ("astraos-carina.png", -0.10),
    "astra-deepfield": ("astraos-deepfield.jpg", -0.15),
}


def main() -> None:
    base = BASE.read_text(encoding="utf-8")
    base = base.replace('font-family = "RedHatDisplay"', 'font-family = "Adwaita Sans"')
    for name, (wallpaper, brightness) in PRESETS.items():
        text = base.replace('background = "smoky.jpg"', f'background = "{wallpaper}"')
        text = text.replace("brightness = 0.0", f"brightness = {brightness:.2f}")
        out = ROOT / "presets" / f"{name}.conf"
        out.write_text(text, encoding="utf-8")
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
