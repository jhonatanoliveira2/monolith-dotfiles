#!/usr/bin/env python3
"""ansi2svg.py - turn a terminal capture (ANSI escapes) into a standalone SVG.

Maintainer tool used to generate assets/previews/*.svg from a real installer run:

    script -qec "stty cols 100; ./scripts/install.sh --dry-run" /tmp/run.typescript
    python3 tools/ansi2svg.py /tmp/run.typescript assets/previews/installer.svg \
        --title "MONOLITH installer" [--from "M O N O"] [--lines 60]

Only the subset of ANSI used by the installer is interpreted: SGR colours (16, 256), bold, dim,
carriage return and "erase to end of line". Everything else is ignored.
"""
import argparse
import re
import sys
from html import escape

BG = "#14161a"      # graphite
FG = "#d0d3d8"
BAR = "#1d2025"


def xterm256(n: int) -> str:
    basic = ["#000000", "#cd3131", "#0dbc79", "#e5e510", "#2472c8", "#bc3fbc", "#11a8cd", "#e5e5e5",
             "#666666", "#f14c4c", "#23d18b", "#f5f543", "#3b8eea", "#d670d6", "#29b8db", "#ffffff"]
    if n < 16:
        return basic[n]
    if n < 232:
        n -= 16
        r, g, b = n // 36, (n // 6) % 6, n % 6
        lv = [0, 95, 135, 175, 215, 255]
        return "#%02x%02x%02x" % (lv[r], lv[g], lv[b])
    v = 8 + (n - 232) * 10
    return "#%02x%02x%02x" % (v, v, v)


SGR_BASIC = {30: 0, 31: 1, 32: 2, 33: 3, 34: 4, 35: 5, 36: 6, 37: 7, 90: 8, 91: 9, 92: 10, 93: 11, 94: 12, 95: 13, 96: 14, 97: 15}


def parse(raw: str):
    lines = [[]]
    row = lines[0]
    col = 0
    fg, bold, dim = None, False, False
    i = 0
    while i < len(raw):
        ch = raw[i]
        if ch == "\x1b" and raw.startswith("[", i + 1):
            m = re.match(r"\x1b\[([0-9;?]*)([A-Za-z])", raw[i:])
            if not m:
                i += 1
                continue
            params, cmd = m.group(1), m.group(2)
            i += m.end()
            if cmd == "m":
                codes = [int(c) if c else 0 for c in params.split(";")] if params else [0]
                k = 0
                while k < len(codes):
                    c = codes[k]
                    if c == 0:
                        fg, bold, dim = None, False, False
                    elif c == 1:
                        bold = True
                    elif c == 2:
                        dim = True
                    elif c == 38 and k + 2 < len(codes) and codes[k + 1] == 5:
                        fg = xterm256(codes[k + 2])
                        k += 2
                    elif c in SGR_BASIC:
                        fg = xterm256(SGR_BASIC[c])
                    elif c == 39:
                        fg = None
                    k += 1
            elif cmd == "K":
                del row[col:]
            continue
        if ch == "\r":
            col = 0
        elif ch == "\n":
            row = []
            lines.append(row)
            col = 0
        elif ch >= " ":
            cell = (ch, fg, bold, dim)
            if col < len(row):
                row[col] = cell
            else:
                row.append(cell)
            col += 1
        i += 1
    return lines


def to_svg(lines, title: str, font_px: int = 14) -> str:
    cw = font_px * 0.602            # monospace advance
    lh = int(font_px * 1.25)
    width_cols = max((len(r) for r in lines), default=1)
    pad_x, top = 22, 46
    w = int(width_cols * cw + pad_x * 2)
    h = top + len(lines) * lh + 22
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-label="{escape(title)}">',
           f'<rect width="{w}" height="{h}" rx="8" fill="{BG}"/>',
           f'<rect width="{w}" height="30" rx="8" fill="{BAR}"/><rect y="20" width="{w}" height="10" fill="{BAR}"/>',
           '<circle cx="20" cy="15" r="5" fill="#3a3f47"/><circle cx="38" cy="15" r="5" fill="#3a3f47"/><circle cx="56" cy="15" r="5" fill="#3a3f47"/>',
           f'<text x="{w // 2}" y="20" text-anchor="middle" font-family="monospace" font-size="12" fill="#7d838c">{escape(title)}</text>',
           f'<g font-family="JetBrains Mono, DejaVu Sans Mono, Menlo, Consolas, monospace" font-size="{font_px}" xml:space="preserve">']
    for ri, row in enumerate(lines):
        y = top + ri * lh
        spans, cur, cur_style = [], "", None
        for ch, fg, bold, dim in row:
            style = (fg, bold, dim)
            if style != cur_style and cur:
                spans.append((cur, cur_style))
                cur = ""
            cur_style = style
            cur += ch
        if cur:
            spans.append((cur, cur_style))
        if not spans:
            continue
        parts, x = [], pad_x
        for text, (fg, bold, dim) in spans:
            attrs = f' fill="{fg or FG}"'
            if bold:
                attrs += ' font-weight="700"'
            if dim:
                attrs += ' opacity="0.65"'
            # one x per glyph keeps box-drawing / block characters on an exact grid
            xs = " ".join(f"{x + k * cw:.1f}" for k in range(len(text)))
            parts.append(f'<tspan x="{xs}"{attrs}>{escape(text)}</tspan>')
            x += len(text) * cw
        out.append(f'<text y="{y}">{"".join(parts)}</text>')
    out.append("</g></svg>")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--title", default="terminal")
    ap.add_argument("--from", dest="start", default="", help="drop everything before the first line containing this text")
    ap.add_argument("--until", default="", help="drop everything after the first line containing this text")
    ap.add_argument("--extra", type=int, default=0, help="keep N more lines after the --until match (e.g. a panel border)")
    ap.add_argument("--lines", type=int, default=0, help="keep at most N lines")
    a = ap.parse_args()
    raw = open(a.input, encoding="utf-8", errors="replace", newline="").read()   # keep \r (progress bars)
    lines = parse(raw)
    text = ["".join(c[0] for c in r) for r in lines]
    lo, hi = 0, len(lines)
    if a.start:
        lo = next((n for n, t in enumerate(text) if a.start in t), 0)
    if a.until:
        hi = next((n + 1 + a.extra for n, t in enumerate(text) if n >= lo and a.until in t), hi)
    lines = lines[lo:hi]
    while lines and not lines[-1]:
        lines.pop()
    if a.lines:
        lines = lines[: a.lines]
    open(a.output, "w", encoding="utf-8").write(to_svg(lines, a.title))
    print(f"wrote {a.output} ({len(lines)} lines)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
