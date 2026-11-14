#!/usr/bin/env python3
"""previews.py - regenerate the SVG previews of assets/previews/ (shown in the README) from the real programs.

    python3 tools/previews.py [--only default/fastfetch,nothing/cava,...] [--out DIR]

Needs fastfetch, fish, script (util-linux) and Python with Pillow and numpy (python-pillow, python-numpy).
Nothing outside a temporary directory is read or written but the repository's own files and --out: the
installers run in --dry-run mode against a throw-away home.

Each preview is written to <out>/<name>.svg; default/ is the default theme, nothing/ the optional Nothing theme.

  logo                    MONOLITH as a dot matrix (the README's title; the letters of the NixOS installer's banner)
  default/fastfetch       fastfetch (configs/.config/fastfetch) as on NixOS: the Nix icon, NixOS rows
  default/nautilus        Nautilus in the default theme: dark glass over the wallpaper, Monolith-Icons
  default/installer       scripts/install.sh: welcome and the theme question (Arch Linux / CachyOS)
  default/installer-nixos the NixOS installer's banner in the default look
  nothing/fastfetch       fastfetch of the Nothing theme on NixOS (nix/nothing/fastfetch.jsonc, snowflake as LEDs)
  nothing/nautilus        Nautilus in the Nothing theme: OLED black, MONOLITH Dots icons and cursor
  nothing/wallpaper       a wallpaper (assets/previews/src/night-peaks.jpg) as it is and as an LED dot matrix
  nothing/cava            monolith-cava, one frame drawn from a made-up spectrum
  nothing/installer-nixos the NixOS installer's banner in the Nothing look

The fastfetch previews show NixOS whatever machine draws them: the distribution, kernel and package rows are
fixed (NIXOS below); the rest (window manager, memory, CPU...) is read from the machine.
"""
import argparse
import base64
import importlib.util
import io
import json
import math
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from html import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NOTHING = os.path.join(ROOT, "nix", "nothing")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import ansi2svg  # noqa: E402

OLED, BAR_N = "#000000", "#0e0e0e"
FONT = "Space Mono, JetBrains Mono, DejaVu Sans Mono, Menlo, Consolas, monospace"
SANS = "Adwaita Sans, Inter, Cantarell, DejaVu Sans, Helvetica, Arial, sans-serif"
# what fastfetch prints on a NixOS of the flake's nixos-unstable (os, kernel, packages as {all} / as a list)
NIXOS = {"os": "NixOS 26.05 (Yarara)", "kernel": "6.18.12",
         "packages": ("1903", "1386 (nix-system), 517 (nix-user)")}
ARCH_ICON, NIX_ICON = "\U000f08c7", "\uf313"   # nerd-font glyphs: md-arch, linux-nixos


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def term_svg(ansi, out, title, nothing=False, start="", until="", extra=0):
    lines = ansi2svg.parse(ansi)
    text = ["".join(c[0] for c in r) for r in lines]
    lo, hi = 0, len(lines)
    if start:
        lo = next((n for n, t in enumerate(text) if start in t), 0)
    if until:
        hi = next((n + 1 + extra for n, t in enumerate(text) if n >= lo and until in t), hi)
    lines = lines[lo:hi]
    while lines and not lines[0]:
        lines.pop(0)
    while lines and not lines[-1]:
        lines.pop()
    kw = {"bg": OLED, "bar": BAR_N} if nothing else {}
    write(out, ansi2svg.to_svg(lines, title, **kw))


def write(path, svg):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(svg + "\n")
    print(f"wrote {os.path.relpath(path, ROOT)} ({os.path.getsize(path) // 1024} KiB)", file=sys.stderr)


def jsonc(path):
    """A fastfetch .jsonc without its whole-line comments (the $schema URL keeps its //)."""
    with open(path, encoding="utf-8") as f:
        return json.loads("".join(l for l in f if not l.lstrip().startswith("//")))


