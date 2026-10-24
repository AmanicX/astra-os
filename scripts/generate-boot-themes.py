#!/usr/bin/env python3
"""Generate bespoke GRUB and Plymouth themes for AstraOS.

Derives all assets from the official AstraOS geometric logo and wallpaper.
"""

from __future__ import annotations

import math
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO_ROOT = Path(__file__).resolve().parents[1]
BRANDING_DIR = REPO_ROOT / "packages/astra-branding/files/usr/share"
WALLPAPER_SRC = BRANDING_DIR / "backgrounds/astraos/astraos-default.png"
LOGO_SRC = BRANDING_DIR / "icons/hicolor/512x512/apps/astraos-logo.png"

GRUB_THEME_DIR = BRANDING_DIR / "grub/themes/astra"
PLYMOUTH_THEME_DIR = BRANDING_DIR / "plymouth/themes/astra"


def create_grub_theme():
    GRUB_THEME_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Background image: 1920x1080 high quality resize of astraos-default.png
    if WALLPAPER_SRC.is_file():
        with Image.open(WALLPAPER_SRC) as img:
            bg = img.resize((1920, 1080), Image.Resampling.LANCZOS)
            bg.save(GRUB_THEME_DIR / "background.png", "PNG", optimize=True)
            print(f"saved {GRUB_THEME_DIR / 'background.png'}")

    # 2. Custom logo for GRUB (300x70): glowing emblem + "AstraOS" typography
    logo_img = Image.new("RGBA", (320, 72), (0, 0, 0, 0))
    if LOGO_SRC.is_file():
        with Image.open(LOGO_SRC) as mark:
            mark_small = mark.resize((64, 64), Image.Resampling.LANCZOS)
            logo_img.paste(mark_small, (8, 4), mark_small)

    draw = ImageDraw.Draw(logo_img)
    # Draw typography "AstraOS"
    # Fallback to default or Adwaita if available
    try:
        font = ImageFont.truetype("/usr/share/fonts/adwaita-fonts/AdwaitaSans-Regular.otf", 38)
    except Exception:
        try:
            font = ImageFont.truetype("/usr/share/fonts/noto/NotoSans-Regular.ttf", 38)
        except Exception:
            font = ImageFont.load_default()

    draw.text((84, 14), "AstraOS", fill=(232, 238, 247, 245), font=font)
    logo_img.save(GRUB_THEME_DIR / "logo.png", "PNG")
    print(f"saved {GRUB_THEME_DIR / 'logo.png'}")

    # 3. Selection bar slices (Height 40px)
    # select_w (left cap 12x40), select_c (center 2x40), select_e (right cap 12x40)
    w_cap = Image.new("RGBA", (12, 40), (0, 0, 0, 0))
    draw_w = ImageDraw.Draw(w_cap)
    # Rounded left rect with cyan highlight border
    draw_w.rounded_rectangle([0, 0, 24, 39], radius=6, fill=(21, 27, 40, 220), outline=(56, 189, 248, 240), width=1)
    # Accent cyan bar on left edge
    draw_w.line([(1, 8), (1, 31)], fill=(103, 232, 249, 255), width=2)
    w_cap.save(GRUB_THEME_DIR / "select_w.png", "PNG")

    e_cap = Image.new("RGBA", (12, 40), (0, 0, 0, 0))
    draw_e = ImageDraw.Draw(e_cap)
    draw_e.rounded_rectangle([-12, 0, 11, 39], radius=6, fill=(21, 27, 40, 220), outline=(56, 189, 248, 240), width=1)
    e_cap.save(GRUB_THEME_DIR / "select_e.png", "PNG")

    c_bar = Image.new("RGBA", (4, 40), (21, 27, 40, 220))
    draw_c = ImageDraw.Draw(c_bar)
    draw_c.line([(0, 0), (3, 0)], fill=(56, 189, 248, 240), width=1)
    draw_c.line([(0, 39), (3, 39)], fill=(56, 189, 248, 240), width=1)
    c_bar.save(GRUB_THEME_DIR / "select_c.png", "PNG")

    # 4. Progress bar slices (Height 4px)
    pb_w = Image.new("RGBA", (4, 4), (30, 41, 59, 200))
    pb_w.save(GRUB_THEME_DIR / "progress_bar_w.png", "PNG")
    pb_c = Image.new("RGBA", (4, 4), (30, 41, 59, 200))
    pb_c.save(GRUB_THEME_DIR / "progress_bar_c.png", "PNG")
    pb_e = Image.new("RGBA", (4, 4), (30, 41, 59, 200))
    pb_e.save(GRUB_THEME_DIR / "progress_bar_e.png", "PNG")

    ph_w = Image.new("RGBA", (4, 4), (56, 189, 248, 255))
    ph_w.save(GRUB_THEME_DIR / "progress_highlight_w.png", "PNG")
    ph_c = Image.new("RGBA", (4, 4), (103, 232, 249, 255))
    ph_c.save(GRUB_THEME_DIR / "progress_highlight_c.png", "PNG")
    ph_e = Image.new("RGBA", (4, 4), (56, 189, 248, 255))
    ph_e.save(GRUB_THEME_DIR / "progress_highlight_e.png", "PNG")

    # 5. Terminal box (16x16 slices)
    for name in ["nw", "n", "ne", "w", "c", "e", "sw", "s", "se"]:
        tbox = Image.new("RGBA", (8, 8), (11, 15, 25, 235))
        tbox.save(GRUB_THEME_DIR / f"terminal_box_{name}.png", "PNG")

    # 6. theme.txt
    theme_txt = """# AstraOS GRUB Theme
# Noctalia-inspired calm cosmic design

title-text: ""
desktop-image: "background.png"
desktop-color: "#05070d"
terminal-font: "Unifont Regular 16"
terminal-box: "terminal_box_*.png"
terminal-left: "10%"
terminal-top: "20%"
terminal-width: "80%"
terminal-height: "60%"
terminal-border: "0"

+ image {
    top = 18%
    left = 50%-160
    width = 320
    height = 72
    file = "logo.png"
}

+ boot_menu {
    top = 36%
    left = 50%-320
    width = 640
    height = 42%
    item_font = "Unifont Regular 16"
    item_color = "#94a3b8"
    selected_item_color = "#ffffff"
    item_height = 40
    item_padding = 10
    item_spacing = 6
    selected_item_pixmap_style = "select_*.png"
}

+ progress_bar {
    id = "__timeout__"
    left = 50%-180
    top = 82%
    width = 360
    height = 4
    show_text = false
    bar_style = "progress_bar_*.png"
    highlight_style = "progress_highlight_*.png"
}
"""
    (GRUB_THEME_DIR / "theme.txt").write_text(theme_txt, encoding="utf-8")
    print(f"saved {GRUB_THEME_DIR / 'theme.txt'}")


