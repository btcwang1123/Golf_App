#!/usr/bin/env python3
"""Generate app icons and launch logo for 高手 (minimal pin concept).

Run from repo root:  python3 Tools/make_icons.py
Outputs into GolfApp/ and GolfWatch/ asset catalogs. Drawn on a 1024 grid,
rendered 4x and downsampled for anti-aliasing.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SS = 4  # supersample
N = 1024 * SS

GOLD_LIGHT, GOLD, GOLD_DEEP = (0xE9, 0xD3, 0xA0), (0xD6, 0xB9, 0x7C), (0xA7, 0x85, 0x4A)
INK, FOREST, FOREST_TOP = (0x0A, 0x12, 0x0E), (0x14, 0x26, 0x1D), (0x1F, 0x3A, 0x2C)
IVORY = (0xF3, 0xEF, 0xE4)


DX = -36  # optical centering: shift mark left so the pennant doesn't pull right


def s(v):
    return v * SS


def sx(v):
    return (v + DX) * SS


def gradient(c0, c1, c2):
    """Diagonal top-left → bottom-right three-stop gradient, full bleed."""
    small = Image.new("RGB", (256, 256))
    px = small.load()
    for y in range(256):
        for x in range(256):
            t = (x + y) / 510
            a, b, u = (c0, c1, t / 0.5) if t < 0.5 else (c1, c2, (t - 0.5) / 0.5)
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * u) for i in range(3))
    return small.resize((N, N), Image.BICUBIC).convert("RGBA")


def draw_pin(img, pole, flag, flag_shade, cup_rim, cup):
    d = ImageDraw.Draw(img)
    # putting surface + cup
    d.ellipse([sx(302), s(720), sx(722), s(820)], fill=cup_rim)
    d.ellipse([sx(468), s(758), sx(556), s(782)], fill=cup)
    # pole with rounded top
    d.rounded_rectangle([sx(498), s(212), sx(526), s(770)], radius=s(14), fill=pole)
    # pennant: two facets for a subtle fold
    d.polygon([(sx(526), s(222)), (sx(770), s(302)), (sx(526), s(302))], fill=flag)
    d.polygon([(sx(526), s(302)), (sx(770), s(302)), (sx(526), s(382))], fill=flag_shade)


def finish(img, path, size=1024, mode="RGB"):
    path.parent.mkdir(parents=True, exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    out.convert(mode).save(path)
    print("wrote", path.relative_to(ROOT))


ios = ROOT / "GolfApp/Resources/Assets.xcassets/AppIcon.appiconset"

# Light (default): champagne gold field, forest-ink pin
light = gradient(GOLD_LIGHT, GOLD, GOLD_DEEP)
draw_pin(light, pole=INK, flag=FOREST, flag_shade=INK, cup_rim=(0x9A, 0x7A, 0x42), cup=INK)
finish(light, ios / "icon-light.png")

# Dark: forest field, gold pin
dark = gradient(FOREST_TOP, FOREST, INK)
draw_pin(dark, pole=IVORY, flag=GOLD, flag_shade=GOLD_DEEP, cup_rim=(0x24, 0x44, 0x33), cup=INK)
finish(dark, ios / "icon-dark.png")

# Tinted: grayscale on black; the system applies the tint colour
tinted = Image.new("RGBA", (N, N), (0, 0, 0, 255))
draw_pin(tinted, pole=(255, 255, 255), flag=(235, 235, 235), flag_shade=(190, 190, 190),
         cup_rim=(90, 90, 90), cup=(0, 0, 0))
finish(tinted, ios / "icon-tinted.png")

# watchOS: same as light (system masks to a circle; artwork stays inside r≈340)
finish(light, ROOT / "GolfWatch/Resources/Assets.xcassets/AppIcon.appiconset/icon.png")

# Launch logo: gold pin on transparent, sits on LaunchBackground (Theme.background)
logo = Image.new("RGBA", (N, N), (0, 0, 0, 0))
draw_pin(logo, pole=IVORY, flag=GOLD, flag_shade=GOLD_DEEP, cup_rim=(0x24, 0x44, 0x33), cup=INK)
logo = logo.crop((s(156), s(196), s(796), s(836)))  # 640x640 around the mark
launch = ROOT / "GolfApp/Resources/Assets.xcassets/LaunchLogo.imageset"
for scale, px in ((2, 320), (3, 480)):
    out = logo.resize((px, px), Image.LANCZOS)
    out.save(launch / f"logo@{scale}x.png")
    print("wrote", (launch / f"logo@{scale}x.png").relative_to(ROOT))