def fixed_terminal(cfg, name="Ghostty"):
    """The terminal row shows `name` (this runs under whatever launched it), alignment kept; the user row shows
    user@monolith, never the name and hostname of the machine that drew the preview."""
    for m in cfg["modules"]:
        if isinstance(m, dict) and m.get("type") == "command" and re.search(r"\$USER|hostname", m.get("text", "")):
            m["text"] = "echo user@monolith"
        if isinstance(m, dict) and m.get("type") == "terminal":
            m["format"] = re.sub(r"\{pretty-name(?:>(\d+))?\}",
                                 lambda g: name.rjust(int(g.group(1) or 0)), m.get("format", "{pretty-name}"))
    return cfg


def as_nixos(cfg):
    """The distribution, kernel and package rows as NixOS prints them (fixed text), the Nix icon instead of
    Arch's (home.nix swaps it the same way in the config it links on NixOS)."""
    for n, m in enumerate(cfg["modules"]):
        if not isinstance(m, dict):
            continue
        if "key" in m:
            m["key"] = m["key"].replace(ARCH_ICON, NIX_ICON)
        t, fmt = m.get("type"), m.get("format", "")
        if t not in ("os", "kernel", "packages"):
            continue
        text = NIXOS[t] if t != "packages" else NIXOS[t][0 if "{all" in fmt else 1]
        new = {"type": "command", "key": m.get("key", t.upper()), "text": "printf %s " + shlex.quote(text)}
        if fmt:
            new["format"] = re.sub(r"\{(?:pretty-name|release|all)", "{", fmt)
        cfg["modules"][n] = new
    return cfg


def fastfetch(home, cfg):
    path = os.path.join(home, "preview.jsonc")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cfg, f)
    env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=os.path.join(home, ".config"))
    return subprocess.run(["fish", "--no-config", "-c", f"fastfetch --pipe false --config {path}"],
                          env=env, capture_output=True, text=True, check=True).stdout


# ── previews ───────────────────────────────────────────────────────────────────────────────────────────────
def p_fastfetch(tmp, out):
    home = os.path.join(tmp, "ff")
    shutil.copytree(os.path.join(ROOT, "configs", ".config", "fastfetch"), os.path.join(home, ".config", "fastfetch"))
    cfg = as_nixos(fixed_terminal(jsonc(os.path.join(ROOT, "configs", ".config", "fastfetch", "config.jsonc"))))
    term_svg(fastfetch(home, cfg), os.path.join(out, "default", "fastfetch.svg"), "fastfetch · NixOS")


def p_fastfetch_nothing(tmp, out):
    home = os.path.join(tmp, "ffn")
    os.makedirs(os.path.join(home, ".config", "fastfetch"))
    shutil.copy(os.path.join(NOTHING, "fastfetch-logo.txt"), os.path.join(home, ".config", "fastfetch", "nothing-logo.txt"))
    cfg = as_nixos(fixed_terminal(jsonc(os.path.join(NOTHING, "fastfetch.jsonc"))))
    term_svg(fastfetch(home, cfg), os.path.join(out, "nothing", "fastfetch.svg"), "fastfetch · Nothing · NixOS", nothing=True)


