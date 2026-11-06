#!/usr/bin/env bash
# build.sh - renders the MONOLITH boot identity for NixOS. Called by the Nix derivations
# (nix/pkgs/{branding,plymouth-theme,grub-theme}.nix) and runnable by hand to preview the result.
#
# The mark is the NixOS snowflake (nix-snowflake-white.svg from nixpkgs' nixos-icons, NixOS artwork,
# CC-BY 4.0) in the Monolith style: light grey, a faint halo, standing above a lit horizon (stage.svg), with a
# light sweep crossing it (band.svg clipped to its shape) and the MONOLITH wordmark (wordmark.svg).
#
#   build.sh branding <out-dir> <snowflake.svg>
#       logo-{64,128,256,512}.png, wordmark-{32,64,128}.png, sweep-<i>.png (light sweep frames),
#       mark-white-512.png, mark-glow-512.png (bloom, 1.5x canvas), mark-sweep-<i>.png (light sweep over the
#       white mark, 1.5x canvas), wordmark-glow-128.png (1.5x canvas),
#       line-glow.png, star.png, pixel.png, bullet.png, frames (count).
#       Needs rsvg-convert, magick and the JetBrains Mono font (fontconfig).
#
# Every PNG written by ImageMagick is forced to 8-bit RGBA (PNG32:): the images are grey, ImageMagick would
# otherwise save them as greyscale PNGs, which GRUB cannot read ("png: color type not supported").
#   build.sh plymouth <branding-dir> <out-dir> <installed-dir>
#       monolith.plymouth + monolith.script + images; <installed-dir> is where the theme will live (Nix store).
#   build.sh grub <branding-dir> <out-dir> <WIDTHxHEIGHT> <pt|en> <regular.ttf> <bold.ttf>
#       theme.txt, background.png, fonts (*.pf2) and the selection / console pixmaps. Needs grub-mkfont.
#
# Layout shared by the three stages (keep greeter/GreeterWindow.qml in sync):
#   Plymouth / greeter: mark canvas 4:5, height = 20 % of the screen, top = 50 % - 0.62 x its height (centered),
#   wordmark height = 11 % of the mark, 16 % of the mark below it, progress line 16 % of the mark below that.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
FRAMES=36
MARK_TINT='#e9e9e9'      # resting colour of the snowflake (near white); the sweep lifts it to pure white

die() { printf 'build.sh: %s\n' "$*" >&2; exit 1; }
png() { rsvg-convert "$@"; }
rgba() { magick -size "$1" "xc:$2" "PNG32:$3"; }   # rgba <WxH> <colour> <file>

# mark_layer <snowflake.svg> <H> <out>: the snowflake alone on the transparent 4:5 canvas, at its place
mark_layer() {
    local svg=$1 H=$2 out=$3 W m top
    W=$((H * 4 / 5)); m=$((W * 86 / 100)); top=$((H * 47 / 100 - m / 2))
    png -w "$m" -h "$m" "$svg" -o "$out.tmp.png"
    magick -size "${W}x${H}" xc:none \( "$out.tmp.png" -fill white -colorize 100 \) -gravity north -geometry "+0+$top" -composite "PNG32:$out"
    rm -f "$out.tmp.png"
}

# compose_logo <snowflake.svg> <H> <out>: stage + bloom (wide soft glow + tight halo) + tinted snowflake
compose_logo() {
    local svg=$1 H=$2 out=$3 W
    W=$((H * 4 / 5))
    mark_layer "$svg" "$H" "$out.mark.png"
    png -w "$W" -h "$H" "$here/stage.svg" -o "$out.stage.png"
    magick "$out.stage.png" \
        \( "$out.mark.png" -blur "0x$((H / 14 + 1))" -channel A -evaluate multiply 0.30 +channel \) -compose over -composite \
        \( "$out.mark.png" -blur "0x$((H / 45 + 1))" -channel A -evaluate multiply 0.55 +channel \) -compose over -composite \
        \( "$out.mark.png" -fill "$MARK_TINT" -colorize 100 \) -compose over -composite "PNG32:$out"
    rm -f "$out.mark.png" "$out.stage.png"
}

# glow <in> <out> <sigma> <alpha>: the image on a 1.5x transparent canvas (same centre), blurred: a bloom sprite
glow() {
    magick "$1" -background none -gravity center -extent 150%x150% -blur "0x$3" \
        -channel A -evaluate multiply "$4" +channel "PNG32:$2"
}

