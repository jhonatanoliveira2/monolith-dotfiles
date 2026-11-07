#!/usr/bin/env python3
# MONOLITH Dots: the cursor theme of the Nothing theme. Every cursor is drawn with LEDs (white dots with a dark
# rim and a soft shadow, so they read on light and dark backgrounds alike); the pointer is a "+".
#
#   cursor.py OUTDIR [--name Monolith-Dots] [--sizes 24,28,32,48,64,96] [--preview preview.png]
#
# Writes OUTDIR/index.theme and OUTDIR/cursors/<shape> as XCursor files (written here directly: a header, a
# table of contents and one ARGB image per size and frame), plus symbolic links for every alias name.

import argparse
import math
import os
import struct

from PIL import Image, ImageDraw, ImageFilter

SS = 4                          # supersampling
WHITE = (242, 242, 242, 255)
RIM = (0, 0, 0, 255)
SHADOW = (0, 0, 0, 110)


def dot_grid(size, n=9):
    """Lattice step for a size: the shapes are laid out on an n x n grid of LED positions."""
    return size / n


def render(size, leds, lit_alpha=None):
    """leds: [(gx, gy, scale, alpha)] in grid units from the centre. Returns an RGBA image size x size."""
    S = size * SS
    step = dot_grid(size) * SS
    r = step * 0.36                       # LED radius
    rim = max(SS * 1.2, r * 0.42)         # dark outline width
    c = S / 2
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    top = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ds, db, dt = ImageDraw.Draw(shadow), ImageDraw.Draw(base), ImageDraw.Draw(top)
    for gx, gy, k, a in leds:
        x, y, rr = c + gx * step, c + gy * step, r * k
        o = rr + rim
        off = SS * 1.0
        ds.ellipse((x - o + off, y - o + off * 1.5, x + o + off, y + o + off * 1.5), fill=SHADOW)
        db.ellipse((x - o, y - o, x + o, y + o), fill=RIM)
        col = WHITE[:3] + (round(255 * a),)
        if a < 1:   # a dimmed LED: grey on its rim instead of translucent
            g = round(60 + 182 * a)
            col = (g, g, g, 255)
        dt.ellipse((x - rr, y - rr, x + rr, y + rr), fill=col)
    shadow = shadow.filter(ImageFilter.GaussianBlur(SS * 1.2))
    out = Image.alpha_composite(Image.alpha_composite(shadow, base), top)
    return out.resize((size, size), Image.LANCZOS)


# ── shapes (grid units, centre 0,0; the hotspot is the centre) ──
def plus(arm=3, big=1.25):
    leds = [(0, 0, big, 1)]
    for i in range(1, arm + 1):
        leds += [(i, 0, 1, 1), (-i, 0, 1, 1), (0, i, 1, 1), (0, -i, 1, 1)]
    return leds


def ring(radius, count, k=0.7, lit=None, head=None):
    out = []
    for i in range(count):
        a = -math.pi / 2 + i * 2 * math.pi / count
        alpha = 1.0
        if head is not None:   # a light running round the ring with a fading trail
            d = (head - i) % count
            alpha = max(0.18, 1 - d * 0.22)
        out.append((radius * math.cos(a), radius * math.sin(a), k, alpha))
    return out


def line(dx, dy, half=3, k=1):
    return [(dx * i, dy * i, k, 1) for i in range(-half, half + 1)]


def arrowheads(dx, dy, half=3):
    # two dots behind each end, splayed: a chevron pointing outwards
    px, py = -dy, dx
    out = []
    for s in (1, -1):
        ex, ey = dx * half * s, dy * half * s
        bx, by = ex - dx * s, ey - dy * s
        out += [(bx + px, by + py, 0.85, 1), (bx - px, by - py, 0.85, 1)]
    return out


def resize(dx, dy):
    # diagonals step on the grid by (1, 1): keep the same length as the straight ones
    half = 3 if dx == 0 or dy == 0 else 2
    return line(dx, dy, half) + arrowheads(dx, dy, half)


