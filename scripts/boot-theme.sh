#!/usr/bin/env bash
# boot-theme.sh - the MONOLITH boot experience on Arch Linux / CachyOS: the Plymouth splash and the Quickshell
# greeter on greetd. What monolith.boot.plymouth and monolith.greeter do on NixOS (nix/modules/nixos/boot.nix,
# greeter.nix), done in place from the same sources (branding/, greeter/).
#
#   boot-theme.sh install [options]   install or bring up to date (safe to run again)
#   boot-theme.sh remove              put back the previous Plymouth theme and greetd config, remove our files
#   boot-theme.sh status              show what is installed
#
# Options of "install":
#   --no-plymouth / --no-greeter   leave that part out
#   --mark FILE                    SVG drawn as the mark (default: the Arch logo, without the ™)
#   --lang pt|en                   greeter language (default: from $LANG)
#   --user NAME                    user selected when none is remembered (default: the one running this)
#   --nothing                      Nothing theme look (LED progress row and password row)
#
# Run it as your user: the images are rendered with your fonts (JetBrains Mono), and sudo is asked only to
# install. What it writes:
#   /usr/share/monolith/branding              mark, wordmark, light sweep frames
#   /usr/share/plymouth/themes/monolith       the splash; it becomes the default theme (initramfs rebuilt)
#   /etc/systemd/system/plymouth-quit.service.d/monolith.conf   keep the last frame until the greeter draws it
#   /usr/share/monolith/greeter               greeter/ + the shell's Txt, Btn, Avatar
#   /etc/monolith/greeter.json, /usr/lib/monolith/monolith-greeter (launcher: cage + qs, tuigreet if it fails)
#   /etc/greetd/config.toml (the previous one saved as config.toml.monolith-backup), greetd.service enabled
#   /etc/tmpfiles.d/monolith-greeter.conf     state / cache directories of the greeter user
# Recovery: the launcher falls back to tuigreet when the graphical greeter does not show up in 25 s, the
# greeter offers a "Console" session, Ctrl+Alt+F2 still gives a text login, and "remove" undoes everything.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARE=/usr/share/monolith
THEME_DIR=/usr/share/plymouth/themes/monolith
STATE=/var/lib/monolith/boot-theme
LAUNCHER=/usr/lib/monolith/monolith-greeter
GREETD_CONF=/etc/greetd/config.toml
QUIT_DROPIN=/etc/systemd/system/plymouth-quit.service.d/monolith.conf
GREETD_DROPIN=/etc/systemd/system/greetd.service.d/monolith.conf
TMPFILES=/etc/tmpfiles.d/monolith-greeter.conf
START_TIMEOUT=25

die() { printf 'boot-theme.sh: %s\n' "$*" >&2; exit 1; }
say() { printf '\033[1m::\033[0m %s\n' "$*"; }
as_root() { if [[ $EUID == 0 ]]; then "$@"; else sudo "$@"; fi; }
# put <mode> <content-file> <dest>: install a file as root
put() { as_root install -D -m "$1" "$2" "$3"; }

usage() { sed -n '2,/^set -E/p' "$0" | sed -e '/^set -E/d' -e 's/^# \{0,1\}//'; }

status() {
    local t
    t=$(plymouth-set-default-theme 2>/dev/null || echo "?")
    printf 'plymouth theme   %s%s\n' "$t" "$([[ -d $THEME_DIR ]] && echo " (monolith installed)")"
    printf 'splash in cmdline %s\n' "$(grep -qw splash /proc/cmdline && echo yes || echo 'no (add "quiet splash" to the kernel parameters)')"
    printf 'greeter          %s\n' "$([[ -x $LAUNCHER ]] && echo installed || echo 'not installed')"
    printf 'greetd.service   %s\n' "$(systemctl is-enabled greetd.service 2>/dev/null || true)"
    t=/etc/systemd/system/display-manager.service
    printf 'display-manager  %s\n' "$([[ -e $t ]] && basename "$(readlink -f "$t")" || echo 'none (getty login)')"
}

