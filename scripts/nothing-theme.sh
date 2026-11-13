#!/usr/bin/env bash
# nothing-theme.sh - the Nothing theme (LED / dot matrix) on Arch Linux / CachyOS: what monolith.nothingTheme
# does on NixOS (nix/modules/home-nothing.nix), done in place, from the same sources (nix/nothing/).
#
# Usage:
#   nothing-theme.sh on [options]   turn it on, or bring what it installed up to date (safe to run again)
#   nothing-theme.sh off            turn it off: remove what it installed, put back what it replaced
#   nothing-theme.sh status         show whether it is on and what it installed
# Options of "on":
#   --no-cursor --no-icons --no-nautilus --no-fastfetch --no-cava    leave that part out (removed if it was there)
#   --cursor-size N    cursor size in px, 16-96 (default 24)
#   --refresh          only when it is on: keep the parts chosen last time (install.sh runs this)
# Common: -y/--yes (never ask)  -n/--dry-run  --lang en|pt_BR  --no-color
#
# What "on" writes (all in your home; a file that was already there and is not ours is saved first):
#   ~/.config/monolith/nothing.json      tokens and defaults: the shell reads it (core/Nothing.qml) and changes at once
#   ~/.local/share/fonts/monolith-nothing  Doto, Space Grotesk, Space Mono (SIL OFL, checked against fixed sha256)
#   ~/.local/bin/monolith-dotmatrix      the wallpaper renderer (wallpaper-menu; needs python-numpy, python-pillow)
#   cursor:    ~/.icons/Monolith-Dots, ~/.icons/default/index.theme, ~/.config/monolith/cursor, gsettings
#   icons:     ~/.local/share/icons/Monolith-Dots-Icons, gsettings icon-theme
#   nautilus:  ~/.config/gtk-4.0/gtk.css, the default one plus nix/nothing/nautilus.css (opaque, no glass)
#   fastfetch: ~/.config/fastfetch/nothing.jsonc + nothing-logo.txt, fish function `fastfetch`
#   cava:      ~/.config/cava/config, ~/.local/bin/monolith-cava, fish function `cava`
# Its record (what it installed, what it saved, the previous gsettings) is in
# ~/.local/state/monolith-dotfiles/nothing-theme/.
# shellcheck disable=SC2034  # option/config variables are consumed by the sourced libraries
# shellcheck disable=SC2088  # "~/..." is only displayed
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOLITH_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export MONOLITH_ROOT
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/i18n.sh
source "$SCRIPT_DIR/lib/i18n.sh"
# shellcheck source=lib/messages.sh
source "$SCRIPT_DIR/lib/messages.sh"
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"

SRC="$MONOLITH_ROOT/nix/nothing"
NT_STATE="$STATE_DIR/nothing-theme"
MANIFEST="$NT_STATE/manifest"       # <part>\t<path relative to the home>: what this script wrote
SAVED="$NT_STATE/saved"             # what it replaced, at the same relative paths
GSET="$NT_STATE/gsettings"          # <part>\t<key>\t<previous value>
PARTS="$NT_STATE/parts"             # the parts chosen last time (sourced: cursor=1 ...)
SCHEMA=org.gnome.desktop.interface

# Same files and revision as nix/pkgs/nothing-fonts.nix (sha256 = its SRI hashes in hex).
FONT_REV=5174b3333331c966c38f4355d50b03ca1c1df2f9
FONTS=(
    "Doto[ROND,wght].ttf ofl/doto/Doto%5BROND,wght%5D.ttf 6f4fe7d37853b91df3698daa84cde2dbe1c9695d88c986e6510134910337d426"
    "SpaceGrotesk[wght].ttf ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf acad6de1fc93436f5c0f1f4137751ef04f1aea3063e7036535970ffcfbd79f72"
    "SpaceMono-Regular.ttf ofl/spacemono/SpaceMono-Regular.ttf 95837e182baeeada83368f7748db28357f0a1b75c6b84ff7065b5edf933c8e18"
    "SpaceMono-Bold.ttf ofl/spacemono/SpaceMono-Bold.ttf 405e73d41afb7e5906efce206a326af5c956f38e255f35421c260e861e599c59"
    "SpaceMono-Italic.ttf ofl/spacemono/SpaceMono-Italic.ttf eca264c8690a91fe837d19a6badf2d88961610c4c8aafcb196526192a9f258c5"
    "SpaceMono-BoldItalic.ttf ofl/spacemono/SpaceMono-BoldItalic.ttf cdcc95eddee312879a9728494e595f591cb159f3f276d79bc58673dec7e57138"
    "Doto-OFL.txt ofl/doto/OFL.txt 26a7b58bdba6cda8a78ca6e8b3791d8013b8abc6d5e6519f84193893aee02020"
    "SpaceGrotesk-OFL.txt ofl/spacegrotesk/OFL.txt 564ce565c371c5e5bbf286006565a7c9aa55a9f56e7ca58d56e05d649dd61a72"
    "SpaceMono-OFL.txt ofl/spacemono/OFL.txt 8e4ee42b2553e1e01504e61cb0d46d148cd8c9e5eacaa3622a7df2d4f2955b9f"
)
: "${MONOLITH_FONTS_URL:=https://raw.githubusercontent.com/google/fonts/$FONT_REV}"

