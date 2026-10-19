#!/usr/bin/env python3
"""Generate the original AstraOS wallpaper SVG.

The output is deterministic: star positions come from a fixed seed. The
wallpaper uses only original geometry and the Adwaita Sans font, which is
shipped by the desktop font set.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "files/usr/share/astra/branding/astraos-wallpaper.svg"

WIDTH = 3840
HEIGHT = 2160
STAR_PATH = (
    "M512 128 "
    "C536 404 620 488 896 512 "
    "C620 536 536 620 512 896 "
    "C488 620 404 536 128 512 "
    "C404 488 488 404 512 128 Z"
)


def stars() -> str:
    rng = random.Random(20261019)
    parts: list[str] = []
    for _ in range(120):
        x = rng.uniform(0, WIDTH)
        y = rng.uniform(0, HEIGHT)
        # Keep the left third quieter so desktop icons and windows have room.
        if x < WIDTH / 3 and rng.random() < 0.72:
            continue
        radius = rng.choice([0.8, 1.0, 1.2, 1.5, 1.9, 2.3])
        opacity = rng.uniform(0.12, 0.62)
        parts.append(
            f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{radius}" '
            f'fill="#E8EEF7" fill-opacity="{opacity:.2f}"/>'
        )
    return "\n  ".join(parts)


def chart(cx: float, cy: float, radii: list[float], opacity: float) -> str:
    parts: list[str] = []
    for index, radius in enumerate(radii):
        stroke = "#67E8F9" if index == len(radii) - 1 else "#1E3A5F"
        stroke_opacity = 0.22 if index == len(radii) - 1 else opacity
        parts.append(
            f'<circle cx="{cx}" cy="{cy}" r="{radius}" fill="none" '
            f'stroke="{stroke}" stroke-opacity="{stroke_opacity}" stroke-width="3"/>'
        )
    for degrees in range(0, 360, 30):
        angle = math.radians(degrees)
        inner = radii[0]
        outer = radii[-1]
        x1 = cx + math.cos(angle) * inner
        y1 = cy + math.sin(angle) * inner
        x2 = cx + math.cos(angle) * outer
        y2 = cy + math.sin(angle) * outer
        parts.append(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="#1E3A5F" stroke-opacity="{opacity * 0.55:.2f}" stroke-width="2"/>'
        )
    return "\n  ".join(parts)


def mark(cx: float, cy: float, scale: float) -> str:
    return f"""
  <g transform="translate({cx} {cy}) scale({scale}) translate(-512 -512)">
    <circle cx="512" cy="512" r="432" fill="none" stroke="#E8EEF7" stroke-opacity="0.30" stroke-width="6"/>
    <circle cx="512" cy="512" r="470" fill="none" stroke="#67E8F9" stroke-opacity="0.10" stroke-width="2"/>
    <g stroke="#67E8F9" stroke-opacity="0.55" stroke-width="4" stroke-linecap="round">
      <line x1="512" y1="52" x2="512" y2="104"/>
      <line x1="512" y1="920" x2="512" y2="972"/>
      <line x1="52" y1="512" x2="104" y2="512"/>
      <line x1="920" y1="512" x2="972" y2="512"/>
    </g>
    <g fill="#D6B36A" fill-opacity="0.75">
      <circle cx="817" cy="817" r="6"/>
      <circle cx="207" cy="817" r="6"/>
      <circle cx="207" cy="207" r="6"/>
      <circle cx="817" cy="207" r="6"/>
    </g>
    <path d="{STAR_PATH}" fill="#E8EEF7" fill-opacity="0.95"/>
    <g transform="translate(512 512) rotate(45) scale(0.34) translate(-512 -512)">
      <path d="{STAR_PATH}" fill="#05070D" fill-opacity="0.34"/>
    </g>
    <circle cx="512" cy="512" r="10" fill="#D6B36A"/>
  </g>"""


def main() -> None:
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {WIDTH} {HEIGHT}" width="{WIDTH}" height="{HEIGHT}">
  <defs>
    <linearGradient id="astra-wall-bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#05070D"/>
      <stop offset="0.55" stop-color="#070B14"/>
      <stop offset="1" stop-color="#0B1220"/>
    </linearGradient>
    <radialGradient id="astra-wall-glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#67E8F9" stop-opacity="0.16"/>
      <stop offset="0.45" stop-color="#1E3A5F" stop-opacity="0.10"/>
      <stop offset="1" stop-color="#05070D" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="astra-wall-mark-glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#67E8F9" stop-opacity="0.18"/>
      <stop offset="0.55" stop-color="#67E8F9" stop-opacity="0.04"/>
      <stop offset="1" stop-color="#67E8F9" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="{WIDTH}" height="{HEIGHT}" fill="url(#astra-wall-bg)"/>
  <ellipse cx="3000" cy="1080" rx="1500" ry="1200" fill="url(#astra-wall-glow)"/>

  <g opacity="0.55">
    {chart(3000, 1080, [300, 520, 760, 1040, 1320], 0.55)}
  </g>
  <g opacity="0.35">
    {chart(520, 360, [120, 180, 250, 330], 0.35)}
  </g>

  <g>
    {stars()}
  </g>

  <ellipse cx="3000" cy="1080" rx="760" ry="760" fill="url(#astra-wall-mark-glow)"/>
  {mark(3000, 1080, 0.92)}

  <line x1="160" y1="1908" x2="520" y2="1908" stroke="#67E8F9" stroke-opacity="0.30" stroke-width="3"/>
  <text x="160" y="2004"
        font-family="Adwaita Sans, Noto Sans, sans-serif"
        font-size="58"
        font-weight="400"
        letter-spacing="24"
        fill="#E8EEF7"
        fill-opacity="0.30">ASTRAOS</text>
</svg>
"""
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(svg, encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