# ── build (as the user) ──────────────────────────────────────────────────────────────────────────────────
build_branding() {
    local out=$1 mark=$2 svg=$1.mark.svg
    if [[ $mark == /usr/share/pixmaps/archlinux-logo.svg ]]; then
        # only the arch: the logo's other paths are the ™ sign
        awk '/<path/ { if (seen++) next } { print }' "$mark" >"$svg"
    else
        cp "$mark" "$svg"
    fi
    bash "$ROOT/branding/build.sh" branding "$out" "$svg"
}

build_plymouth() {
    local branding=$1 out=$2
    NOTHING=$NOTHING bash "$ROOT/branding/build.sh" plymouth "$branding" "$out" "$THEME_DIR"
    # the mkinitcpio hook copies these fonts into the initramfs (prompts, LUKS password, messages)
    printf 'Font=JetBrains Mono\nMonospaceFont=JetBrains Mono\n' >>"$out/monolith.plymouth"
}

build_greeter() {
    local out=$1 c
    mkdir -p "$out/components"
    cp -r "$ROOT/greeter/." "$out/"
    for c in Txt Btn Avatar; do cp "$ROOT/configs/.config/quickshell/components/$c.qml" "$out/components/"; done
}

# the JSON the greeter reads (same keys as nix/modules/nixos/greeter.nix)
greeter_json() {
    local users='[]' layout variant keyboard version
    users=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ { print $1 "\t" $5 }' |
        jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | { name: .[0], description: (((.[1] // "") | split(",")[0]) // "") })')
    layout=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Layout: //p'); layout=${layout:-us}
    variant=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Variant: //p')
    keyboard=$layout${variant:+ ($variant)}
    version=$(sed -n 's/.*version *= *"\([^"]*\)".*/\1/p' "$ROOT/flake.nix" | head -n1)
    jq -n --arg language "$LANGUAGE" --arg version "${version:-0.1.0}" --arg user "$DEFAULT_USER" \
        --argjson users "$users" --arg keyboard "$keyboard" --arg branding "$SHARE/branding" \
        --argjson nothing "$([[ $NOTHING == 1 ]] && echo true || echo false)" '{
        language: $language, version: $version,
        defaultUser: $user, defaultSession: "hyprland", allowOtherUsers: true,
        clock24: true, animations: true, output: null, console: true,
        users: $users, sessionDirs: ["/usr/share/wayland-sessions"],
        background: "", branding: $branding, sweepFrames: 36,
        statePath: "/var/lib/monolith-greeter/state.json",
        keyboard: $keyboard, nothing: $nothing }'
}

launcher_script() {
    local layout variant options
    layout=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Layout: //p')
    variant=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Variant: //p')
    options=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Options: //p')
    cat <<EOF
#!/bin/sh
# MONOLITH greeter launcher (written by scripts/boot-theme.sh): Quickshell inside cage; if it fails or does not
# show its window within ${START_TIMEOUT} s, tuigreet takes over so a broken greeter never locks anyone out.
export MONOLITH_GREETER_CONFIG=/etc/monolith/greeter.json
export XDG_CACHE_HOME=/var/cache/monolith-greeter XDG_STATE_HOME=/var/cache/monolith-greeter/state
export XDG_DATA_HOME=/var/cache/monolith-greeter/data
export XKB_DEFAULT_LAYOUT='${layout:-us}' XKB_DEFAULT_VARIANT='${variant}' XKB_DEFAULT_OPTIONS='${options}'
export QT_QPA_PLATFORM=wayland

run=\$(mktemp -d)
export MONOLITH_GREETER_READY=\$run/ready
cage -s -d -m extend -- sh -c 'qs -p "\$1"; echo \$? >"\$2"' sh $SHARE/greeter "\$run/status" &
pid=\$!
( sleep ${START_TIMEOUT}; [ -e "\$run/ready" ] || kill "\$pid" 2>/dev/null ) &
watchdog=\$!
wait "\$pid"
kill "\$watchdog" 2>/dev/null
code=\$(cat "\$run/status" 2>/dev/null || echo 1)
rm -rf "\$run"
[ "\$code" = 0 ] && exit 0
echo "monolith-greeter: the graphical greeter failed (status \$code); starting the text greeter" >&2
exec tuigreet --time --remember --remember-session --asterisks \\
    --greeting "MONOLITH · Arch Linux" --sessions /usr/share/wayland-sessions
EOF
}

# ── install (as root, through sudo) ──────────────────────────────────────────────────────────────────────
install_plymouth() {
    local build=$1 prev
    prev=$(plymouth-set-default-theme 2>/dev/null || true)
    if [[ $prev != monolith ]]; then
        as_root mkdir -p "$STATE"
        printf '%s\n' "${prev:-bgrt}" | as_root tee "$STATE/plymouth-theme" >/dev/null
    fi
    as_root rm -rf "$THEME_DIR"
    as_root mkdir -p "$THEME_DIR"
    as_root cp -r "$build/plymouth/." "$THEME_DIR/"
    as_root chmod -R u=rwX,go=rX "$THEME_DIR"
    grep -qw plymouth /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf 2>/dev/null ||
        say "warning: the plymouth hook is not in /etc/mkinitcpio.conf (HOOKS=(... udev plymouth ...))"
    grep -qw splash /proc/cmdline ||
        say "warning: \"splash\" is not in the kernel parameters; add \"quiet splash\" to the boot entry"
    say "Plymouth: default theme monolith, rebuilding the initramfs"
    as_root plymouth-set-default-theme -R monolith
}

install_greeter() {
    local build=$1
    say "greeter: greetd, cage and tuigreet"
    as_root pacman -S --needed --noconfirm greetd greetd-tuigreet cage
    command -v qs >/dev/null || as_root pacman -S --needed --noconfirm quickshell

    as_root rm -rf "$SHARE/greeter"
    as_root mkdir -p "$SHARE"
    as_root cp -r "$build/greeter" "$SHARE/greeter"
    as_root chmod -R u=rwX,go=rX "$SHARE/greeter"
    greeter_json >"$build/greeter.json"
    put 644 "$build/greeter.json" /etc/monolith/greeter.json
    launcher_script >"$build/launcher"
    put 755 "$build/launcher" "$LAUNCHER"

    printf 'd /var/lib/monolith-greeter 0755 greeter greeter -\nd /var/cache/monolith-greeter 0755 greeter greeter -\n' >"$build/tmpfiles"
    put 644 "$build/tmpfiles" "$TMPFILES"
    as_root systemd-tmpfiles --create "$TMPFILES"

    if [[ -f $GREETD_CONF ]] && ! grep -q monolith-greeter "$GREETD_CONF" && [[ ! -f $GREETD_CONF.monolith-backup ]]; then
        as_root cp -a "$GREETD_CONF" "$GREETD_CONF.monolith-backup"
    fi
    printf '# written by monolith-dotfiles scripts/boot-theme.sh (previous: config.toml.monolith-backup)\n[terminal]\nvt = 1\n\n[default_session]\ncommand = "%s"\nuser = "greeter"\n' \
        "$LAUNCHER" >"$build/greetd.toml"
    put 644 "$build/greetd.toml" "$GREETD_CONF"

    # the greeter starts once the splash is done (it then takes the display over from Plymouth's last frame)
    printf '[Unit]\nAfter=plymouth-quit-wait.service plymouth-quit.service systemd-user-sessions.service\n' >"$build/greetd-dropin"
    put 644 "$build/greetd-dropin" "$GREETD_DROPIN"

    # another display manager would fight greetd for display-manager.service
    local dm
    # (readlink -f prints the path itself when there is no link: only follow a link that exists)
    dm=""
    [[ -L /etc/systemd/system/display-manager.service ]] && dm=$(readlink -f /etc/systemd/system/display-manager.service)
    if [[ -n $dm && ${dm##*/} != greetd.service && ${dm##*/} != display-manager.service ]]; then
        say "disabling ${dm##*/} (greetd takes over)"
        as_root systemctl disable "${dm##*/}"
    fi
    as_root systemctl enable greetd.service
}

install_seamless() {
    local build=$1
    # with the greeter: keep the splash's last frame until the greeter draws the same one
    printf '[Service]\nExecStart=\nExecStart=-/usr/bin/plymouth quit --retain-splash\n' >"$build/quit-dropin"
    put 644 "$build/quit-dropin" "$QUIT_DROPIN"
}

cmd_install() {
    local mark=/usr/share/pixmaps/archlinux-logo.svg plymouth=1 greeter=1
    LANGUAGE=$([[ ${LANG:-} == pt* ]] && echo pt || echo en)
    DEFAULT_USER=${SUDO_USER:-$USER}
    NOTHING=0
    while (($#)); do
        case $1 in
            --no-plymouth) plymouth=0 ;;
            --no-greeter) greeter=0 ;;
            --mark) mark=${2:?--mark needs a file}; shift ;;
            --lang) LANGUAGE=${2:?}; shift; [[ $LANGUAGE == pt_BR ]] && LANGUAGE=pt ;;
            --user) DEFAULT_USER=${2:?}; shift ;;
            --nothing) NOTHING=1 ;;
            -h | --help) usage; exit 0 ;;
            *) die "unknown option: $1" ;;
        esac
        shift
    done
    [[ -f $mark ]] || die "mark not found: $mark"
    for t in rsvg-convert magick jq; do command -v "$t" >/dev/null || die "$t is needed (librsvg, imagemagick, jq)"; done
    ((plymouth)) && ! command -v plymouth-set-default-theme >/dev/null && die "plymouth is not installed (pacman -S plymouth)"

    local build
    build=$(mktemp -d); BUILD=$build
    trap 'rm -rf "$BUILD"' EXIT
    say "rendering the boot identity (mark: $mark)"
    build_branding "$build/branding" "$mark"
    ((plymouth)) && build_plymouth "$build/branding" "$build/plymouth"
    ((greeter)) && build_greeter "$build/greeter"

    as_root true || die "sudo is needed to install"
    as_root rm -rf "$SHARE/branding"
    as_root mkdir -p "$SHARE"
    as_root cp -r "$build/branding" "$SHARE/branding"
    as_root chmod -R u=rwX,go=rX "$SHARE/branding"

    ((greeter)) && install_greeter "$build"
    if ((plymouth && greeter)); then install_seamless "$build"; else as_root rm -f "$QUIT_DROPIN"; fi
    ((plymouth)) && install_plymouth "$build"
    as_root systemctl daemon-reload
    say "done; it shows on the next boot"
    status
}