branding() {
    local out=$1 svg=$2 h i y H=384 W
    [[ -f $svg ]] || die "snowflake SVG not found: $svg"
    mkdir -p "$out"
    for h in 64 128 256 512; do compose_logo "$svg" "$h" "$out/logo-$h.png"; done
    for h in 32 64 128; do png -h "$h" "$here/wordmark.svg" -o "$out/wordmark-$h.png"; done
    # light sweep: a soft diagonal band crossing the snowflake from top to bottom, clipped to its shape
    W=$((H * 4 / 5))
    compose_logo "$svg" "$H" "$out/.base.png"
    mark_layer "$svg" "$H" "$out/.mask.png"
    for ((i = 0; i < FRAMES; i++)); do
        y=$((10 + i * 220 / (FRAMES - 1)))
        sed "s|@Y@|$y|" "$here/band.svg" | png -w "$W" -h "$H" -o "$out/.band.png"
        magick "$out/.band.png" "$out/.mask.png" -compose DstIn -composite "PNG32:$out/.lit.png"
        # the lit band blooms: its own blurred copy under it, then the band itself
        magick "$out/.base.png" \( "$out/.lit.png" -blur 0x9 -channel A -evaluate multiply 0.9 +channel \) -compose over -composite \
            "$out/.lit.png" -compose over -composite "PNG32:$out/sweep-$i.png"
    done
    rm -f "$out"/.base.png "$out"/.mask.png "$out"/.band.png "$out"/.lit.png
    # pure white mark (the greeter) and the bloom sprites
    mark_layer "$svg" 512 "$out/mark-white-512.png"
    glow "$out/mark-white-512.png" "$out/mark-glow-512.png" 26 0.85
    # light sweep for the greeter's white mark: only the lit band (clipped to the snowflake) and its bloom,
    # on a transparent 1.5x canvas, drawn over the mark (mark-sweep-<i>.png)
    for ((i = 0; i < FRAMES; i++)); do
        y=$((10 + i * 220 / (FRAMES - 1)))
        sed "s|@Y@|$y|" "$here/band.svg" | png -w 410 -h 512 -o "$out/.band.png"
        magick "$out/.band.png" "$out/mark-white-512.png" -compose DstIn -composite -compose over \
            -background none -gravity center -extent 150%x150% "PNG32:$out/.lit.png"
        magick "$out/.lit.png" \( +clone -blur 0x14 -channel A -evaluate multiply 1.6 +channel \) -compose over -composite \
            "$out/.lit.png" -compose over -composite "PNG32:$out/mark-sweep-$i.png"
    done
    rm -f "$out"/.band.png "$out"/.lit.png
    glow "$out/wordmark-128.png" "$out/wordmark-glow-128.png" 10 0.9
    magick -size 512x64 xc:none -fill white -draw "rectangle 24,31 487,32" -blur 0x7 \
        -channel A -evaluate multiply 2.2 +channel "PNG32:$out/line-glow.png"
    magick -size 64x64 radial-gradient:white-none "PNG32:$out/star.png"
    echo "$FRAMES" >"$out/frames"
    rgba 1x1 white "$out/pixel.png"
    magick -size 48x48 xc:none -fill white -draw "circle 24,24 24,6" "PNG32:$out/bullet.png"
    cp "$svg" "$out/snowflake.svg"
    cp "$here/stage.svg" "$here/band.svg" "$here/wordmark.svg" "$out/"
}

plymouth() {
    local b=$1 out=$2 dest=$3 i
    mkdir -p "$out"
    cp "$b/logo-512.png" "$out/logo.png"
    cp "$b/wordmark-128.png" "$out/wordmark.png"
    cp "$b/pixel.png" "$b/bullet.png" "$b/line-glow.png" "$out/"
    cp "$b/mark-glow-512.png" "$out/glow.png"
    cp "$b/wordmark-glow-128.png" "$out/wordmark-glow.png"
    for ((i = 0; i < $(cat "$b/frames"); i++)); do cp "$b/sweep-$i.png" "$out/"; done
    sed "s|@FRAMES@|$(cat "$b/frames")|g" "$here/plymouth/monolith.script" >"$out/monolith.script"
    sed "s|@DIR@|$dest|g" "$here/plymouth/monolith.plymouth" >"$out/monolith.plymouth"
}

# pf2 font name as GRUB will see it ("<family> <style> <size>"), read from the file's NAME section
pf2name() { tr -c '[:print:]' '\n' <"$1" | grep -m1 -E '^Monolith .* [0-9]+$' || die "no font name in $1"; }

