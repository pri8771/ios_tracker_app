#!/usr/bin/env python3
"""Generate placeholder app-icon and launch-logo PNGs for ZIP Tracker.

Dependency-free (Python stdlib only — uses zlib for PNG compression). Produces a
simple, on-brand "location" glyph (a white ring with a center dot) so the app has
a valid, opaque App Store icon and a transparent launch logo without requiring
any design tools. Replace these with real artwork before shipping.

Run:  python3 Scripts/generate_app_assets.py
"""
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "ZIPTracker", "Resources", "Assets.xcassets")

# Brand teal (sRGB 0-255).
BRAND = (15, 118, 110)      # #0F766E
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


def _glyph_alpha(x, y, size):
    """Coverage (0..1) of the location glyph at pixel (x, y) for a square image."""
    cx = cy = size / 2.0
    dx, dy = x + 0.5 - cx, y + 0.5 - cy
    dist = math.hypot(dx, dy)
    R = 0.34 * size            # outer ring radius
    ring_inner = 0.66 * R      # inner edge of the ring
    dot = 0.30 * R             # center dot radius
    aa = 1.2                   # anti-alias width (px)

    def band(d, edge, inside):
        # Smooth step around an edge; `inside` True => filled when d < edge.
        if inside:
            return max(0.0, min(1.0, (edge - d) / aa + 0.5))
        return max(0.0, min(1.0, (d - edge) / aa + 0.5))

    ring = min(band(dist, R, True), band(dist, ring_inner, False))
    center = band(dist, dot, True)
    return max(ring, center)


def make_app_icon(path, size=1024):
    def pixel(x, y):
        a = _glyph_alpha(x, y, size)
        # Composite white glyph over the opaque brand background (no alpha).
        r = round(BRAND[0] * (1 - a) + WHITE[0] * a)
        g = round(BRAND[1] * (1 - a) + WHITE[1] * a)
        b = round(BRAND[2] * (1 - a) + WHITE[2] * a)
        return (r, g, b)
    _png(path, size, size, pixel, has_alpha=False)


def make_launch_logo(path, size=600):
    def pixel(x, y):
        a = _glyph_alpha(x, y, size)
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
