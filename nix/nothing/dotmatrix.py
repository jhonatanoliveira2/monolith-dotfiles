#!/usr/bin/env python3
# monolith-dotmatrix: renders a still picture as an LED dot matrix (MONOLITH "Nothing" theme).
#
# Adapted from dotmatrix.py of NIHIL Shell by poligle (MIT, github.com/poligle/Nihil-Shell; notice in
# nix/nothing/LICENSE.NIHIL): the luminance
# curve (black point raised so dark skies stay off, isolated highlights still light their cell) and the
# cover-crop to the output's native size come from there. New here: LED shapes, size + spacing instead of a
# pitch, colours, inversion, dithering, colour LEDs, a vectorised renderer (4K in about a second) and a CLI.
#
#   one output:   monolith-dotmatrix SOURCE -o OUT.png --resolution 1920x1080 [options]
#   several:      monolith-dotmatrix SOURCE --outdir DIR --output eDP-1:1920x1200 --output DP-1:2560x1440
#   cache key:    monolith-dotmatrix --key [options]      (the same string the Nix module computes)
#
# The picture is cover-cropped to each resolution, so every LED sits on whole pixels (nothing is scaled after
# rendering). Every cell of size + spacing px holds an unlit LED (--off) and, over it, a lit one whose colour
# (and, without dithering, size) follows the cell's brightness. Animated pictures are refused: only still
# wallpapers are converted. The source file is only read, never written.

import argparse
import os
import sys

import numpy as np
from PIL import Image

SHAPES = ("circle", "square", "rounded")
DITHERS = ("none", "floyd", "bayer")
# version of the look: part of the cache key, so a change of the curve below renders every wallpaper again
LOOK = "v2"
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32)


def colour(text):
    value = text.strip().lstrip("#")
    if len(value) != 6 or any(c not in "0123456789abcdefABCDEF" for c in value):
        raise argparse.ArgumentTypeError(f"not a #RRGGBB colour: {text}")
    return value.lower()


