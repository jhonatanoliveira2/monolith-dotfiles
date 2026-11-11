#!/usr/bin/env python3
# Monolith Icons: the icon theme of the default MONOLITH theme (Nautilus and every GTK app). Flat folders,
# files, places and devices in the greys of the shell palette (quickshell/core/Palettes.qml, "default"):
# a light front, a darker back and a quiet emblem. Everything else (symbolic UI icons, app icons) is
# inherited from Adwaita / hicolor.
#
#   icons.py OUTDIR [--name Monolith-Icons] [--preview sheet.svg]
#
# Pure Python (no dependencies): writes OUTDIR/index.theme and scalable SVGs in places/, mimetypes/, devices/.

import argparse
import os

LIGHT, MID, DARK, EMBLEM, WHITE = "#cccccc", "#888888", "#444444", "#5c5c5c", "#eeeeee"
HILITE = "#dadada"                          # 2 px top edge of the folder front

# ── emblems, drawn in a 20 x 20 box centred on (0, 0) ──
def stroke(width=2.6, cap="round"):
    return f'fill="none" stroke="{EMBLEM}" stroke-width="{width}" stroke-linecap="{cap}" stroke-linejoin="round"'


STROKE = stroke()
FILL = f'fill="{EMBLEM}"'
EMBLEMS = {
    "download": f'<path {STROKE} d="M0 -8V5M-6 -1L0 5L6 -1M-8 9H8"/>',
    "documents": f'<path {STROKE} d="M-6 -9H3L7 -5V9H-6Z"/>',
    "text": f'<path {STROKE} d="M-7 -6H7M-7 -1H4M-7 4H7M-7 9H1"/>',
    "music": f'<path {STROKE} d="M-3 6V-7L7 -9V4"/><circle cx="-6" cy="6" r="3.2" {FILL}/>'
             f'<circle cx="4" cy="4" r="3.2" {FILL}/>',
    "picture": f'<rect x="-9" y="-8" width="18" height="16" rx="2" {STROKE}/>'
               f'<path {STROKE} d="M-8 6L-3 0L1 4L4 1L8 6"/><circle cx="4" cy="-3.5" r="1.8" {FILL}/>',
    "video": f'<path {FILL} stroke="{EMBLEM}" stroke-width="2" stroke-linejoin="round" d="M-5 -8L8 0L-5 8Z"/>',
    "desktop": f'<rect x="-9" y="-8" width="18" height="12" rx="1.5" {STROKE}/><path {STROKE} d="M0 4V8M-5 9H5"/>',
    "home": f'<path {STROKE} d="M-9 0L0 -8L9 0M-6 -2V9H6V-2M-2 9V3H2V9"/>',
    "templates": f'<rect x="-8" y="-8" width="16" height="16" rx="1" {STROKE} stroke-dasharray="3 3.4"/>',
    "public": f'<circle cx="0" cy="-4" r="3.5" {STROKE}/><path {STROKE} d="M-8 9C-8 1 8 1 8 9"/>',
    "projects": f'<path {STROKE} d="M-7 6L5 -6L8 -3L-4 9H-7ZM2 -3L5 0M-9 9H9" />',
    "bookmark": f'<path {STROKE} d="M-6 -9H6V9L0 4L-6 9Z"/>',
    "globe": f'<circle r="8.5" {STROKE}/><ellipse rx="3.5" ry="8.5" {STROKE}/><path {STROKE} d="M-8.5 0H8.5"/>',
    "code": f'<path {STROKE} d="M-4 -7L-10 0L-4 7M4 -7L10 0L4 7"/>',
    "exec": f'<path {STROKE} d="M-8 -6L-2 0L-8 6M1 7H9"/>',
    "archive": f'<path {STROKE} stroke-dasharray="2.2 2.2" d="M0 -10V1"/><rect x="-3" y="2" width="6" height="7" rx="1" {STROKE}/>',
    "pdf": f'<path {STROKE} d="M-5 9V-8H1C6 -8 6 1 1 1H-5"/>',
    "sheet": f'<rect x="-8" y="-8" width="16" height="16" rx="1" {STROKE}/>'
             f'<path {stroke(2)} d="M-8 -2.7H8M-8 2.7H8M-2.7 -8V8"/>',
    "slides": f'<path {stroke(4, "butt")} d="M-6 9V2M0 9V-7M6 9V-2"/>',
    "drawing": f'<circle cx="-3" cy="-2" r="6" {STROKE}/><rect x="0" y="1" width="9" height="8" rx="1" {FILL}/>',
    "font": f'<path {STROKE} d="M-7 9L0 -9L7 9M-4 3H4"/>',
    "addon": f'<path {STROKE} d="M-8 -4H-3A3 3 0 1 1 3 -4H8V9H-8Z"/>',
    "certificate": f'<circle cx="0" cy="-3" r="5" {STROKE}/><path {STROKE} d="M-3 2L-5 10L0 7L5 10L3 2"/>',
    "firmware": f'<rect x="-6" y="-6" width="12" height="12" rx="1" {STROKE}/>'
                f'<path {stroke(2)} d="M-3 -9V-6M3 -9V-6M-3 6V9M3 6V9M-9 -3H-6M-9 3H-6M6 -3H9M6 3H9"/>',
    "addressbook": f'<circle cx="0" cy="-3" r="3.5" {STROKE}/><path {STROKE} d="M-7 9C-7 2 7 2 7 9"/>',
    "symlink": f'<path {STROKE} d="M-7 8V2C-7 -3 -3 -5 2 -5H7M3 -9L7 -5L3 -1"/>',
    "model": f'<path {STROKE} d="M0 -9L8 -4.5V4.5L0 9L-8 4.5V-4.5ZM0 0V9M0 0L8 -4.5M0 0L-8 -4.5"/>',
    "repo": f'<rect x="-8" y="-8" width="16" height="6" rx="1" {STROKE}/><rect x="-8" y="2" width="16" height="6" rx="1" {STROKE}/>',
    "preview": f'<path {STROKE} d="M-9 0C-5 -7 5 -7 9 0C5 7 -5 7 -9 0Z"/><circle r="2.6" {FILL}/>',
}