def p_cava_nothing(tmp, out):
    cava = load("cava_dots", os.path.join(NOTHING, "cava-dots.py"))
    bars, rows = 44, 14
    vals, peaks = [], []
    for i in range(bars):   # bass on the left, a few bumps, falling off towards the treble
        v = rows * (0.78 * math.exp(-i / 13) + 0.22 * abs(math.sin(i * 0.55)) * math.exp(-i / 30) + 0.06)
        vals.append(max(0, min(rows, int(v + 0.5))))
        peaks.append(min(rows, vals[-1] + (2 if i % 3 == 0 else 1)))
    buf = []
    for row in range(rows, 0, -1):     # the same drawing as monolith-cava's loop
        cur = ""
        for i, v in enumerate(vals):
            if row <= v:
                col, ch = cava.LIT[min(len(cava.LIT) - 1, (row - 1) * len(cava.LIT) // rows)], cava.DOT
            elif row == peaks[i] and peaks[i] > v:
                col, ch = cava.PEAK, cava.DOT
            else:
                col, ch = cava.OFF, cava.OFF_DOT
            if col != cur:
                buf.append(col)
                cur = col
            buf.append(ch + " ")
        buf.append("\x1b[0m\n")
    term_svg("".join(buf), os.path.join(out, "nothing", "cava.svg"), "monolith-cava · Nothing", nothing=True)


def icon_symbols(icons):
    """icon(name) -> the id of a <symbol> holding that icon of the theme drawn in `icons`; symbols() -> the defs."""
    used = {}

    def icon(name):
        if name not in used:
            path = next(os.path.join(icons, "scalable", d, name + ".svg") for d in ("places", "mimetypes", "devices")
                        if os.path.exists(os.path.join(icons, "scalable", d, name + ".svg")))
            inner = re.sub(r"^<svg[^>]*>|</svg>\s*$", "", open(path).read().strip())
            used[name] = f'<symbol id="{name}" viewBox="0 0 64 64">{inner}</symbol>'
        return name
    return icon, lambda: "".join(used.values())


def jpeg_b64(path, w, h, quality=80):
    """`path` cover-cropped to w x h, as base64 JPEG."""
    from PIL import Image
    im = Image.open(path).convert("RGB")
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    l, t = (im.width - w) // 2, (im.height - h) // 2
    buf = io.BytesIO()
    im.crop((l, t, l + w, t + h)).save(buf, "JPEG", quality=quality, optimize=True, progressive=True)
    return base64.b64encode(buf.getvalue()).decode()


def p_nautilus(tmp, out):
    """Nautilus in the default theme (configs/.config/gtk-4.0/gtk.css): the window is transparent, the sidebar
    black at 55 %, the content #111111 at 45 %, no blur (the wallpaper behind it is sharp), Monolith-Icons."""
    icons = os.path.join(tmp, "monolith-icons")
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "branding", "icons.py"), icons], check=True, capture_output=True)
    icon, symbols = icon_symbols(icons)

    CW, CH = 1000, 600                    # the screen: wallpaper, the window floating on it
    X, Y, W, H, SIDE = 90, 56, 820, 488, 200
    wall = jpeg_b64(os.path.join(ROOT, "wallpapers", "static", "blue_sky.png"), CW, CH, 78)
    side = [("user-home", "Home", True), ("folder-documents", "Documents", False),
            ("folder-download", "Downloads", False), ("folder-music", "Music", False),
            ("folder-pictures", "Pictures", False), ("folder-videos", "Videos", False),
            ("user-trash", "Trash", False)]
    devices = [("drive-harddisk", "System"), ("drive-removable-media", "USB stick")]
    grid = [("folder-desktop", "Desktop"), ("folder-documents", "Documents"), ("folder-download", "Downloads"),
            ("folder-music", "Music"), ("folder-pictures", "Pictures"), ("folder-videos", "Videos"),
            ("folder-templates", "Templates"), ("folder-publicshare", "Public"), ("folder", "Projects"),
            ("text-x-generic", "notes.txt"), ("image-x-generic", "sky.png"), ("audio-x-generic", "song.flac"),
            ("application-pdf", "report.pdf"), ("text-x-script", "build.sh"), ("package-x-generic", "dots.zip")]
    b = [f'<rect x="{X}" y="{Y}" width="{SIDE}" height="{H}" fill="#000000" fill-opacity="0.55"/>',
         f'<rect x="{X + SIDE}" y="{Y}" width="{W - SIDE}" height="{H}" fill="#111111" fill-opacity="0.45"/>',
         f'<line x1="{X + SIDE}" y1="{Y}" x2="{X + SIDE}" y2="{Y + H}" stroke="#ffffff" stroke-opacity="0.06"/>']
    # header: title and buttons of the sidebar, the path pill, the view buttons and close
    b.append(f'<text x="{X + SIDE / 2}" y="{Y + 30}" text-anchor="middle" fill="#eeeeee" font-size="13" font-weight="bold">Files</text>')
    px = X + SIDE + 70
    b.append(f'<rect x="{px}" y="{Y + 11}" width="380" height="30" rx="15" fill="#ffffff" fill-opacity="0.06"/>'
             f'<text x="{px + 18}" y="{Y + 31}" fill="#ffffff" font-size="13" font-weight="bold">Home</text>'
             f'<circle cx="{px + 362}" cy="{Y + 21}" r="1.4" fill="#cccccc"/><circle cx="{px + 362}" cy="{Y + 26}" r="1.4" fill="#cccccc"/>'
             f'<circle cx="{px + 362}" cy="{Y + 31}" r="1.4" fill="#cccccc"/>')
    for k, ch in enumerate("‹›"):
        b.append(f'<text x="{X + SIDE + 22 + k * 24}" y="{Y + 32}" text-anchor="middle" fill="{"#888888" if k else "#cccccc"}" font-size="20">{ch}</text>')
    b.append(f'<circle cx="{X + W - 24}" cy="{Y + 26}" r="11" fill="#ffffff" fill-opacity="0.1"/>'
             f'<path d="M{X + W - 28} {Y + 22}l8 8m0 -8l-8 8" stroke="#eeeeee" stroke-width="1.6" stroke-linecap="round"/>')
    for k in range(3):   # list / grid / sort, as three small bars
        b.append(f'<rect x="{X + W - 86 + k * 0}" y="{Y + 19 + k * 5}" width="14" height="2" rx="1" fill="#cccccc"/>')
    y = Y + 62
    for ic, label, cur in side:
        if cur:
            b.append(f'<rect x="{X + 8}" y="{y - 7}" width="{SIDE - 16}" height="32" rx="6" fill="#ffffff" fill-opacity="0.12"/>')
        b.append(f'<use href="#{icon(ic)}" x="{X + 18}" y="{y - 1}" width="20" height="20"/>'
                 f'<text x="{X + 48}" y="{y + 14}" fill="{"#ffffff" if cur else "#cccccc"}" font-size="13">{escape(label)}</text>')
        y += 36
    b.append(f'<line x1="{X + 14}" y1="{y - 6}" x2="{X + SIDE - 14}" y2="{y - 6}" stroke="#ffffff" stroke-opacity="0.08"/>')
    y += 8
    for ic, label in devices:
        b.append(f'<use href="#{icon(ic)}" x="{X + 18}" y="{y - 1}" width="20" height="20"/>'
                 f'<text x="{X + 48}" y="{y + 14}" fill="#cccccc" font-size="13">{escape(label)}</text>')
        y += 36
    cols, cw, chh = 5, 118, 126
    for n, (ic, label) in enumerate(grid):
        gx = X + SIDE + 22 + (n % cols) * cw
        gy = Y + 70 + (n // cols) * chh
        if n in (2, 10):   # selected: white at 14 %; hovered: 6 %
            b.append(f'<rect x="{gx + 4}" y="{gy - 8}" width="{cw - 12}" height="{chh - 18}" rx="10" fill="#ffffff" '
                     f'fill-opacity="{0.14 if n == 2 else 0.06}"/>')
        b.append(f'<use href="#{icon(ic)}" x="{gx + 23}" y="{gy}" width="64" height="64"/>'
                 f'<text x="{gx + 55}" y="{gy + 86}" text-anchor="middle" fill="{"#ffffff" if n == 2 else "#eeeeee"}" font-size="12">{escape(label)}</text>')
    b.append(f'<rect x="{X + W - 210}" y="{Y + H - 40}" width="196" height="28" rx="8" fill="#000000" fill-opacity="0.75" stroke="#ffffff" stroke-opacity="0.08"/>'
             f'<text x="{X + W - 112}" y="{Y + H - 21}" text-anchor="middle" fill="#cccccc" font-size="12">“Downloads” selected</text>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{CW}" height="{CH}" viewBox="0 0 {CW} {CH}" role="img" '
           f'aria-label="Nautilus in the default theme: dark glass over the wallpaper, Monolith-Icons">'
           f'<defs>{symbols()}<clipPath id="screen"><rect width="{CW}" height="{CH}" rx="20"/></clipPath>'
           f'<clipPath id="win"><rect x="{X}" y="{Y}" width="{W}" height="{H}" rx="14"/></clipPath>'
           f'<filter id="sh" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="10" stdDeviation="14" flood-opacity="0.45"/></filter></defs>'
           f'<g clip-path="url(#screen)"><image width="{CW}" height="{CH}" href="data:image/jpeg;base64,{wall}"/>'
           f'<rect x="{X}" y="{Y}" width="{W}" height="{H}" rx="14" fill="#000000" fill-opacity="0.01" filter="url(#sh)"/>'
           f'<g clip-path="url(#win)" font-family="{SANS}">{"".join(b)}</g>'
           f'<rect x="{X + 0.5}" y="{Y + 0.5}" width="{W - 1}" height="{H - 1}" rx="14" fill="none" stroke="#ffffff" stroke-opacity="0.18"/></g></svg>')
    write(os.path.join(out, "default", "nautilus.svg"), svg)


def p_nautilus_nothing(tmp, out):
    icons = os.path.join(tmp, "icons")
    subprocess.run([sys.executable, "-I", os.path.join(NOTHING, "icons.py"), icons], check=True, capture_output=True)
    cursor = load("cursor", os.path.join(NOTHING, "cursor.py"))
    buf = io.BytesIO()
    cursor.render(48, cursor.SHAPES["pointer"]()).save(buf, "PNG", optimize=True)
    pointer = base64.b64encode(buf.getvalue()).decode()

    used = {}

    def icon(name):
        if name not in used:
            path = next(os.path.join(icons, "scalable", d, name + ".svg") for d in ("places", "mimetypes", "devices")
                        if os.path.exists(os.path.join(icons, "scalable", d, name + ".svg")))
            inner = re.sub(r"^<svg[^>]*>|</svg>\s*$", "", open(path).read().strip())
            used[name] = f'<symbol id="{name}" viewBox="0 0 64 64">{inner}</symbol>'
        return name

    W, H, SIDE, TOP = 820, 470, 196, 52
    side = [("user-home", "Home"), ("folder-desktop", "Desktop"), ("folder-documents", "Documents"),
            ("folder-download", "Downloads"), ("folder-music", "Music"), ("folder-pictures", "Pictures"),
            ("folder-videos", "Videos"), ("user-trash", "Trash"), ("drive-harddisk", "System")]
    grid = [("folder-desktop", "Desktop"), ("folder-documents", "Documents"), ("folder-download", "Downloads"),
            ("folder-music", "Music"), ("folder-pictures", "Pictures"), ("folder-videos", "Videos"),
            ("folder-templates", "Templates"), ("folder-publicshare", "Public"), ("folder", "Projects"),
            ("text-x-generic", "notes.txt"), ("image-x-generic", "sky.png"), ("audio-x-generic", "song.flac"),
            ("application-pdf", "report.pdf"), ("text-x-script", "build.sh"), ("package-x-generic", "dots.zip")]
    body = [f'<rect width="{W}" height="{H}" rx="20" fill="{OLED}" stroke="#2a2a2a"/>',
            f'<rect x="1" y="1" width="{SIDE}" height="{H - 2}" rx="19" fill="#0e0e0e"/>',
            f'<rect x="{SIDE - 20}" y="1" width="20" height="{H - 2}" fill="#0e0e0e"/>',
            f'<line x1="{SIDE}" y1="1" x2="{SIDE}" y2="{H - 1}" stroke="#2a2a2a"/>']
    # header: path pill with a breathing LED, window controls as LEDs
    body.append(f'<rect x="{SIDE + 150}" y="12" width="300" height="28" rx="14" fill="#0e0e0e" stroke="#2a2a2a"/>'
                f'<circle cx="{SIDE + 168}" cy="26" r="3.2" fill="#f2f2f2"/>'
                f'<text x="{SIDE + 182}" y="31" fill="#a3a3a3" font-size="12" letter-spacing="1.5">HOME</text>')
    for k in range(3):
        body.append(f'<circle cx="{W - 26 - k * 18}" cy="26" r="4" fill="{"#f2f2f2" if k == 0 else "#333333"}"/>')
    body.append(f'<text x="22" y="32" fill="#7a7a7a" font-size="11" letter-spacing="2">PLACES</text>')
    for n, (ic, label) in enumerate(side):
        y = TOP + 6 + n * 38
        if n == 0:   # the current place: outlined row, lit LED
            body.append(f'<rect x="10" y="{y - 4}" width="{SIDE - 20}" height="32" rx="16" fill="none" stroke="#7a7a7a"/>'
                        f'<circle cx="{SIDE - 26}" cy="{y + 12}" r="3" fill="#f2f2f2"/>')
        body.append(f'<use href="#{icon(ic)}" x="20" y="{y}" width="24" height="24"/>'
                    f'<text x="54" y="{y + 16}" fill="{"#f2f2f2" if n == 0 else "#a3a3a3"}" font-size="13">{escape(label)}</text>')
    cols, cw, ch = 5, 116, 118
    for n, (ic, label) in enumerate(grid):
        x = SIDE + 26 + (n % cols) * cw
        y = TOP + 22 + (n // cols) * ch
        if n == 3:   # hovered item: outlined
            body.append(f'<rect x="{x + 4}" y="{y - 8}" width="{cw - 16}" height="{ch - 14}" rx="14" fill="none" stroke="#f2f2f2" stroke-opacity="0.5"/>')
        body.append(f'<use href="#{icon(ic)}" x="{x + 20}" y="{y}" width="64" height="64"/>'
                    f'<text x="{x + 52}" y="{y + 86}" text-anchor="middle" fill="#d4d4d4" font-size="12">{escape(label)}</text>')
    cx, cy = SIDE + 26 + 3 * cw + 64, TOP + 22 + 40
    body.append(f'<image x="{cx - 24}" y="{cy - 24}" width="48" height="48" href="data:image/png;base64,{pointer}"/>')
    body.append(f'<text x="{W - 20}" y="{H - 16}" text-anchor="end" fill="#333333" font-size="11" letter-spacing="2">15 ITEMS</text>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" '
           f'aria-label="Nautilus in the Nothing theme: OLED black, with the MONOLITH Dots icons and cursor">'
           f'<defs>{"".join(used.values())}</defs><g font-family="{FONT}">{"".join(body)}</g></svg>')
    write(os.path.join(out, "nothing", "nautilus.svg"), svg)


def p_wallpaper_nothing(tmp, out):
    from PIL import Image
    src = os.path.join(ROOT, "assets", "previews", "src", "night-peaks.jpg")
    dots = os.path.join(tmp, "dots.png")
    subprocess.run([sys.executable, "-I", os.path.join(NOTHING, "dotmatrix.py"), src, "-o", dots,
                    "--resolution", "480x270", "--size", "3", "--spacing", "1",
                    "--contrast", "1.3", "--brightness", "1.2"], check=True, capture_output=True)

    def b64(im, fmt, **kw):
        b = io.BytesIO()
        im.save(b, fmt, **kw)
        return base64.b64encode(b.getvalue()).decode()

    orig = Image.open(src).convert("RGB")
    s = max(480 / orig.width, 270 / orig.height)   # cover-crop, as the renderer does
    orig = orig.resize((round(orig.width * s), round(orig.height * s)), Image.LANCZOS)
    l, t = (orig.width - 480) // 2, (orig.height - 270) // 2
    orig = orig.crop((l, t, l + 480, t + 270))
    a, b = b64(orig, "JPEG", quality=80), b64(Image.open(dots).convert("L"), "PNG", optimize=True)
    W, H = 1000, 330
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{W}" height="{H}" '
           f'viewBox="0 0 {W} {H}" role="img" aria-label="A wallpaper as it is and as an LED dot matrix">'
           f'<rect width="{W}" height="{H}" rx="20" fill="{OLED}"/>'
           f'<defs><clipPath id="a"><rect x="14" y="14" width="480" height="270" rx="12"/></clipPath>'
           f'<clipPath id="b"><rect x="506" y="14" width="480" height="270" rx="12"/></clipPath></defs>'
           f'<image x="14" y="14" width="480" height="270" clip-path="url(#a)" href="data:image/jpeg;base64,{a}"/>'
           f'<image x="506" y="14" width="480" height="270" clip-path="url(#b)" href="data:image/png;base64,{b}"/>'
           f'<g font-family="{FONT}" font-size="12" letter-spacing="2" fill="#7a7a7a">'
           f'<text x="254" y="312" text-anchor="middle">ORIGINAL</text>'
           f'<circle cx="668" cy="308" r="3.2" fill="#f2f2f2"/><text x="680" y="312">LED MATRIX · CONTRAST 130 %</text></g></svg>')
    write(os.path.join(out, "nothing", "wallpaper.svg"), svg)


def pty(cmd, answers, cols=100):
    """Run `cmd` in a pseudo-terminal of `cols` columns, typing `answers`; returns what it printed."""
    log = tempfile.mktemp(suffix=".typescript")
    try:
        subprocess.run(["script", "-qec", f"stty cols {cols} rows 50; {cmd}", log], input=answers, text=True,
                       capture_output=True, timeout=300)
        return open(log, encoding="utf-8", errors="replace").read()
    finally:
        if os.path.exists(log):
            os.unlink(log)


def p_installer(tmp, out):
    home = os.path.join(tmp, "home")
    os.makedirs(home, exist_ok=True)
    raw = pty(f"MONOLITH_TARGET_HOME={home} LANG=en_US.UTF-8 bash {ROOT}/scripts/install.sh --lang en --no-deps "
              "--dry-run --no-clear", "y\n2\n")
    term_svg(raw, os.path.join(out, "default", "installer.svg"), "MONOLITH · scripts/install.sh", start="█",
             until="Choose the theme")


def p_installer_nixos(tmp, out):
    raw = pty(f"MONOLITH_INSTALL_THEME=monolith bash {ROOT}/nix/install/monolith-install.sh --lang en --dry-run", "", cols=110)
    term_svg(raw, os.path.join(out, "default", "installer-nixos.svg"), "MONOLITH · NixOS installer", start="█",
             until="installer", extra=1)


def p_installer_nixos_nothing(tmp, out):
    raw = pty(f"MONOLITH_INSTALL_THEME=nothing bash {ROOT}/nix/install/monolith-install.sh --lang en --dry-run", "", cols=110)
    term_svg(raw, os.path.join(out, "nothing", "installer-nixos.svg"), "MONOLITH · NixOS installer · Nothing",
             nothing=True, start="●", until="I N S T A L L E R")


def p_logo(tmp, out):
    font = {"M": "●···● ●●·●● ●·●·● ●···● ●···●", "O": "·●●●· ●···● ●···● ●···● ·●●●·",
            "N": "●···● ●●··● ●·●·● ●··●● ●···●", "L": "●···· ●···· ●···· ●···· ●●●●●",
            "I": "●●● ·●· ·●· ·●· ●●●", "T": "●●●●● ··●·· ··●·· ··●·· ··●··", "H": "●···● ●···● ●●●●● ●···● ●···●"}
    pitch, r_on, r_off, pad = 14, 5, 2, 34
    dots, x0 = [], pad
    for ch in "MONOLITH":
        rows = font[ch].split()
        for ri, row in enumerate(rows):
            for ci, c in enumerate(row):
                cx, cy = x0 + ci * pitch + pitch / 2, pad + ri * pitch + pitch / 2
                dots.append(f'<circle cx="{cx:g}" cy="{cy:g}" r="{r_on if c == "●" else r_off}" fill="{"#f2f2f2" if c == "●" else "#333333"}"/>')
        x0 += (len(rows[0]) + 1) * pitch
    w, h = int(x0 - pitch + pad), 5 * pitch + 2 * pad
    write(os.path.join(out, "logo.svg"),
          f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-label="MONOLITH">'
          f'<rect width="{w}" height="{h}" rx="22" fill="{OLED}"/>{"".join(dots)}</svg>')


PREVIEWS = {
    "logo": p_logo,
    "default/fastfetch": p_fastfetch, "default/nautilus": p_nautilus, "default/installer": p_installer,
    "default/installer-nixos": p_installer_nixos,
    "nothing/fastfetch": p_fastfetch_nothing, "nothing/nautilus": p_nautilus_nothing,
    "nothing/wallpaper": p_wallpaper_nothing, "nothing/cava": p_cava_nothing,
    "nothing/installer-nixos": p_installer_nixos_nothing,
}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default="", help="comma-separated names (default: all)")
    ap.add_argument("--out", default=os.path.join(ROOT, "assets", "previews"))
    a = ap.parse_args()
    names = [n for n in a.only.split(",") if n] or list(PREVIEWS)
    bad = [n for n in names if n not in PREVIEWS]
    if bad:
        ap.error("unknown: " + ", ".join(bad))
    os.makedirs(a.out, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for n in names:
            PREVIEWS[n](tmp, a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