def rgb(hex6):
    return np.array([int(hex6[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def resolution(text):
    try:
        w, h = (int(v) for v in text.lower().split("x"))
    except ValueError:
        raise argparse.ArgumentTypeError(f"not WIDTHxHEIGHT: {text}")
    if w < 16 or h < 16 or w > 16384 or h > 16384:
        raise argparse.ArgumentTypeError(f"resolution out of range: {text}")
    return w, h


def key(a):
    """Canonical description of the look; equal keys = identical output (the Nix module builds the same)."""
    return "-".join([LOOK, str(a.size), str(a.spacing), a.shape, a.dither, str(a.levels), "inv" if a.invert else "pos",
                     "color" if a.color else "mono", a.lit, a.off, a.background])


def cover(img, width, height):
    scale = max(width / img.width, height / img.height)
    img = img.resize((max(width, round(img.width * scale)), max(height, round(img.height * scale))), Image.LANCZOS)
    left, top = (img.width - width) // 2, (img.height - height) // 2
    return img.crop((left, top, left + width, top + height))


def stamp(shape, diameter, pitch, sub=4):
    """Coverage (0..1) of one LED of `diameter` px centred in a pitch x pitch cell, antialiased."""
    n = pitch * sub
    c = (np.arange(n, dtype=np.float32) + 0.5) / sub - pitch / 2
    x, y = np.meshgrid(c, c)
    r = diameter / 2
    if shape == "circle":
        inside = x * x + y * y <= r * r
    elif shape == "square":
        inside = (np.abs(x) <= r) & (np.abs(y) <= r)
    else:  # rounded square, corner radius 40 % of the half side
        k = r * 0.4
        qx, qy = np.maximum(np.abs(x) - (r - k), 0), np.maximum(np.abs(y) - (r - k), 0)
        inside = (np.abs(x) <= r) & (np.abs(y) <= r) & (qx * qx + qy * qy <= k * k)
    return inside.astype(np.float32).reshape(pitch, sub, pitch, sub).mean(axis=(1, 3))


def quantise(level, mode, levels):
    if mode == "none":
        return level
    steps = max(2, levels) - 1
    if mode == "bayer":
        rows, cols = level.shape
        t = (np.tile(BAYER4, (rows // 4 + 1, cols // 4 + 1))[:rows, :cols] + 0.5) / 16.0
        return np.clip(np.floor(level * steps + t), 0, steps) / steps
    out = level.astype(np.float32).copy()  # Floyd-Steinberg over the grid of LEDs
    rows, cols = out.shape
    for j in range(rows):
        row, nxt = out[j], out[j + 1] if j + 1 < rows else None
        for i in range(cols):
            old = row[i]
            new = min(max(round(old * steps), 0), steps) / steps
            row[i] = new
            e = old - new
            if i + 1 < cols:
                row[i + 1] += e * 7 / 16
            if nxt is not None:
                if i > 0:
                    nxt[i - 1] += e * 3 / 16
                nxt[i] += e * 5 / 16
                if i + 1 < cols:
                    nxt[i + 1] += e * 1 / 16
    return np.clip(out, 0, 1)


def render(source, width, height, a):
    pitch = a.size + a.spacing
    img = cover(source, width, height)
    px = np.asarray(img, dtype=np.float32) / 255.0
    lum = 0.2126 * px[..., 0] + 0.7152 * px[..., 1] + 0.0722 * px[..., 2]
    low, high = np.percentile(lum, [2.0, 99.7])
    lum = np.clip((lum - low) / max(high - low, 1e-6), 0.0, 1.0)

    cols, rows = width // pitch, height // pitch
    ox, oy = (width - cols * pitch) // 2, (height - rows * pitch) // 2
    cells = lum[oy:oy + rows * pitch, ox:ox + cols * pitch].reshape(rows, pitch, cols, pitch)
    level = np.clip((cells.mean(axis=(1, 3)) - a.black) / (1.0 - a.black), 0.0, 1.0) ** a.gamma
    stars = np.clip((cells.max(axis=(1, 3)) - 0.55) / 0.45, 0.0, 1.0)
    level = np.maximum(level, 0.9 * stars)
    # contrast around the middle (blacks blacker, whites whiter), then brightness
    level = np.clip(np.clip(0.5 + (level - 0.5) * a.contrast, 0.0, 1.0) * a.brightness, 0.0, 1.0)
    if a.invert:
        level = 1.0 - level
    level = quantise(level, a.dither, a.levels)

    bg, off, lit = rgb(a.background), rgb(a.off), rgb(a.lit)
    if a.color:  # each LED takes its cell's hue at full brightness
        mean = px[oy:oy + rows * pitch, ox:ox + cols * pitch].reshape(rows, pitch, cols, pitch, 3).mean(axis=(1, 3))
        peak = np.maximum(mean.max(axis=2, keepdims=True), 1e-3)
        hue = np.clip(mean / peak, 0, 1) * 255.0
        target = 0.25 * lit + 0.75 * hue
    else:
        target = np.broadcast_to(lit, (rows, cols, 3))
    led = off + (target - off) * level[..., None]                        # (rows, cols, 3)

    # LED size: with dithering every lit LED is whole; without it, it grows with the brightness
    buckets = 16
    if a.dither == "none":
        b = np.clip(np.round(np.sqrt(level) * (buckets - 1)), 0, buckets - 1).astype(np.int32)
        sizes = [a.size * (0.3 + 0.7 * k / (buckets - 1)) for k in range(buckets)]
    else:
        b = np.full(level.shape, buckets - 1, dtype=np.int32)
        sizes = [a.size] * buckets
    stamps = np.stack([stamp(a.shape, d, pitch) for d in sizes])         # (buckets, pitch, pitch)
    m_off = stamp(a.shape, a.size, pitch)[None, :, None, :, None]
    m_lit = stamps[b].transpose(0, 2, 1, 3)[..., None]                   # (rows, pitch, cols, pitch, 1)
    m_lit = m_lit * (level > 0.02)[:, None, :, None, None]

    grid = np.empty((rows, pitch, cols, pitch, 3), dtype=np.float32)
    grid[:] = bg
    grid += (off - grid) * m_off
    grid += (led[:, None, :, None, :] - grid) * m_lit

    out = np.empty((height, width, 3), dtype=np.float32)
    out[:] = bg
    out[oy:oy + rows * pitch, ox:ox + cols * pitch] = grid.reshape(rows * pitch, cols * pitch, 3)
    return Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGB")


def parse_output(spec):
    name, _, size = spec.rpartition(":")
    if not name or "/" in name:
        raise argparse.ArgumentTypeError(f"not NAME:WIDTHxHEIGHT: {spec}")
    return name, resolution(size)


def main():
    p = argparse.ArgumentParser(prog="monolith-dotmatrix", description="Render a still picture as an LED dot matrix.")
    p.add_argument("source", nargs="?", help="picture to convert (PNG, JPEG, WebP...); never modified")
    p.add_argument("-o", "--out", help="output PNG (with --resolution)")
    p.add_argument("-r", "--resolution", type=resolution, help="WIDTHxHEIGHT of the output, e.g. 2560x1440")
    p.add_argument("--outdir", help="folder for --output (one NAME.png per output)")
    p.add_argument("--output", action="append", type=parse_output, default=[], help="NAME:WIDTHxHEIGHT, repeatable")
    p.add_argument("--key", action="store_true", help="print the cache key of these options and exit")
    p.add_argument("--size", type=int, default=6, help="LED diameter in px (default 6)")
    p.add_argument("--spacing", type=int, default=3, help="gap between LEDs in px (default 3)")
    p.add_argument("--shape", choices=SHAPES, default="circle")
    p.add_argument("--lit", type=colour, default="ffffff", help="colour of a fully lit LED")
    p.add_argument("--off", type=colour, default="0e0e0e", help="colour of an unlit LED")
    p.add_argument("--background", type=colour, default="000000", help="colour between the LEDs")
    p.add_argument("--color", action="store_true", help="colour LEDs (the picture's hues) instead of monochrome")
    p.add_argument("--invert", action="store_true", help="light the dark parts")
    p.add_argument("--dither", choices=DITHERS, default="none", help="none: LED size and brightness follow the "
                   "picture; floyd / bayer: whole LEDs at --levels brightness steps")
    p.add_argument("--levels", type=int, default=2, help="brightness steps with dithering (2 = on / off)")
    p.add_argument("--gamma", type=float, default=1.25)
    p.add_argument("--black", type=float, default=0.12, help="black point (0..0.9): below it LEDs stay off")
    p.add_argument("--contrast", type=float, default=1.35, help="contrast around the middle grey (1 = none)")
    p.add_argument("--brightness", type=float, default=1.12, help="brightness of the lit LEDs (1 = none)")
    a = p.parse_args()

    if not 1 <= a.size <= 64 or not 0 <= a.spacing <= 64:
        p.error("--size must be 1..64 and --spacing 0..64")
    if not 2 <= a.levels <= 16:
        p.error("--levels must be 2..16")
    a.black = min(max(a.black, 0.0), 0.9)
    a.contrast = min(max(a.contrast, 0.2), 4.0)
    a.brightness = min(max(a.brightness, 0.2), 3.0)
    if a.key:
        print(key(a))
        return 0
    if not a.source:
        p.error("SOURCE is required")
    jobs = []
    if a.out or a.resolution:
        if not (a.out and a.resolution):
            p.error("-o needs --resolution (and the other way round)")
        jobs.append((a.out, a.resolution))
    if a.output:
        if not a.outdir:
            p.error("--output needs --outdir")
        jobs += [(os.path.join(a.outdir, f"{name}.png"), size) for name, size in a.output]
    if not jobs:
        p.error("nothing to do: give -o OUT --resolution WxH, or --outdir DIR --output NAME:WxH")

    try:
        source = Image.open(a.source)
        if getattr(source, "is_animated", False) or getattr(source, "n_frames", 1) > 1:
            print(f"monolith-dotmatrix: {a.source}: animated pictures are not supported (still wallpapers only)",
                  file=sys.stderr)
            return 2
        source = source.convert("RGB")
    except (OSError, ValueError) as e:
        print(f"monolith-dotmatrix: {a.source}: {e}", file=sys.stderr)
        return 1

    for path, (w, h) in jobs:
        if os.path.realpath(path) == os.path.realpath(a.source):
            print("monolith-dotmatrix: refusing to overwrite the source picture", file=sys.stderr)
            return 1
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        tmp = path + ".part"
        render(source, w, h, a).save(tmp, format="PNG", optimize=False, compress_level=6)
        os.replace(tmp, path)  # atomic: a reader never sees half a file
    return 0


if __name__ == "__main__":
    sys.exit(main())
