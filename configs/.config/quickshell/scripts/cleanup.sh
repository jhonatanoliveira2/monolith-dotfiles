#!/usr/bin/env bash
# Settings > Storage cleanup.
#   cleanup.sh scan          -> one line per target that exists: id|bytes|count|what will be removed
#   cleanup.sh run <id>      -> removes that target (root-owned ones ask for the password through pkexec)
# Nothing is removed by "scan"; the page shows its output and asks for confirmation before "run".
export LC_ALL=C
cache=${XDG_CACHE_HOME:-$HOME/.cache}
data=${XDG_DATA_HOME:-$HOME/.local/share}
size() { du -sb "$@" 2>/dev/null | awk '{s+=$1} END{print s+0}'; }
count() { find "$@" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l; }
tobytes() { awk '{ v=$1; u=$2; m=1; if (u ~ /^K/) m=1024; else if (u ~ /^M/) m=1048576; else if (u ~ /^G/) m=1073741824; else if (u ~ /^T/) m=1099511627776; printf "%d", v*m }'; }

scan() {
    [ -d "$data/Trash/files" ] && echo "trash|$(size "$data/Trash")|$(count "$data/Trash/files")|$data/Trash"
    [ -d "$cache/thumbnails" ] && echo "thumbs|$(size "$cache/thumbnails")|$(find "$cache/thumbnails" -type f 2>/dev/null | wc -l)|$cache/thumbnails"
    if command -v paccache >/dev/null && [ -d /var/cache/pacman/pkg ]; then
        # old versions (keeps the 2 newest of each package) + every version of uninstalled packages
        a=$(paccache -dk2 2>/dev/null | sed -n 's/.*: \([0-9]*\) candidates (disk space saved: \([0-9.]*\) \([KMGT]\)iB).*/\1 \2 \3/p')
        b=$(paccache -duk0 2>/dev/null | sed -n 's/.*: \([0-9]*\) candidates (disk space saved: \([0-9.]*\) \([KMGT]\)iB).*/\1 \2 \3/p')
        n=$(( ${a%% *} + 0 + ${b%% *} + 0 ))
        bytes=$(( $( [ -n "$a" ] && echo "${a#* }" | tobytes || echo 0) + $( [ -n "$b" ] && echo "${b#* }" | tobytes || echo 0) ))
        echo "pacman|$bytes|$n|/var/cache/pacman/pkg (paccache -rk2, paccache -ruk0)"
    fi
    [ -d "$cache/yay" ] && echo "yay|$(size "$cache/yay")|$(count "$cache/yay")|$cache/yay"
    [ -d "$cache/paru" ] && echo "paru|$(size "$cache/paru/clone" "$cache/paru/diff")|$(count "$cache/paru/clone")|$cache/paru/{clone,diff}"
    [ -d "$cache/pip" ] && echo "pip|$(size "$cache/pip")|0|$cache/pip"
    [ -d "$HOME/.npm/_cacache" ] && echo "npm|$(size "$HOME/.npm/_cacache")|0|$HOME/.npm/_cacache"
    [ -d "$cache/go-build" ] && echo "go|$(size "$cache/go-build")|0|$cache/go-build"
    [ -d "$cache/quickshell-monolith/covers" ] && echo "covers|$(size "$cache/quickshell-monolith/covers")|$(count "$cache/quickshell-monolith/covers")|$cache/quickshell-monolith/covers"
    if command -v journalctl >/dev/null; then
        j=$(journalctl --disk-usage 2>/dev/null | sed -n 's/.* take up \([0-9.]*\)\([KMGT]\) .*/\1 \2/p' | tobytes)
        echo "journal|${j:-0}|0|systemd journal (journalctl --vacuum-time=2weeks)"
    fi
    if command -v flatpak >/dev/null; then
        u=$(flatpak uninstall --unused --noninteractive --assumeyes --dry-run 2>/dev/null | grep -c '^ *[0-9]*\.')
        [ "${u:-0}" -gt 0 ] 2>/dev/null && echo "flatpak|0|$u|flatpak uninstall --unused"
    fi
    # the 6 largest folders in ~/.cache, for information only
    du -sb "$cache"/* 2>/dev/null | sort -rn | head -6 | while read -r b p; do echo "info|$b|0|$p"; done
}

run() {
    case $1 in
        trash) gio trash --empty ;;
        thumbs) rm -rf -- "$cache/thumbnails"/* ;;
        pacman) pkexec sh -c 'paccache -rk2 && paccache -ruk0' ;;
        yay) rm -rf -- "$cache/yay"/* ;;
        paru) rm -rf -- "$cache/paru/clone"/* "$cache/paru/diff"/* ;;
        pip) rm -rf -- "$cache/pip" ;;
        npm) rm -rf -- "$HOME/.npm/_cacache" ;;
        go) command -v go >/dev/null && go clean -cache || rm -rf -- "$cache/go-build" ;;
        covers) rm -f -- "$cache/quickshell-monolith/covers"/* ;;
        journal) pkexec journalctl --vacuum-time=2weeks ;;
        flatpak) flatpak uninstall --unused --noninteractive --assumeyes ;;
        *) echo "unknown target: $1" >&2; exit 2 ;;
    esac
}

case $1 in
    scan) scan ;;
    run) [ -n "$2" ] || exit 2; run "$2" ;;
    *) echo "usage: $0 scan | run <id>" >&2; exit 2 ;;
esac
