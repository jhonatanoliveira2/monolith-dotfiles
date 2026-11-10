#!/usr/bin/env python3
# MONOLITH Dots Icons: the icon theme of the Nothing theme (Nautilus and every GTK app). Folders, files,
# places and devices drawn as a 16 x 16 matrix of LEDs: lit outline and emblem, dimmed fill, monochrome.
# Everything else (symbolic UI icons, app icons) is inherited from Adwaita / hicolor.
#
#   icons.py OUTDIR [--name Monolith-Dots-Icons] [--preview sheet.svg]
#
# Pure Python (no dependencies): writes OUTDIR/index.theme and scalable SVGs in places/, mimetypes/, devices/.

import argparse
import math
import os

LIT, DIM = "#f2f2f2", "#5c5c5c"
N = 16                                      # LEDs per side

# ── 7 x 7 emblems ('#' = lit) ──
EMBLEMS = {
    "download": ["...#...", "...#...", ".#.#.#.", "..###..", "...#...", ".......", "#######"],
    "music": ["..#####", "..#...#", "..#...#", "..#...#", "###.###", "###.###", "......."],
    "picture": [".....##", ".....##", "..#....", ".###.#.", "#######", "#######", "......."],
    "video": [".#.....", ".##....", ".###...", ".####..", ".###...", ".##....", ".#....."],
    "documents": ["#######", ".......", "#######", ".......", "#######", ".......", "####..."],
    "desktop": ["#######", "#.....#", "#.....#", "#######", "...#...", "..###..", "......."],
    "home": ["...#...", "..###..", ".#####.", "#######", ".#...#.", ".#.#.#.", ".#.#.#."],
    "templates": ["#.#.#.#", ".......", "#.....#", ".......", "#.....#", ".......", "#.#.#.#"],
    "public": ["..###..", "..###..", "...#...", ".#####.", "#..#..#", "..#.#..", ".#...#."],
    "globe": ["..###..", ".#.#.#.", "#..#..#", "#######", "#..#..#", ".#.#.#.", "..###.."],
    "text": ["#####..", ".......", "######.", ".......", "####...", ".......", "#####.."],
    "archive": ["...#...", "..#....", "...#...", "..#....", "...#...", "..###..", "..###.."],
    "exec": [".......", "#......", ".#.....", "..#....", ".#.....", "#..####", "......."],
    "code": ["..#.#..", ".#...#.", "#.....#", ".#...#.", "..#.#..", ".......", "......."],
    "pdf": ["####...", "#...#..", "#...#..", "####...", "#......", "#......", "#......"],
    "sheet": ["#######", "#..#..#", "#######", "#..#..#", "#######", "#..#..#", "#######"],
    "slides": [".....#.", ".....#.", "...#.#.", "...#.#.", ".#.#.#.", ".#.#.#.", "#######"],
    "font": ["...#...", "..#.#..", ".#...#.", ".#####.", "#.....#", "#.....#", "#.....#"],
}


def grid():
    return [[0] * N for _ in range(N)]     # 0 off, 1 dim, 2 lit


def stamp(g, emblem, top, left):
    for r, row in enumerate(EMBLEMS[emblem]):
        for c, ch in enumerate(row):
            g[top + r][left + c] = 2 if ch == "#" else 0


def folder(emblem=None):
    g = grid()
    for c in range(1, 6):
        g[2][c] = 2                         # tab
    g[3][6] = 2
    for c in range(6, 15):
        g[4][c] = 2                         # body top
    for r in range(2, 15):
        g[r][1] = 2                         # left
    for r in range(4, 15):
        g[r][14] = 2                        # right
    for c in range(1, 15):
        g[14][c] = 2                        # bottom
    for r in range(5, 14):
        for c in range(2, 14):
            g[r][c] = 1
    for c in range(2, 6):
        g[3][c] = 1
    if emblem:
        stamp(g, emblem, 6, 4)
    return g


def page(emblem=None):
    g = grid()
    for c in range(3, 10):
        g[1][c] = 2                         # top
    g[2][10], g[3][11], g[4][12] = 2, 2, 2  # folded corner
    g[2][9], g[3][9], g[4][9], g[4][10], g[4][11] = 1, 1, 2, 2, 2
    for r in range(1, 15):
        g[r][3] = 2                         # left
    for r in range(4, 15):
        g[r][12] = 2                        # right
    for c in range(3, 13):
        g[14][c] = 2                        # bottom
    for r in range(2, 14):
        for c in range(4, 12):
            if g[r][c] == 0 and not (r < 4 and c >= 9):
                g[r][c] = 1
    if emblem:
        stamp(g, emblem, 6, 4)
    return g


def from_rows(rows, fill=True):
    """16 rows of 16 chars: '#' lit, '+' dim; with fill, the inside of each row's lit span is dimmed."""
    g = grid()
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            g[r][c] = 2 if ch == "#" else 1 if ch == "+" else 0
    return g


def trash(full=False):
    rows = ["................", "......####......", "..############..", "................",
            "...##########...", ] + ["...#+#++#++#+#..."[:16]] * 9 + ["...##########...", "................"]
    g = from_rows(rows)
    if full:   # papers over the rim
        for r, c in [(0, 4), (1, 3), (0, 9), (1, 10), (1, 11), (0, 12), (3, 6), (3, 7), (3, 9)]:
            g[r][c] = 2
    return g