CMD="" OPT_YES=0 OPT_DRY=0 OPT_LANG="" OPT_NO_COLOR=0 OPT_REFRESH=0
P_CURSOR=1 P_ICONS=1 P_NAUTILUS=1 P_FASTFETCH=1 P_CAVA=1 CURSOR_SIZE=24
declare -A SET_BY_FLAG=()
WARN=0 TMP=""

usage() { sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while (( $# )); do
    case $1 in
        on | off | status) CMD=$1; shift ;;
        --no-cursor) P_CURSOR=0; SET_BY_FLAG[cursor]=1; shift ;;
        --no-icons) P_ICONS=0; SET_BY_FLAG[icons]=1; shift ;;
        --no-nautilus) P_NAUTILUS=0; SET_BY_FLAG[nautilus]=1; shift ;;
        --no-fastfetch) P_FASTFETCH=0; SET_BY_FLAG[fastfetch]=1; shift ;;
        --no-cava) P_CAVA=0; SET_BY_FLAG[cava]=1; shift ;;
        --cursor-size) CURSOR_SIZE=${2:?--cursor-size needs a value}; SET_BY_FLAG[size]=1; shift 2 ;;
        --cursor-size=*) CURSOR_SIZE=${1#*=}; SET_BY_FLAG[size]=1; shift ;;
        --refresh) OPT_REFRESH=1; shift ;;
        -y | --yes) OPT_YES=1; shift ;;
        -n | --dry-run) OPT_DRY=1; shift ;;
        --lang) OPT_LANG=${2:?--lang needs a value}; shift 2 ;;
        --lang=*) OPT_LANG=${1#*=}; shift ;;
        --no-color) OPT_NO_COLOR=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done
[[ -n $CMD ]] || { usage >&2; exit 1; }
if [[ ! $CURSOR_SIZE =~ ^[0-9]+$ ]] || (( CURSOR_SIZE < 16 || CURSOR_SIZE > 96 )); then
    echo "--cursor-size: 16-96" >&2; exit 1
fi

if [[ -n $OPT_LANG ]]; then MONOLITH_LANG=$(normalize_lang "$OPT_LANG" || echo en); fi
[[ -n ${MONOLITH_LANG_USER-} || -n $OPT_LANG ]] || MONOLITH_LANG=$(detect_system_lang)
ui_init
init_logging nothing-theme
log INFO "nothing-theme $CMD (dry_run=$OPT_DRY refresh=$OPT_REFRESH) target=$TARGET_HOME"
trap '[[ -z $TMP ]] || rm -rf -- "$TMP"' EXIT

warn() { WARN=$(( WARN + 1 )); ui_warn "$*"; }
# real_session: the real home of the user running this (gsettings, fc-cache and the session are per-user)
real_session() { [[ -z ${MONOLITH_TARGET_HOME-} || ${MONOLITH_APPLY_GSETTINGS-0} == 1 ]]; }
# own_home: really the user's home, never a test one (packages and the running Hyprland are not faked)
own_home() { [[ -z ${MONOLITH_TARGET_HOME-} ]]; }
has() { command -v "$1" >/dev/null 2>&1; }

