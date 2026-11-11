#!/usr/bin/env python3
"""previews.py - regenerate the SVG previews of assets/previews/ (shown in the README) from the real programs.

    python3 tools/previews.py [--only fastfetch,cava,...] [--out DIR]

Needs fastfetch, fish, script (util-linux) and Python with Pillow and numpy (python-pillow, python-numpy).
Nothing outside a temporary directory is read or written but the repository's own files and --out: the
installers run in --dry-run mode against a throw-away home.

  fastfetch          fastfetch with the default theme (configs/.config/fastfetch)
  fastfetch-nothing  fastfetch with the Nothing theme (nix/nothing/fastfetch.jsonc, Arch LED logo)
  cava-nothing       monolith-cava, one frame drawn from a made-up spectrum
  nautilus-nothing   a Nautilus-like window with the MONOLITH Dots icons and cursor (Nothing theme)
  wallpaper-nothing  a wallpaper as it is and as an LED dot matrix (monolith-dotmatrix)
  installer          scripts/install.sh: welcome and the theme question (Arch Linux / CachyOS)
  installer-nixos    the NixOS installer's banner in the Nothing look
  logo               MONOLITH as a dot matrix (the README's title; the letters of the NixOS installer's banner)
"""
import argparse
import base64
import importlib.util
import io
import json
import math
import os
import re
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


def fastfetch(home, cfg):
    path = os.path.join(home, "preview.jsonc")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cfg, f)
    env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=os.path.join(home, ".config"))
    return subprocess.run(["fish", "--no-config", "-c", f"fastfetch --pipe false --config {path}"],
                          env=env, capture_output=True, text=True, check=True).stdout


def distro_label():
    name = "Linux"
    try:
        with open("/etc/os-release") as f:
            for l in f:
                if l.startswith("NAME="):
                    name = l.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return " ".join(re.sub(r"[^A-Z0-9 ]", "", name.upper()))


# ── previews ───────────────────────────────────────────────────────────────────────────────────────────────
def p_fastfetch(tmp, out):
    home = os.path.join(tmp, "ff")
    shutil.copytree(os.path.join(ROOT, "configs", ".config", "fastfetch"), os.path.join(home, ".config", "fastfetch"))
    cfg = fixed_terminal(jsonc(os.path.join(ROOT, "configs", ".config", "fastfetch", "config.jsonc")))
    term_svg(fastfetch(home, cfg), os.path.join(out, "fastfetch.svg"), "fastfetch")


def p_fastfetch_nothing(tmp, out):
    home = os.path.join(tmp, "ffn")
    os.makedirs(os.path.join(home, ".config", "fastfetch"))
    shutil.copy(os.path.join(NOTHING, "fastfetch-logo-arch.txt"), os.path.join(home, ".config", "fastfetch", "nothing-logo.txt"))
    raw = open(os.path.join(NOTHING, "fastfetch.jsonc"), encoding="utf-8").read().replace("N I X O S", distro_label())
    cfg = fixed_terminal(json.loads("".join(l for l in raw.splitlines(True) if not l.lstrip().startswith("//"))))
    term_svg(fastfetch(home, cfg), os.path.join(out, "fastfetch-nothing.svg"), "fastfetch · Nothing", nothing=True)


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
    term_svg("".join(buf), os.path.join(out, "cava-nothing.svg"), "monolith-cava · Nothing", nothing=True)


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
           f'aria-label="Nautilus with the MONOLITH Dots icons and cursor (Nothing theme)">'
           f'<defs>{"".join(used.values())}</defs><g font-family="{FONT}">{"".join(body)}</g></svg>')
    write(os.path.join(out, "nautilus-nothing.svg"), svg)


def p_wallpaper_nothing(tmp, out):
    from PIL import Image
    src = os.path.join(ROOT, "wallpapers", "static", "blue_sky.png")
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
    write(os.path.join(out, "wallpaper-nothing.svg"), svg)


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
    term_svg(raw, os.path.join(out, "installer.svg"), "MONOLITH · scripts/install.sh", start="█",
             until="Choose the theme")


def p_installer_nixos(tmp, out):
    raw = pty(f"MONOLITH_INSTALL_THEME=nothing bash {ROOT}/nix/install/monolith-install.sh --lang en --dry-run", "", cols=110)
    term_svg(raw, os.path.join(out, "installer-nixos.svg"), "MONOLITH · NixOS installer", nothing=True, start="●",
             until="I N S T A L L E R")


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
    "fastfetch": p_fastfetch, "fastfetch-nothing": p_fastfetch_nothing, "cava-nothing": p_cava_nothing,
    "nautilus-nothing": p_nautilus_nothing, "wallpaper-nothing": p_wallpaper_nothing,
    "installer": p_installer, "installer-nixos": p_installer_nixos, "logo": p_logo,
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
