#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are shared with the scripts that source this file
# distro.sh - which pacman-based distribution this is. Requires packages.sh (PACMAN_AVAILABLE).
#
# Arch Linux and CachyOS share the installation path: same package names, pacman, the AUR and the
# same configuration files. What differs is handled by generic checks in packages.sh (packages that
# the distribution's repositories already provide, an AUR helper shipped in those repositories,
# conflicts with packages the distribution installs by default), so the steps never branch on the
# distribution. This file only identifies it, for the messages and the log.
#
#   DISTRO_ID     arch | cachyos | arch-based (another pacman distribution) | unknown
#   DISTRO_NAME   PRETTY_NAME from os-release (e.g. "CachyOS Linux")

DISTRO_ID=unknown
DISTRO_NAME=""

# distro_detect: read os-release without sourcing it (MONOLITH_OS_RELEASE overrides the path, for tests).
distro_detect() {
    local file=${MONOLITH_OS_RELEASE:-/etc/os-release} k v id="" like="" name=""
    if [[ -r $file ]]; then
        while IFS='=' read -r k v; do
            v=${v%\"}; v=${v#\"}; v=${v%\'}; v=${v#\'}
            case $k in
                ID) id=$v ;;
                ID_LIKE) like=$v ;;
                PRETTY_NAME) name=$v ;;
            esac
        done <"$file"
    fi
    case $id in
        cachyos) DISTRO_ID=cachyos ;;
        arch) DISTRO_ID=arch ;;
        *)
            if [[ " $like " == *" arch "* ]] || (( PACMAN_AVAILABLE )); then
                DISTRO_ID=arch-based
            else
                DISTRO_ID=unknown
            fi
            ;;
    esac
    DISTRO_NAME=${name:-${id:-unknown}}
}