# ── record ──────────────────────────────────────────────────────────────────
safe_rel() { [[ -n $1 && $1 != /* && $1 != *..* ]]; }
in_manifest() { [[ -f $MANIFEST ]] && cut -f2 "$MANIFEST" | grep -Fxq -- "$1"; }
record() { in_manifest "$2" || printf '%s\t%s\n' "$1" "$2" >>"$MANIFEST"; }

# put <part> <rel> <source> [mode]: write a file (or a whole folder) into the home atomically. Something that
# is there, is not ours and differs is saved once, to be put back by "off".
put() {
    local part=$1 rel=$2 src=$3 mode=${4:-644} dst="$TARGET_HOME/$2" tmp
    safe_rel "$rel" || return 1
    if [[ -f $src && -f $dst ]] && cmp -s -- "$src" "$dst"; then record "$part" "$rel"; return 0; fi
    if (( OPT_DRY )); then ui_info "$(t nt.would_write "~/$rel")"; return 0; fi
    mkdir -p -- "$(dirname "$dst")" "$NT_STATE"
    if [[ -e $dst || -L $dst ]] && ! in_manifest "$rel" && [[ ! -e $SAVED/$rel ]]; then
        mkdir -p -- "$(dirname "$SAVED/$rel")"
        mv -- "$dst" "$SAVED/$rel"
        ui_dim "$(t nt.saved "~/$rel")"
        log INFO "saved: $rel"
    fi
    tmp="$dst.monolith-tmp.$$"
    rm -rf -- "$tmp"
    cp -r -- "$src" "$tmp"
    [[ -d $tmp ]] || chmod "$mode" -- "$tmp"
    rm -rf -- "$dst"
    mv -fT -- "$tmp" "$dst"
    record "$part" "$rel"
    log INFO "written ($part): $rel"
}

# unput <rel>: remove one of our paths and put back what it replaced
unput() {
    local rel=$1
    safe_rel "$rel" || return 0
    if (( OPT_DRY )); then ui_info "$(t nt.would_remove "~/$rel")"; return 0; fi
    rm -rf -- "${TARGET_HOME:?}/$rel"
    if [[ -e $SAVED/$rel || -L $SAVED/$rel ]]; then
        mkdir -p -- "$(dirname "$TARGET_HOME/$rel")"
        mv -- "$SAVED/$rel" "$TARGET_HOME/$rel"
        ui_dim "$(t nt.restored "~/$rel")"
    else
        # folders left empty by it (never the top-level ones such as ~/.config)
        local d
        d=$(dirname "$rel")
        while [[ $d == */* ]] && rmdir -- "$TARGET_HOME/$d" 2>/dev/null; do d=$(dirname "$d"); done
    fi
    log INFO "removed: $rel"
}

# drop_part <part>: undo one part (its files and its gsettings)
drop_part() {
    local part=$1 p rel key val keep
    [[ -f $MANIFEST ]] || return 0
    keep=$(mktemp)
    while IFS=$'\t' read -r p rel; do
        if [[ $p == "$part" ]]; then unput "$rel"; else printf '%s\t%s\n' "$p" "$rel" >>"$keep"; fi
    done <"$MANIFEST"
    if (( OPT_DRY )); then rm -f -- "$keep"; else mv -f -- "$keep" "$MANIFEST"; fi
    [[ -f $GSET ]] || return 0
    keep=$(mktemp)
    while IFS=$'\t' read -r p key val; do
        if [[ $p == "$part" ]]; then gset_restore "$key" "$val"; else printf '%s\t%s\t%s\n' "$p" "$key" "$val" >>"$keep"; fi
    done <"$GSET"
    if (( OPT_DRY )); then rm -f -- "$keep"; else mv -f -- "$keep" "$GSET"; fi
}