def computer():
    rows = [".##############."] + [".#++++++++++++#."] * 9 + [".##############.",
            "......####......", "....########....", "................", "................", "................"]
    return from_rows(["................"] + rows[:15])


def harddisk():
    rows = ["................"] * 4 + [".##############.", ".#++++++++++++#.", ".#++++++++++++#.",
            ".#++++++++++#+#.", ".#++++++++++++#.", ".##############."] + ["................"] * 6
    return from_rows(rows)


def removable():
    rows = ["................", ".....######.....", ".....#+##+#.....", ".....######.....",
            "...##########...", ] + ["...#++++++++#..."] * 8 + ["...##########...", "................", "................"]
    return from_rows(rows)


def optical():
    g = grid()
    for r in range(N):
        for c in range(N):
            d = math.hypot(r - 7.5, c - 7.5)
            if 6.1 <= d < 7.2 or 1.2 <= d < 2.3:
                g[r][c] = 2
            elif 2.3 <= d < 6.1:
                g[r][c] = 1
    return g


def svg(g):
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">']
    for r in range(N):
        for c in range(N):
            if g[r][c]:
                out.append(f'<circle cx="{4 * c + 2}" cy="{4 * r + 2}" r="{1.55 if g[r][c] == 2 else 1.25}" '
                           f'fill="{LIT if g[r][c] == 2 else DIM}"/>')
    out.append("</svg>")
    return "\n".join(out) + "\n"


ICONS = {   # context -> {icon name(s): grid}
    "places": {
        "folder folder-open folder-drag-accept": folder(),
        "folder-documents": folder("documents"),
        "folder-download": folder("download"),
        "folder-music": folder("music"),
        "folder-pictures": folder("picture"),
        "folder-videos": folder("video"),
        "folder-desktop user-desktop": folder("desktop"),
        "user-home folder-home": folder("home"),
        "folder-templates": folder("templates"),
        "folder-publicshare": folder("public"),
        "folder-remote network-workgroup network-server": folder("globe"),
        "user-trash": trash(),
        "user-trash-full": trash(True),
    },
    "mimetypes": {
        "inode-directory": folder(),
        "text-x-generic text-plain application-x-generic unknown": page("text"),
        "text-x-script text-x-python text-x-csrc text-x-c++src text-x-java text-x-makefile application-json "
        "application-javascript text-x-sql application-x-shellscript text-x-nix": page("code"),
        "application-x-executable application-x-sharedlib application-x-desktop": page("exec"),
        "image-x-generic": page("picture"),
        "audio-x-generic": page("music"),
        "video-x-generic": page("video"),
        "application-pdf": page("pdf"),
        "package-x-generic application-x-archive application-zip application-x-compressed-tar "
        "application-x-7z-compressed application-x-rar": page("archive"),
        "font-x-generic": page("font"),
        "text-html": page("globe"),
        "x-office-document": page("documents"),
        "x-office-spreadsheet": page("sheet"),
        "x-office-presentation": page("slides"),
        "application-x-cd-image": optical(),
    },
    "devices": {
        "computer": computer(),
        "drive-harddisk drive-harddisk-system": harddisk(),
        "drive-removable-media drive-removable-media-usb media-removable": removable(),
        "media-optical drive-optical": optical(),
    },
}


def main():
    p = argparse.ArgumentParser(description="MONOLITH Dots icon theme")
    p.add_argument("outdir")
    p.add_argument("--name", default="Monolith-Dots-Icons")
    p.add_argument("--preview", help="also write one SVG with every icon")
    a = p.parse_args()
    seen = []
    for ctx, icons in ICONS.items():
        d = os.path.join(a.outdir, "scalable", ctx)
        os.makedirs(d, exist_ok=True)
        for names, g in icons.items():
            first, *rest = names.split()
            with open(os.path.join(d, first + ".svg"), "w") as f:
                f.write(svg(g))
            for alias in rest:
                link = os.path.join(d, alias + ".svg")
                if not os.path.lexists(link):
                    os.symlink(first + ".svg", link)
            seen.append(g)
    with open(os.path.join(a.outdir, "index.theme"), "w") as f:
        f.write(f"""[Icon Theme]
Name={a.name}
Comment=MONOLITH Nothing theme: folders, files and devices drawn with LEDs
Inherits=Adwaita,hicolor
Directories=scalable/places,scalable/mimetypes,scalable/devices

[scalable/places]
Context=Places
Size=64
MinSize=8
MaxSize=512
Type=Scalable

[scalable/mimetypes]
Context=MimeTypes
Size=64
MinSize=8
MaxSize=512
Type=Scalable

[scalable/devices]
Context=Devices
Size=64
MinSize=8
MaxSize=512
Type=Scalable
""")
    if a.preview:   # every icon in a row of 8, on a dark background
        cols, cell = 8, 72
        rows = (len(seen) + cols - 1) // cols
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{cols * cell}" height="{rows * cell}">',
               f'<rect width="100%" height="100%" fill="#151515"/>']
        for i, g in enumerate(seen):
            x, y = (i % cols) * cell + 4, (i // cols) * cell + 4
            out.append(f'<g transform="translate({x},{y})">' + svg(g).split("\n", 1)[1].rsplit("</svg>", 1)[0] + "</g>")
        out.append("</svg>")
        with open(a.preview, "w") as f:
            f.write("\n".join(out))


if __name__ == "__main__":
    main()
