#!/usr/bin/env bash
# shellcheck shell=bash
# packages.sh - read packages.txt and query pacman. Requires common.sh.

PACMAN_AVAILABLE=0
command -v pacman >/dev/null 2>&1 && PACMAN_AVAILABLE=1

# pkg_list <source:scope>: print package names of a section (comments stripped, de-duplicated).
pkg_list() {
    awk -v sec="$1" '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        /^\[.*\][[:space:]]*$/ { cur = $0; gsub(/^\[|\][[:space:]]*$/, "", cur); next }
        cur == sec {
            sub(/[[:space:]]*#.*/, "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            if ($0 != "" && !seen[$0]++) print $0
        }
    ' "$MONOLITH_PACKAGES_FILE"
}

# pkg_desc <name>: description (text after '#') of the first entry with that name.
pkg_desc() {
    awk -v name="$1" '
        /^[[:space:]]*#/ || /^\[/ { next }
        {
            n = $1
            if (n == name) {
                i = index($0, "#")
                if (i > 0) { d = substr($0, i + 1); gsub(/^[[:space:]]+/, "", d); print d }
                exit
            }
        }
    ' "$MONOLITH_PACKAGES_FILE"
}

# pkg_installed <name>: satisfied by an installed package or provider (pacman -T).
pkg_installed() {
    (( PACMAN_AVAILABLE )) || return 1
    pacman -T "$1" >/dev/null 2>&1
}

# pkg_in_repos <name>: package exists in the synced official repositories.
pkg_in_repos() {
    (( PACMAN_AVAILABLE )) || return 1
    pacman -Si "$1" >/dev/null 2>&1
}

# aur_helper: print the first available AUR helper (or the requested one).
aur_helper() {
    local want=${1:-} h
    if [[ -n $want ]]; then
        command -v "$want" >/dev/null 2>&1 && echo "$want"
        return
    fi
    for h in paru yay; do
        if command -v "$h" >/dev/null 2>&1; then
            echo "$h"
            return
        fi
    done
    return 1
}

# aur_helper_in_repos [name]: the first AUR helper (or the requested one) that the synced repositories
# ship, so it can be installed with pacman. CachyOS has paru and yay in its own repositories; on Arch
# they exist only in the AUR, and this prints nothing.
aur_helper_in_repos() {
    local h
    for h in ${1:-paru yay}; do
        if pkg_in_repos "$h"; then
            echo "$h"
            return 0
        fi
    done
    return 1
}

# Conflicts. pacman checks them only inside a real transaction (a --print run reports success), and one
# conflicting package makes the whole 'pacman -S' fail. A distribution can ship an alternative by default
# (pulseaudio instead of pipewire-pulse, a different power daemon on CachyOS...), so conflicting packages
# are detected first and left out: the installed alternative is kept and the user is told.

# _pkg_conflict_pairs: "<package> <conflict>" for each 'Conflicts With' entry of pacman -Si / -Qi output
# on stdin (version constraints stripped; long lists continue on indented lines).
_pkg_conflict_pairs() {
    awk '
        /^Name / { name = $3 }
        /^[^ ]/ { field = $0; sub(/[[:space:]]*:.*/, "", field); value = $0; sub(/^[^:]*:[[:space:]]*/, "", value) }
        /^ / { value = $0 }
        field == "Conflicts With" {
            n = split(value, c, /[[:space:]]+/)
            for (i = 1; i <= n; i++) if (c[i] != "" && c[i] != "None") { sub(/[<>=].*/, "", c[i]); print name, c[i] }
        }'
}

# pkg_split_conflicts <package...>: sets PKG_OK (safe to install) and PKG_CONFLICT ("<package>: <installed...>"),
# looking both ways: what the package declares, and installed packages that declare a conflict with it.
# Runs in the current shell (not in $(...)), so the list of installed packages is read only once.
PKG_OK=() PKG_CONFLICT=()
pkg_split_conflicts() {
    PKG_OK=() PKG_CONFLICT=()
    (( PACMAN_AVAILABLE )) || { PKG_OK=("$@"); return 0; }
    local -A against=()
    local owner target p c
    while read -r owner target; do
        against[$target]+=" $owner"
    done < <(LC_ALL=C pacman -Qi 2>/dev/null | _pkg_conflict_pairs)
    for p in "$@"; do
        local -A found=()
        while read -r _ c; do
            pacman -T "$c" >/dev/null 2>&1 && found[$c]=1
        done < <(LC_ALL=C pacman -Si "$p" 2>/dev/null | _pkg_conflict_pairs)
        for c in ${against[$p]-}; do found[$c]=1; done
        if (( ${#found[@]} )); then PKG_CONFLICT+=("$p: ${!found[*]}"); else PKG_OK+=("$p"); fi
        unset found
    done
}