# ── gsettings (GTK and the portal read the cursor and icon themes from here) ─
GS_RUN=()
gs_ready() {
    real_session && has gsettings || return 1
    if [[ -z ${DBUS_SESSION_BUS_ADDRESS-} ]] && has dbus-run-session; then GS_RUN=(dbus-run-session --); fi
}
gset() { # gset <part> <key> <value>: remember the previous value once, then set
    local part=$1 key=$2 val=$3 cur
    gs_ready || return 0
    cur=$("${GS_RUN[@]}" gsettings get "$SCHEMA" "$key" 2>/dev/null) || return 0
    [[ $cur == "$val" || $cur == "'$val'" ]] && return 0
    if (( OPT_DRY )); then ui_info "$(t nt.would_gset "$key" "$val")"; return 0; fi
    mkdir -p -- "$NT_STATE"
    [[ -f $GSET ]] && cut -f2 "$GSET" | grep -Fxq -- "$key" || printf '%s\t%s\t%s\n' "$part" "$key" "$cur" >>"$GSET"
    "${GS_RUN[@]}" gsettings set "$SCHEMA" "$key" "$val" >>"$LOG_FILE" 2>&1 || warn "$(t nt.gset_failed "$key")"
}
gset_restore() { # previous values are in gsettings' own syntax ('Adwaita', 24)
    gs_ready || return 0
    if (( OPT_DRY )); then ui_info "$(t nt.would_gset "$1" "$2")"; return 0; fi
    "${GS_RUN[@]}" gsettings set "$SCHEMA" "$1" "$2" >>"$LOG_FILE" 2>&1 || warn "$(t nt.gset_failed "$1")"
}

# ── parts ───────────────────────────────────────────────────────────────────
py_has() { python3 -I -c "import $1" >/dev/null 2>&1; }

# python-pillow draws the cursors, python-numpy renders the wallpapers: offer to install what is missing
ensure_python() {
    local -a miss=()
    has python3 || miss+=(python)
    py_has PIL || miss+=(python-pillow)
    py_has numpy || miss+=(python-numpy)
    (( ${#miss[@]} )) || return 0
    if (( OPT_DRY )); then ui_info "$(t nt.would_pkgs "${miss[*]}")"; return 0; fi
    if own_home && has pacman && has sudo && ui_confirm "$(t nt.ask_pkgs "${miss[*]}")" y; then
        local -a conf=()
        (( OPT_YES )) && conf=(--noconfirm)
        sudo pacman -S --needed "${conf[@]}" "${miss[@]}" || warn "$(t nt.pkgs_failed "${miss[*]}")"
    else
        warn "$(t nt.pkgs_missing "${miss[*]}" "${miss[*]}")"
    fi
}

fonts() {
    local dir="$TMP/fonts" line name path sum want n=0
    mkdir -p "$dir"
    for line in "${FONTS[@]}"; do
        read -r name path want <<<"$line"
        local have="$TARGET_HOME/.local/share/fonts/monolith-nothing/$name"
        if [[ -f $have ]] && [[ $(sha256sum <"$have" | cut -d' ' -f1) == "$want" ]]; then
            cp -- "$have" "$dir/$name"; n=$(( n + 1 )); continue
        fi
        if (( OPT_DRY )); then n=$(( n + 1 )); continue; fi
        if ! curl -fsSL --retry 2 --max-time 60 -o "$dir/$name" "$MONOLITH_FONTS_URL/$path" 2>>"$LOG_FILE"; then
            rm -f -- "$dir/$name"; warn "$(t nt.font_failed "$name")"; continue
        fi
        sum=$(sha256sum <"$dir/$name" | cut -d' ' -f1)
        if [[ $sum != "$want" ]]; then
            rm -f -- "$dir/$name"; warn "$(t nt.font_hash "$name")"; log WARN "font $name: sha256 $sum, expected $want"; continue
        fi
        n=$(( n + 1 ))
    done
    if (( n == 0 )); then return 0; fi
    put base .local/share/fonts/monolith-nothing "$dir"
    if (( ! OPT_DRY )) && real_session && has fc-cache; then fc-cache -f "$TARGET_HOME/.local/share/fonts" >/dev/null 2>&1 || true; fi
    ui_ok "$(t nt.fonts "$n" "${#FONTS[@]}")"
}

tokens_json() { # nothing.json, as home-nothing.nix writes it (defaults: nix/modules/nothing-options.nix)
    jq -n --slurpfile t "$SRC/tokens.json" '{
        version: 1,
        defaults: {
            enabled: true, monochrome: true, edgeGlow: true,
            ledSize: 6, ledSpacing: 3, ledShape: "circle",
            wallpaperStyle: "dotmatrix", dither: "none", levels: 2, invert: false,
            contrast: 100, brightness: 100,
            lit: "f2f2f2", off: $t[0].wallpaperOff, background: "000000"
        },
        palette: ($t[0].palette | map_values("#" + .)),
        fonts: $t[0].fonts,
        motion: $t[0].motion,
        wallpapers: { dir: "", key: "", outputs: [] }
    }'
}

part_base() {
    fonts
    put base .local/bin/monolith-dotmatrix "$SRC/dotmatrix.py" 755
    tokens_json >"$TMP/nothing.json"
    put base .config/monolith/nothing.json "$TMP/nothing.json"
    ui_ok "$(t nt.base)"
}

part_cursor() {
    if ! py_has PIL; then
        (( OPT_DRY )) || { warn "$(t nt.cursor_skipped)"; return 0; }
    else
        python3 -I "$SRC/cursor.py" "$TMP/Monolith-Dots" --name Monolith-Dots >>"$LOG_FILE" 2>&1 \
            || { warn "$(t nt.cursor_failed)"; return 0; }
        put cursor .icons/Monolith-Dots "$TMP/Monolith-Dots"
    fi
    printf '[Icon Theme]\nName=Default\nInherits=Monolith-Dots\n' >"$TMP/index.theme"
    put cursor .icons/default/index.theme "$TMP/index.theme"
    printf 'Monolith-Dots %s\n' "$CURSOR_SIZE" >"$TMP/cursor"
    put cursor .config/monolith/cursor "$TMP/cursor"
    gset cursor cursor-theme Monolith-Dots
    gset cursor cursor-size "$CURSOR_SIZE"
    if (( ! OPT_DRY )) && own_home && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE-} ]] && has hyprctl; then
        hyprctl setcursor Monolith-Dots "$CURSOR_SIZE" >/dev/null 2>&1 || true
    fi
    ui_ok "$(t nt.cursor "$CURSOR_SIZE")"
}