def emblem(name, cx, cy):
    return f'<g transform="translate({cx} {cy})">{EMBLEMS[name]}</g>' if name else ""


def folder(name=None):
    return ('<path fill="%s" d="M6 14a4 4 0 0 1 4-4h14c1.6 0 2.6.6 3.6 1.6L31 15h23a4 4 0 0 1 4 4v31H6z"/>' % MID
            + f'<rect x="4" y="21" width="56" height="35" rx="4" fill="{LIGHT}"/>'
            + f'<path fill="{HILITE}" d="M8 21h48a4 4 0 0 1 4 4v-2a2 2 0 0 0-2-2z"/>'
            + emblem(name, 32, 39.5))


def page(name=None):
    return (f'<path fill="{LIGHT}" d="M17 6h21l12 12v37a3 3 0 0 1-3 3H17a3 3 0 0 1-3-3V9a3 3 0 0 1 3-3z"/>'
            + f'<path fill="{MID}" d="M38 6v9a3 3 0 0 0 3 3h9z"/>'
            + emblem(name, 32, 38))


def trash(full=False):
    body = (f'<path fill="{LIGHT}" d="M16 20h32l-3 35a3 3 0 0 1-3 3H22a3 3 0 0 1-3-3z"/>'
            f'<path fill="none" stroke="{MID}" stroke-width="3" stroke-linecap="round" d="M26 27v24M32 27v24M38 27v24"/>')
    if full:
        return (f'<path fill="{WHITE}" stroke="{MID}" stroke-width="1.5" stroke-linejoin="round" d="M19 21l5-13 10 4-4 9z"/>'
                f'<path fill="{WHITE}" stroke="{MID}" stroke-width="1.5" stroke-linejoin="round" d="M32 21l7-15 8 7-5 8z"/>'
                + f'<rect x="12" y="18" width="40" height="4" rx="2" fill="{MID}"/>' + body)
    return (f'<rect x="26" y="8" width="12" height="7" rx="2" fill="none" stroke="{MID}" stroke-width="3"/>'
            + f'<rect x="12" y="13" width="40" height="5" rx="2" fill="{MID}"/>' + body)


def computer():
    return (f'<rect x="6" y="10" width="52" height="34" rx="3" fill="{LIGHT}"/>'
            f'<rect x="10" y="14" width="44" height="26" rx="1" fill="{DARK}"/>'
            f'<path fill="{MID}" d="M26 44h12l2 8H24z"/><rect x="18" y="52" width="28" height="4" rx="2" fill="{LIGHT}"/>')


def harddisk():
    return (f'<rect x="6" y="18" width="52" height="30" rx="4" fill="{LIGHT}"/>'
            f'<path fill="{MID}" d="M6 38h52v6a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4z"/>'
            f'<circle cx="50" cy="43" r="2" fill="{WHITE}"/>'
            f'<path fill="none" stroke="{MID}" stroke-width="2" stroke-linecap="round" d="M12 26h20M12 31h14"/>')


def multidisk():
    return (f'<rect x="10" y="8" width="44" height="20" rx="3" fill="{MID}"/>'
            f'<rect x="6" y="22" width="52" height="30" rx="4" fill="{LIGHT}"/>'
            f'<path fill="{MID}" d="M6 42h52v6a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4z"/>'
            f'<circle cx="50" cy="47" r="2" fill="{WHITE}"/>')


def removable():
    return (f'<rect x="23" y="6" width="18" height="16" rx="1" fill="{MID}"/>'
            f'<rect x="27" y="11" width="4" height="4" fill="{DARK}"/><rect x="33" y="11" width="4" height="4" fill="{DARK}"/>'
            f'<rect x="17" y="22" width="30" height="36" rx="4" fill="{LIGHT}"/>'
            f'<rect x="25" y="42" width="14" height="4" rx="2" fill="{MID}"/>')


def flash():
    return (f'<path fill="{LIGHT}" d="M18 6h20l10 10v39a3 3 0 0 1-3 3H19a3 3 0 0 1-3-3V8a2 2 0 0 1 2-2z"/>'
            f'<path fill="none" stroke="{MID}" stroke-width="3" stroke-linecap="round" d="M23 10v8M29 10v8M35 10v8"/>'
            f'<rect x="21" y="34" width="22" height="16" rx="2" fill="{MID}"/>')


