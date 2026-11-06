#!/usr/bin/env bash
# preview-grub.sh - boots the MONOLITH GRUB theme in QEMU: the real GRUB (BIOS build) with a NixOS-like menu,
# so what you see is what the boot menu draws. Nothing is installed or written outside a temporary folder.
#
#   branding/preview-grub.sh [--res 1920x1080] [--lang pt|en] [--shot FILE.png] [--snowflake FILE.svg]
#
# Default: a QEMU window (arrows, Enter, e, c work like on the real menu; close the window to quit).
# --shot: no window: boots, saves a screenshot to FILE.png and exits.
# Needs: rsvg-convert, magick, grub-mkfont, grub-mkrescue (+ xorriso), qemu-system-x86_64, fc-match, and the
# NixOS snowflake (nixos-icons, or --snowflake; downloaded from nixos-artwork as a last resort).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
res=1920x1080 lang=pt shot="" svg=""
die() { printf 'preview-grub: %s\n' "$*" >&2; exit 1; }
while (($#)); do
    case $1 in
        --res) res=$2; shift ;;
        --lang) lang=$2; shift ;;
        --shot) shot=$2; shift ;;
        --snowflake) svg=$2; shift ;;
        -h | --help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done
for c in rsvg-convert magick grub-mkfont grub-mkrescue xorriso qemu-system-x86_64 fc-match; do
    command -v "$c" >/dev/null || die "missing command: $c"
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# the snowflake: --snowflake, the installed nixos-icons, or nixos-artwork
if [[ -z $svg ]]; then
    for d in /run/current-system/sw/share/icons "$HOME/.nix-profile/share/icons" /usr/share/icons; do
        [[ -f $d/hicolor/scalable/apps/nix-snowflake-white.svg ]] && { svg=$d/hicolor/scalable/apps/nix-snowflake-white.svg; break; }
    done
fi
if [[ -z $svg ]]; then
    svg=$work/nix-snowflake-white.svg
    curl -sSfL -m 30 -o "$svg" https://raw.githubusercontent.com/NixOS/nixos-artwork/master/logo/nix-snowflake-white.svg ||
        die "snowflake SVG not found: pass --snowflake FILE"
fi

# JetBrains Mono (plain or Nerd Font), as the theme uses
font() {
    local f
    for fam in "JetBrains Mono" "JetBrainsMono Nerd Font" "JetBrainsMono Nerd Font Mono"; do
        f=$(fc-match -f '%{file}' "$fam:style=$1")
        [[ $f == *JetBrains* ]] && { printf '%s' "$f"; return; }
    done
    die "JetBrains Mono not found (fontconfig)"
}
regular=$(font Regular) bold=$(font Bold)

# theme (only the pieces build.sh grub needs: the snowflake and the wordmark)
mkdir -p "$work/br" "$work/iso/boot/grub"
cp "$svg" "$work/br/snowflake.svg"
cp "$here/wordmark.svg" "$work/br/"
"$here/build.sh" grub "$work/br" "$work/iso/boot/grub/theme" "$res" "$lang" "$regular" "$bold" 2>&1 | grep -v -i 'aviso\|warning' || true

# a menu shaped like NixOS' (the theme, fonts and background loaded the way install-grub.pl does)
{
    printf '%s\n' "insmod all_video" "insmod gfxterm" "insmod png" "set gfxmode=$res,auto" "set gfxpayload=keep" "terminal_output gfxterm"
    for f in "$work"/iso/boot/grub/theme/*.pf2; do printf 'loadfont ($root)/boot/grub/theme/%s\n' "${f##*/}"; done
    cat <<'CFG'
background_image ($root)/boot/grub/theme/background.png
set theme=($root)/boot/grub/theme/theme.txt
set timeout=15
set default=0
menuentry "NixOS" { echo "(preview) booting NixOS"; sleep 2 }
submenu "NixOS - All configurations" {
  menuentry "NixOS - Configuration 3 (2026-11-06 - 26.05)" { echo "(preview)"; sleep 2 }
  menuentry "NixOS - Configuration 2 (2026-11-05 - 26.05)" { echo "(preview)"; sleep 2 }
}
menuentry "NixOS (recovery)" { echo "(preview) booting the recovery entry"; sleep 2 }
menuentry "UEFI Firmware Settings" { echo "(preview)"; sleep 2 }
CFG
} >"$work/iso/boot/grub/grub.cfg"

pc=/usr/lib/grub/i386-pc
[[ -d $pc ]] || pc=$(dirname "$(readlink -f "$(command -v grub-mkrescue)")")/../lib/grub/i386-pc
[[ -d $pc ]] || die "GRUB i386-pc modules not found"
grub-mkrescue -d "$pc" -o "$work/preview.iso" "$work/iso" >/dev/null 2>&1 || die "grub-mkrescue failed"

qemu=(qemu-system-x86_64 -m 256 -cdrom "$work/preview.iso" -device VGA,vgamem_mb=64 -name "MONOLITH GRUB preview")
if [[ -z $shot ]]; then
    "${qemu[@]}" -display gtk,zoom-to-fit=on
else
    coproc QEMU { "${qemu[@]}" -display none -monitor stdio 2>/dev/null; }
    sleep 6
    printf 'screendump %s\n' "$work/shot.ppm" >&"${QEMU[1]}"
    sleep 1
    printf 'quit\n' >&"${QEMU[1]}"
    wait "$QEMU_PID" 2>/dev/null || true
    [[ -f $work/shot.ppm ]] || die "no screenshot (QEMU did not start?)"
    magick "$work/shot.ppm" "PNG24:$shot"
    printf '%s\n' "$shot"
fi