part_icons() {
    python3 -I "$SRC/icons.py" "$TMP/Monolith-Dots-Icons" --name Monolith-Dots-Icons >>"$LOG_FILE" 2>&1 \
        || { warn "$(t nt.icons_failed)"; return 0; }
    put icons .local/share/icons/Monolith-Dots-Icons "$TMP/Monolith-Dots-Icons"
    gset icons icon-theme Monolith-Dots-Icons
    ui_ok "$(t nt.icons)"
}

# Nautilus without the glass: the default gtk.css (the one install.sh deploys) with the Nothing block after it,
# so a reinstall followed by "on --refresh" ends up with the same file and "off" puts the default one back
part_nautilus() {
    cat "$MONOLITH_ROOT/configs/.config/gtk-4.0/gtk.css" "$SRC/nautilus.css" >"$TMP/gtk.css"
    put nautilus .config/gtk-4.0/gtk.css "$TMP/gtk.css"
    ui_ok "$(t nt.nautilus)"
}

# the distribution's name in the title, spaced like the rest ("A R C H   L I N U X")
distro_label() {
    local name
    name=$( . /etc/os-release 2>/dev/null; echo "${NAME:-Linux}")
    name=$(tr '[:lower:]' '[:upper:]' <<<"$name" | tr -cd 'A-Z0-9 ')
    sed 's/./& /g; s/ *$//' <<<"${name:-LINUX}"
}

part_fastfetch() {
    { printf '%s\n' "// MONOLITH fastfetch, Nothing theme (written by scripts/nothing-theme.sh from nix/nothing/fastfetch.jsonc):" \
        "// the Arch logo as a matrix of LEDs (nothing-logo.txt: \$1 lit, \$2 half lit, \$3 off), grey labels, LED bars."
      grep -v '^//' "$SRC/fastfetch.jsonc" | sed "s/N I X O S/$(distro_label)/"; } >"$TMP/nothing.jsonc"
    put fastfetch .config/fastfetch/nothing.jsonc "$TMP/nothing.jsonc"
    put fastfetch .config/fastfetch/nothing-logo.txt "$SRC/fastfetch-logo-arch.txt"
    cat >"$TMP/fastfetch.fish" <<'FISH'
# Written by MONOLITH (scripts/nothing-theme.sh): `fastfetch` with no arguments uses the Nothing style
function fastfetch --wraps fastfetch --description "fastfetch in the Nothing style (MONOLITH)"
    if test (count $argv) -eq 0; and test -r ~/.config/fastfetch/nothing.jsonc
        command fastfetch --config ~/.config/fastfetch/nothing.jsonc
    else
        command fastfetch $argv
    end
end
FISH
    put fastfetch .config/fish/functions/fastfetch.fish "$TMP/fastfetch.fish"
    ui_ok "$(t nt.fastfetch)"
}