def optical():
    return (f'<path fill="{LIGHT}" fill-rule="evenodd" d="M32 6a26 26 0 1 1 0 52a26 26 0 1 1 0-52zM32 28a4 4 0 1 0 0 8a4 4 0 1 0 0-8z"/>'
            f'<circle cx="32" cy="32" r="7.5" fill="none" stroke="{MID}" stroke-width="4"/>'
            f'<path fill="none" stroke="{HILITE}" stroke-width="3" stroke-linecap="round" d="M14 26a19 19 0 0 1 12-12"/>')


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">{body}</svg>\n'


ICONS = {   # context -> {icon name(s): svg body}
    "places": {
        "folder folder-open folder-drag-accept folder-visiting": folder(),
        "folder-documents": folder("documents"),
        "folder-download": folder("download"),
        "folder-music": folder("music"),
        "folder-pictures": folder("picture"),
        "folder-videos": folder("video"),
        "folder-projects": folder("projects"),
        "folder-desktop user-desktop": folder("desktop"),
        "user-home folder-home": folder("home"),
        "folder-templates": folder("templates"),
        "folder-publicshare": folder("public"),
        "user-bookmarks": folder("bookmark"),
        "folder-remote network-workgroup network-server": folder("globe"),
        "user-trash": trash(),
        "user-trash-full": trash(True),
    },
    "mimetypes": {
        "inode-directory": folder(),
        "inode-symlink": page("symlink"),
        "text-x-generic text-plain application-x-generic unknown": page("text"),
        "text-x-script text-x-python text-x-csrc text-x-c++src text-x-java text-x-makefile application-json "
        "application-javascript text-x-sql application-x-shellscript text-x-nix": page("code"),
        "text-x-preview": page("preview"),
        "application-x-executable application-x-sharedlib application-x-desktop": page("exec"),
        "application-x-addon": page("addon"),
        "application-x-firmware": page("firmware"),
        "application-certificate": page("certificate"),
        "image-x-generic": page("picture"),
        "audio-x-generic": page("music"),
        "video-x-generic": page("video"),
        "model": page("model"),
        "application-pdf": page("pdf"),
        "package-x-generic application-x-archive application-zip application-x-compressed-tar "
        "application-x-7z-compressed application-x-rar": page("archive"),
        "x-package-repository": page("repo"),
        "font-x-generic": page("font"),
        "text-html": page("globe"),
        "x-office-document x-office-document-template": page("documents"),
        "x-office-spreadsheet x-office-spreadsheet-template": page("sheet"),
        "x-office-presentation x-office-presentation-template": page("slides"),
        "x-office-drawing": page("drawing"),
        "x-office-addressbook": page("addressbook"),
        "application-x-cd-image": optical(),
    },
    "devices": {
        "computer": computer(),
        "drive-harddisk drive-harddisk-system": harddisk(),
        "drive-multidisk": multidisk(),
        "drive-removable-media drive-removable-media-usb media-removable": removable(),
        "media-flash": flash(),
        "media-optical drive-optical": optical(),
    },
}


def main():
    p = argparse.ArgumentParser(description="Monolith icon theme")
    p.add_argument("outdir")
    p.add_argument("--name", default="Monolith-Icons")
    p.add_argument("--preview", help="also write one SVG with every icon")
    a = p.parse_args()
    seen = []
    for ctx, icons in ICONS.items():
        d = os.path.join(a.outdir, "scalable", ctx)
        os.makedirs(d, exist_ok=True)
        for names, body in icons.items():
            first, *rest = names.split()
            with open(os.path.join(d, first + ".svg"), "w") as f:
                f.write(svg(body))
            for alias in rest:
                link = os.path.join(d, alias + ".svg")
                if not os.path.lexists(link):
                    os.symlink(first + ".svg", link)
            seen.append(body)
    sections = "".join(f"""
[scalable/{ctx}]
Context={ctx.capitalize() if ctx != "mimetypes" else "MimeTypes"}
Size=64
MinSize=8
MaxSize=512
Type=Scalable
""" for ctx in ICONS)
    with open(os.path.join(a.outdir, "index.theme"), "w") as f:
        f.write(f"""[Icon Theme]
Name={a.name}
Comment=MONOLITH default theme: flat grey folders, files and devices
Inherits=Adwaita,hicolor
Directories={",".join("scalable/" + c for c in ICONS)}
{sections}""")
    if a.preview:   # every icon in a row of 8, on a dark background
        cols, cell = 8, 80
        rows = (len(seen) + cols - 1) // cols
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{cols * cell}" height="{rows * cell}">',
               '<rect width="100%" height="100%" fill="#151515"/>']
        for i, body in enumerate(seen):
            x, y = (i % cols) * cell + 8, (i // cols) * cell + 8
            out.append(f'<g transform="translate({x},{y})">{body}</g>')
        out.append("</svg>")
        with open(a.preview, "w") as f:
            f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
