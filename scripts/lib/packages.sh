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
