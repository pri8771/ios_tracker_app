#!/usr/bin/env python3
"""Generate the Roam app-icon and launch-logo PNGs.

Dependency-free (Python stdlib only — uses zlib for PNG compression). Produces an
on-brand icon: a warm "golden-hour" sunset gradient (coral -> magenta -> violet)
with a clean white map-pin glyph, matching Roam's design system. The launch logo
is the same white pin on a transparent background.

Run:  python3 Scripts/generate_app_assets.py
"""
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Roam", "Resources", "Assets.xcassets")

# Brand gradient stops (sRGB 0-255): coral -> magenta -> violet.
G0 = (255, 138, 77)    # #FF8A4D coral
G1 = (245, 85, 158)    # #F5559E magenta
G2 = (124, 58, 237)    # #7C3AED violet
WHITE = (255, 255, 255)


def _png(path, width, height, pixel_fn, has_alpha):
    """Write a PNG. pixel_fn(x, y) -> (r, g, b) or (r, g, b, a)."""
    color_type = 6 if has_alpha else 2
    bpp = 4 if has_alpha else 3
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter: none
        for x in range(width):
            px = pixel_fn(x, y)
            raw += bytes(px[:bpp])
    comp = zlib.compress(bytes(raw), 9)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", comp))
        f.write(chunk(b"IEND", b""))


def _lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _gradient(x, y, size):
    """Diagonal coral->magenta->violet gradient at (x, y)."""
    t = (x + y) / (2.0 * (size - 1))
    t = max(0.0, min(1.0, t))
    if t < 0.5:
        return _lerp(G0, G1, t / 0.5)
    return _lerp(G1, G2, (t - 0.5) / 0.5)


def _sign(ax, ay, bx, by, px, py):
    return (px - bx) * (ay - by) - (ax - bx) * (py - by)


def _in_triangle(px, py, a, b, c):
    d1 = _sign(a[0], a[1], b[0], b[1], px, py)
    d2 = _sign(b[0], b[1], c[0], c[1], px, py)
    d3 = _sign(c[0], c[1], a[0], a[1], px, py)
    has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (has_neg and has_pos)


def _pin_inside(px, py, size):
    """Whether (px, py) is inside the white map-pin silhouette (with a hole)."""
    cx = size / 2.0
    head_cy = 0.40 * size
    head_r = 0.205 * size
    tip_y = 0.82 * size
    hole_r = 0.082 * size

    in_head = (px - cx) ** 2 + (py - head_cy) ** 2 <= head_r ** 2
    bx = head_r * 0.86
    by = head_cy + head_r * 0.34
    in_body = _in_triangle(px, py, (cx, tip_y), (cx - bx, by), (cx + bx, by))
    inside = in_head or in_body
    if inside and (px - cx) ** 2 + (py - head_cy) ** 2 <= hole_r ** 2:
        inside = False
    return inside


def _pin_coverage(x, y, size, samples=3):
    """Supersampled coverage (0..1) of the pin glyph at pixel (x, y)."""
    hit = 0
    step = 1.0 / samples
    for sx in range(samples):
        for sy in range(samples):
            px = x + (sx + 0.5) * step
            py = y + (sy + 0.5) * step
            if _pin_inside(px, py, size):
                hit += 1
    return hit / (samples * samples)


def make_app_icon(path, size=1024):
    def pixel(x, y):
        bg = _gradient(x, y, size)
        a = _pin_coverage(x, y, size)
        return tuple(round(bg[i] * (1 - a) + WHITE[i] * a) for i in range(3))
    _png(path, size, size, pixel, has_alpha=False)


def make_launch_logo(path, size=600):
    def pixel(x, y):
        a = _pin_coverage(x, y, size)
        return (WHITE[0], WHITE[1], WHITE[2], round(255 * a))
    _png(path, size, size, pixel, has_alpha=True)


def main():
    appicon_dir = os.path.join(ASSETS, "AppIcon.appiconset")
    logo_dir = os.path.join(ASSETS, "LaunchLogo.imageset")
    os.makedirs(appicon_dir, exist_ok=True)
    os.makedirs(logo_dir, exist_ok=True)
    make_app_icon(os.path.join(appicon_dir, "AppIcon-1024.png"))
    make_launch_logo(os.path.join(logo_dir, "LaunchLogo.png"))
    print("Wrote AppIcon-1024.png and LaunchLogo.png")


if __name__ == "__main__":
    main()