part_cava() {
    put cava .config/cava/config "$SRC/cava.conf"
    put cava .local/bin/monolith-cava "$SRC/cava-dots.py" 755
    cat >"$TMP/cava.fish" <<'FISH'
# Written by MONOLITH (scripts/nothing-theme.sh): `cava` with no arguments opens the LED version
function cava --wraps cava --description "cava as LEDs (MONOLITH Nothing theme)"
    if test (count $argv) -eq 0; and isatty stdout; and command -q monolith-cava
        monolith-cava
    else
        command cava $argv
    end
end
FISH
    put cava .config/fish/functions/cava.fish "$TMP/cava.fish"
    has cava || ui_dim "$(t nt.cava_missing)"
    ui_ok "$(t nt.cava)"
}

# ── commands ────────────────────────────────────────────────────────────────
is_on() { [[ -f $PARTS ]]; }

cmd_on() {
    if (( OPT_REFRESH )); then
        is_on || { ui_info "$(t nt.not_on)"; return 0; }
        local cursor=1 icons=1 nautilus=1 fastfetch=1 cava=1 cursor_size=24
        # shellcheck disable=SC1090
        source "$PARTS"
        [[ -n ${SET_BY_FLAG[cursor]-} ]] || P_CURSOR=$cursor
        [[ -n ${SET_BY_FLAG[icons]-} ]] || P_ICONS=$icons
        [[ -n ${SET_BY_FLAG[nautilus]-} ]] || P_NAUTILUS=$nautilus
        [[ -n ${SET_BY_FLAG[fastfetch]-} ]] || P_FASTFETCH=$fastfetch
        [[ -n ${SET_BY_FLAG[cava]-} ]] || P_CAVA=$cava
        [[ -n ${SET_BY_FLAG[size]-} ]] || CURSOR_SIZE=$cursor_size
    fi
    has jq || { ui_err "$(t nt.need "jq")"; exit 1; }
    has curl || warn "$(t nt.need "curl")"
    [[ -f $SRC/tokens.json ]] || { ui_err "$(t nt.no_sources "$SRC")"; exit 1; }
    ui_info "$(t nt.turning_on)"
    TMP=$(mktemp -d)
    ensure_python
    part_base
    if (( P_CURSOR )); then part_cursor; else drop_part cursor; fi
    if (( P_ICONS )); then part_icons; else drop_part icons; fi
    if (( P_NAUTILUS )); then part_nautilus; else drop_part nautilus; fi
    if (( P_FASTFETCH )); then part_fastfetch; else drop_part fastfetch; fi
    if (( P_CAVA )); then part_cava; else drop_part cava; fi
    if (( ! OPT_DRY )); then
        printf 'cursor=%s\nicons=%s\nnautilus=%s\nfastfetch=%s\ncava=%s\ncursor_size=%s\n' \
            "$P_CURSOR" "$P_ICONS" "$P_NAUTILUS" "$P_FASTFETCH" "$P_CAVA" "$CURSOR_SIZE" >"$PARTS"
    fi
    py_has numpy || ui_dim "$(t nt.no_numpy)"
    ui_ok "$(t nt.on_done)"
    ui_dim "$(t nt.relogin)"
}

cmd_off() {
    if ! is_on && [[ ! -f $MANIFEST ]]; then ui_info "$(t nt.not_on)"; return 0; fi
    ui_info "$(t nt.turning_off)"
    local part
    for part in cava fastfetch nautilus icons cursor base; do drop_part "$part"; done
    if (( OPT_DRY )); then return 0; fi
    if real_session && has fc-cache; then fc-cache -f "$TARGET_HOME/.local/share/fonts" >/dev/null 2>&1 || true; fi
    rm -rf -- "${NT_STATE:?}"
    ui_ok "$(t nt.off_done)"
    ui_dim "$(t nt.relogin)"
}

cmd_status() {
    if ! is_on; then ui_info "$(t nt.status_off)"; return 0; fi
    ui_ok "$(t nt.status_on)"
    local p rel
    while IFS=$'\t' read -r p rel; do ui_kv "$p" "~/$rel"; done <"$MANIFEST"
}

case $CMD in
    on) cmd_on ;;
    off) cmd_off ;;
    status) cmd_status ;;
esac
(( WARN == 0 )) || ui_warn "$(t nt.warnings "$WARN")"
exit 0