SHAPES = {
    "plus": lambda: plus(),
    "pointer": lambda: plus(2, 1.4) + ring(3.4, 12, 0.62),
    "text": lambda: line(0, 1, 3) + [(-1, -3, 0.8, 1), (1, -3, 0.8, 1), (-1, 3, 0.8, 1), (1, 3, 0.8, 1)],
    "not-allowed": lambda: line(1, 1, 2) + line(1, -1, 2)[:2] + line(1, -1, 2)[3:] + ring(3.6, 14, 0.6),
    "move": lambda: plus() + arrowheads(1, 0) + arrowheads(0, 1),
    "ew": lambda: resize(1, 0),
    "ns": lambda: resize(0, 1),
    "nwse": lambda: resize(1, 1),
    "nesw": lambda: resize(1, -1),
}
ANIMATED = {   # name -> (frames, ms per frame, frame(i) -> leds)
    "wait": (12, 70, lambda i: ring(3.2, 12, 0.8, head=i)),
    "progress": (12, 70, lambda i: plus(2, 1.2) + ring(3.6, 12, 0.6, head=i)),
}
ALIASES = {
    "plus": "default left_ptr arrow top_left_arrow crosshair cross tcross cell context-menu alias copy dnd-none "
            "dnd-copy dnd-link dnd-move dnd-ask color-picker zoom-in zoom-out center_ptr right_ptr draft_large "
            "draft_small left_ptr_arrow",
    "pointer": "pointer hand hand1 hand2 pointing_hand help question_arrow whats_this left_ptr_help openhand grab "
               "e29285e634086352946a0e7090d73106 9d800788f1b08800ae810202380a0822",
    "text": "text xterm ibeam vertical-text",
    "wait": "watch",
    "progress": "left_ptr_watch half-busy 00000000000000020006000e7e9ffc3f 08e8e1c95fe2fc01f976f1e063a24ccd "
                "3ecb610c1bf2410f44200f48c40d3599",
    "not-allowed": "no-drop forbidden crossed_circle circle dnd-no-drop X_cursor x-cursor pirate",
    "move": "fleur all-scroll grabbing closedhand size_all 4498f0e0c1937ffe01fd06f973665830 "
            "9081237383d90e509aa00f00170e968f",
    "ew": "ew-resize col-resize e-resize w-resize h_double_arrow sb_h_double_arrow size_hor left_side right_side "
          "split_h 028006030e0e7ebffc7f7070c0600140 14fef782d02440884392942c11205230",
    "ns": "ns-resize row-resize n-resize s-resize v_double_arrow sb_v_double_arrow size_ver top_side bottom_side "
          "split_v 00008160000006810000408080010102 2870a09082c103050810ffdffffe0204",
    "nwse": "nwse-resize nw-resize se-resize top_left_corner bottom_right_corner size_fdiag bd_double_arrow "
            "c7088f0f3e6c8088236ef8e1e3e70000",
    "nesw": "nesw-resize ne-resize sw-resize top_right_corner bottom_left_corner size_bdiag fd_double_arrow "
            "fcf1c3c7cd4491d801f1e1c78f100000",
}


def xcursor(images):
    """images: [(nominal, Image, xhot, yhot, delay)] -> bytes of an XCursor file."""
    n = len(images)
    header = struct.pack("<4sIII", b"Xcur", 16, 0x10000, n)
    pos = 16 + n * 12
    toc, chunks = b"", b""
    for nominal, img, xh, yh, delay in images:
        w, h = img.size
        toc += struct.pack("<III", 0xFFFD0002, nominal, pos)
        raw, px = img.tobytes(), bytearray()
        for i in range(0, len(raw), 4):   # premultiplied ARGB, little endian (B G R A bytes)
            r, g, b, a = raw[i], raw[i + 1], raw[i + 2], raw[i + 3]
            px += bytes((b * a // 255, g * a // 255, r * a // 255, a))
        chunk = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, nominal, 1, w, h, xh, yh, delay) + bytes(px)
        chunks += chunk
        pos += len(chunk)
    return header + toc + chunks


def main():
    p = argparse.ArgumentParser(description="MONOLITH Dots cursor theme")
    p.add_argument("outdir")
    p.add_argument("--name", default="Monolith-Dots")
    p.add_argument("--sizes", default="24,28,32,48,64,96")
    p.add_argument("--preview", help="also write a PNG sheet of every cursor at 48 px")
    a = p.parse_args()
    sizes = [int(s) for s in a.sizes.split(",")]
    cdir = os.path.join(a.outdir, "cursors")
    os.makedirs(cdir, exist_ok=True)

    sheet = []
    for name, shape in SHAPES.items():
        leds = shape()
        imgs = [(s, render(s, leds), s // 2, s // 2, 0) for s in sizes]
        with open(os.path.join(cdir, name), "wb") as f:
            f.write(xcursor(imgs))
        sheet.append(render(48, leds))
    for name, (frames, ms, frame) in ANIMATED.items():
        imgs = [(s, render(s, frame(i)), s // 2, s // 2, ms) for s in sizes for i in range(frames)]
        with open(os.path.join(cdir, name), "wb") as f:
            f.write(xcursor(imgs))
        sheet.append(render(48, frame(0)))
    for target, names in ALIASES.items():
        for alias in names.split():
            link = os.path.join(cdir, alias)
            if not os.path.lexists(link):
                os.symlink(target, link)
    with open(os.path.join(a.outdir, "index.theme"), "w") as f:
        f.write(f"[Icon Theme]\nName={a.name}\nComment=MONOLITH Nothing theme: cursors drawn with LEDs\n")

    if a.preview:   # every cursor on a light and on a dark strip
        w = 48 * len(sheet) + 8 * (len(sheet) + 1)
        out = Image.new("RGBA", (w, 2 * 64), (235, 235, 235, 255))
        ImageDraw.Draw(out).rectangle((0, 64, w, 128), fill=(12, 12, 12, 255))
        for i, im in enumerate(sheet):
            for y in (8, 72):
                out.alpha_composite(im, (8 + i * 56, y))
        out.save(a.preview)


if __name__ == "__main__":
    main()