def create_plymouth_theme():
    PLYMOUTH_THEME_DIR.mkdir(parents=True, exist_ok=True)

    # 1. watermark.png (240x48 at bottom of screen)
    watermark = Image.new("RGBA", (260, 48), (0, 0, 0, 0))
    draw_wm = ImageDraw.Draw(watermark)
    try:
        wm_font = ImageFont.truetype("/usr/share/fonts/adwaita-fonts/AdwaitaSans-Regular.otf", 20)
    except Exception:
        wm_font = ImageFont.load_default()
    draw_wm.text((20, 12), "A S T R A   O S", fill=(232, 238, 247, 140), font=wm_font)
    watermark.save(PLYMOUTH_THEME_DIR / "watermark.png", "PNG")
    print(f"saved {PLYMOUTH_THEME_DIR / 'watermark.png'}")

    # 2. 24 animation frames for breathing cosmic star emblem (160x160)
    base_mark = None
    if LOGO_SRC.is_file():
        with Image.open(LOGO_SRC) as src:
            base_mark = src.convert("RGBA").resize((128, 128), Image.Resampling.LANCZOS)

    num_frames = 24
    for i in range(num_frames):
        frame = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
        angle = (i / num_frames) * 360.0
        phase = math.sin((i / num_frames) * 2 * math.pi)  # -1 to +1
        alpha_scale = 0.75 + 0.25 * phase  # 0.5 to 1.0

        # Draw subtle rotating orbital reticle
        draw_f = ImageDraw.Draw(frame)
        cx, cy = 80, 80
        r_inner = 70
        r_outer = 76

        for tick_deg in range(0, 360, 45):
            rad = math.radians(tick_deg + angle)
            x1 = cx + math.cos(rad) * r_inner
            y1 = cy + math.sin(rad) * r_inner
            x2 = cx + math.cos(rad) * r_outer
            y2 = cy + math.sin(rad) * r_outer
            draw_f.line([(x1, y1), (x2, y2)], fill=(103, 232, 249, int(110 * alpha_scale)), width=2)

        draw_f.circle((cx, cy), r_inner, outline=(103, 232, 249, int(35 * alpha_scale)), width=1)

        # Paste base star mark with pulsing opacity
        if base_mark:
            bm = base_mark.copy()
            # Modulate alpha
            r, g, b, a = bm.split()
            a = a.point(lambda p: int(p * alpha_scale))
            bm.putalpha(a)
            frame.paste(bm, (16, 16), bm)

        frame_num = f"{i+1:04d}"
        frame.save(PLYMOUTH_THEME_DIR / f"animation-{frame_num}.png", "PNG")

    print(f"saved 24 animation frames to {PLYMOUTH_THEME_DIR}")

    # 3. Dialog support icons (lock.png, bullet.png, entry.png)
    lock_img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw_l = ImageDraw.Draw(lock_img)
    draw_l.rounded_rectangle([6, 14, 25, 28], radius=3, fill=(103, 232, 249, 220))
    draw_l.arc([9, 6, 22, 18], start=180, end=0, fill=(103, 232, 249, 220), width=3)
    lock_img.save(PLYMOUTH_THEME_DIR / "lock.png", "PNG")

    bullet_img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw_b = ImageDraw.Draw(bullet_img)
    draw_b.circle((8, 8), 4, fill=(103, 232, 249, 240))
    bullet_img.save(PLYMOUTH_THEME_DIR / "bullet.png", "PNG")

    entry_img = Image.new("RGBA", (240, 36), (0, 0, 0, 0))
    draw_e = ImageDraw.Draw(entry_img)
    draw_e.rounded_rectangle([0, 0, 239, 35], radius=6, fill=(11, 15, 25, 220), outline=(56, 189, 248, 180), width=1)
    entry_img.save(PLYMOUTH_THEME_DIR / "entry.png", "PNG")

    # 4. astra.plymouth
    plymouth_conf = """[Plymouth Theme]
Name=AstraOS
Description=Calm cosmic boot splash for AstraOS
ModuleName=two-step

[two-step]
Font=Adwaita Sans 12
TitleFont=Adwaita Sans Light 28
MonospaceFont=Adwaita Mono 12
ImageDir=/usr/share/plymouth/themes/astra
DialogHorizontalAlignment=.5
DialogVerticalAlignment=.6
TitleHorizontalAlignment=.5
TitleVerticalAlignment=.382
HorizontalAlignment=.5
VerticalAlignment=.45
WatermarkHorizontalAlignment=.5
WatermarkVerticalAlignment=.92
Transition=fade
TransitionDuration=0.3
BackgroundStartColor=0x05070d
BackgroundEndColor=0x0b1220
ProgressBar=false

[boot-up]
UseEndAnimation=false

[shutdown]
UseEndAnimation=false

[reboot]
UseEndAnimation=false
"""
    (PLYMOUTH_THEME_DIR / "astra.plymouth").write_text(plymouth_conf, encoding="utf-8")
    print(f"saved {PLYMOUTH_THEME_DIR / 'astra.plymouth'}")


def create_systemd_boot_splash():
    out_dir = BRANDING_DIR / "astra/branding"
    out_dir.mkdir(parents=True, exist_ok=True)
    if WALLPAPER_SRC.is_file():
        with Image.open(WALLPAPER_SRC) as img:
            splash = img.resize((1024, 768), Image.Resampling.LANCZOS).convert("RGB")
            # Overlay logo
            if LOGO_SRC.is_file():
                with Image.open(LOGO_SRC) as mark:
                    mark_sm = mark.resize((128, 128), Image.Resampling.LANCZOS)
                    splash.paste(mark_sm, (512 - 64, 384 - 80), mark_sm)
            splash.save(out_dir / "splash.bmp", "BMP")
            print(f"saved {out_dir / 'splash.bmp'}")


if __name__ == "__main__":
    create_grub_theme()
    create_plymouth_theme()
    create_systemd_boot_splash()
    print("All GRUB, Plymouth and systemd-boot theme assets successfully generated!")