cmd_remove() {
    local prev
    as_root true || die "sudo is needed"
    if [[ -x $LAUNCHER ]]; then
        say "greeter: disabling greetd and restoring its config"
        as_root systemctl disable greetd.service 2>/dev/null || true
        if [[ -f $GREETD_CONF.monolith-backup ]]; then as_root mv -f "$GREETD_CONF.monolith-backup" "$GREETD_CONF"; fi
        as_root rm -rf "$SHARE/greeter" /etc/monolith/greeter.json "$LAUNCHER" "$TMPFILES" "$GREETD_DROPIN" \
            /var/lib/monolith-greeter /var/cache/monolith-greeter
    fi
    as_root rm -f "$QUIT_DROPIN"
    if [[ -d $THEME_DIR ]]; then
        prev=$(cat "$STATE/plymouth-theme" 2>/dev/null || echo bgrt)
        say "Plymouth: back to $prev, rebuilding the initramfs"
        as_root plymouth-set-default-theme -R "$prev"
        as_root rm -rf "$THEME_DIR"
    fi
    as_root rm -rf "$SHARE/branding" "$STATE"
    as_root systemctl daemon-reload
    say "removed; getty@tty1 is the login again"
}

# sourced (tests): only the functions
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0

case ${1-} in
    install) shift; cmd_install "$@" ;;
    remove) cmd_remove ;;
    status) status ;;
    -h | --help | "") usage ;;
    *) die "unknown command: $1 (install | remove | status)" ;;
esac