grub() {
    local b=$1 out=$2 res=$3 lang=$4 regular=$5 bold=$6
    local W=${res%x*} H=${res#*x}
    [[ $W =~ ^[0-9]+$ && $H =~ ^[0-9]+$ ]] || die "resolution must be WIDTHxHEIGHT, got $res"
    mkdir -p "$out"
    # fonts: Latin-1 + Latin Extended-A (Portuguese), arrows, bullet and middle dot
    local ranges=0x20-0x7E,0xA0-0x17F,0x2022-0x2022,0x2190-0x2193,0x25CF-0x25CF
    local item=$((H / 54)) small=$((H / 80)) term=$((H / 64))
    grub-mkfont -n Monolith -r "$ranges" -s "$item" -o "$out/monolith-$item.pf2" "$regular"
    grub-mkfont -n Monolith -r "$ranges" -s "$item" -o "$out/monolith-bold-$item.pf2" "$bold"
    grub-mkfont -n Monolith -r "$ranges" -s "$small" -o "$out/monolith-$small.pf2" "$regular"
    [[ $term == "$item" || $term == "$small" ]] || grub-mkfont -n Monolith -r "$ranges" -s "$term" -o "$out/monolith-$term.pf2" "$regular"
    local fItem fBold fSmall fTerm
    fItem=$(pf2name "$out/monolith-$item.pf2"); fBold=$(pf2name "$out/monolith-bold-$item.pf2")
    fSmall=$(pf2name "$out/monolith-$small.pf2")
    if [[ -f $out/monolith-$term.pf2 ]]; then fTerm=$(pf2name "$out/monolith-$term.pf2"); else fTerm=$fItem; fi

    # background: soft radial light behind the mark, logo + wordmark in the upper third
    local logoH=$((H * 16 / 100)) wmH logoTop wmTop menuTop
    wmH=$((logoH * 20 / 100)); logoTop=$((H * 9 / 100)); wmTop=$((logoTop + logoH + logoH * 14 / 100))
    compose_logo "$b/snowflake.svg" "$logoH" "$out/.logo.png"
    png -h "$wmH" "$b/wordmark.svg" -o "$out/.wordmark.png"
    magick -size "${W}x${H}" xc:black \
        \( -size "$((W * 3 / 2))x$((H * 3 / 2))" radial-gradient:'#161616-#000000' -gravity center -crop "${W}x${H}+0+0" +repage \) \
        -gravity north -composite \
        "$out/.logo.png" -gravity north -geometry "+0+$logoTop" -composite \
        "$out/.wordmark.png" -gravity north -geometry "+0+$wmTop" -composite \
        -strip "PNG32:$out/background.png"
    rm -f "$out/.logo.png" "$out/.wordmark.png"
    menuTop=$(((wmTop + wmH + H * 7 / 100) * 100 / H))

    # selection box like the shell's selected rows: faint fill, thin light border
    for p in nw n ne w e sw s se; do rgba 1x1 'rgba(255,255,255,0.45)' "$out/select_$p.png"; done
    rgba 1x1 'rgba(255,255,255,0.09)' "$out/select_c.png"
    for p in nw n ne w e sw s se; do rgba 1x1 'rgba(255,255,255,0.18)' "$out/terminal_box_$p.png"; done
    rgba 1x1 'rgba(8,8,8,0.92)' "$out/terminal_box_c.png"
    rgba 1x1 'rgba(255,255,255,0.35)' "$out/scrollbar_thumb_c.png"
    # timeout bar: GRUB gives the component the font's height whatever the theme says, so the pixmaps are a
    # 2 px line in the middle of a transparent strip; stretched to any height, only the thin line shows
    for p in progress_bar:0.16 progress_highlight:0.95; do
        magick -size 1x32 xc:none -fill "rgba(255,255,255,${p#*:})" -draw "rectangle 0,15 0,16" "PNG32:$out/${p%%:*}_c.png"
    done

    local timeout hint
    if [[ $lang == en ]]; then
        timeout="Booting in %d s"
        hint="↑ ↓  select   ·   Enter  boot   ·   e  edit   ·   c  console"
    else
        timeout="Iniciando em %d s"
        hint="↑ ↓  escolher   ·   Enter  iniciar   ·   e  editar   ·   c  console"
    fi
    sed -e "s|@ITEM_FONT@|$fItem|g" -e "s|@BOLD_FONT@|$fBold|g" -e "s|@SMALL_FONT@|$fSmall|g" -e "s|@TERM_FONT@|$fTerm|g" \
        -e "s|@MENU_TOP@|$menuTop|g" -e "s|@ITEM_H@|$((item * 2))|g" -e "s|@ITEM_PAD@|$((item * 3 / 4))|g" \
        -e "s|@TIMEOUT@|$timeout|g" -e "s|@HINT@|$hint|g" \
        "$here/grub/theme.txt" >"$out/theme.txt"
}

case ${1-} in
    branding) [[ $# == 3 ]] || die "usage: build.sh branding <out> <snowflake.svg>"; branding "$2" "$3" ;;
    plymouth) [[ $# == 4 ]] || die "usage: build.sh plymouth <branding> <out> <installed-dir>"; plymouth "$2" "$3" "$4" ;;
    grub) [[ $# == 7 ]] || die "usage: build.sh grub <branding> <out> <WxH> <pt|en> <regular.ttf> <bold.ttf>"; grub "$2" "$3" "$4" "$5" "$6" "$7" ;;
    *) die "usage: build.sh branding|plymouth|grub ..." ;;
esac
