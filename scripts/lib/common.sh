#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are shared with the scripts that source this file
# common.sh - shared helpers: paths, logging, managed-file discovery and classification.
# This file is sourced by every script in scripts/. It must not produce output by itself.

MONOLITH_VERSION="0.1.0"

: "${MONOLITH_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
: "${MONOLITH_CONFIGS_DIR:=$MONOLITH_ROOT/configs}"
: "${MONOLITH_PACKAGES_FILE:=$MONOLITH_ROOT/packages.txt}"
: "${MONOLITH_WALLPAPERS_DIR:=$MONOLITH_ROOT/wallpapers}"   # wallpapers/static and wallpapers/live

# TARGET_HOME is where files are deployed. MONOLITH_TARGET_HOME exists for tests and
# for advanced users; by default it is the real $HOME.
if [[ -n ${MONOLITH_TARGET_HOME-} ]]; then
    TARGET_HOME=$MONOLITH_TARGET_HOME
    _state_base="$TARGET_HOME/.local/state"
    _data_base="$TARGET_HOME/.local/share"
else
    TARGET_HOME=$HOME
    _state_base="${XDG_STATE_HOME:-$HOME/.local/state}"
    _data_base="${XDG_DATA_HOME:-$HOME/.local/share}"
fi
STATE_DIR="$_state_base/monolith-dotfiles"
DATA_DIR="$_data_base/monolith-dotfiles"
BACKUP_ROOT="${MONOLITH_BACKUP_ROOT:-$DATA_DIR/backups}"
LOG_FILE=/dev/null

MANAGED=()

# init_logging <name>: create the state directory and select a timestamped log file.
init_logging() {
    local name=${1:-run}
    if mkdir -p "$STATE_DIR" 2>/dev/null; then
        LOG_FILE="$STATE_DIR/$name-$(date +%Y%m%d-%H%M%S).log"
        : >"$LOG_FILE" 2>/dev/null || LOG_FILE=/dev/null
    fi
}

# log <LEVEL> <message...>: technical log line (always English).
log() {
    local level=$1
    shift
    printf '%s [%s] %s\n' "$(date '+%F %T')" "$level" "$*" >>"$LOG_FILE" 2>/dev/null || true
}

# list_managed_files: fill MANAGED with paths relative to the configs directory
# (e.g. ".config/hypr/hyprland.lua"). Placeholders (.gitkeep) are never managed.
list_managed_files() {
    MANAGED=()
    local sub f
    for sub in .config .local; do
        [[ -d $MONOLITH_CONFIGS_DIR/$sub ]] || continue
        while IFS= read -r -d '' f; do
            MANAGED+=("${f#"$MONOLITH_CONFIGS_DIR"/}")
        done < <(find "$MONOLITH_CONFIGS_DIR/$sub" \( -type f -o -type l \) ! -name '.gitkeep' -print0 | LC_ALL=C sort -z)
    done
}

# classify_file <rel>: print one of new | same | diff | conflict.
classify_file() {
    local src="$MONOLITH_CONFIGS_DIR/$1" dst="$TARGET_HOME/$1"
    if [[ -d $dst && ! -L $dst ]]; then
        echo conflict
        return 0
    fi
    if [[ ! -e $dst && ! -L $dst ]]; then
        echo new
        return 0
    fi
    if [[ -L $src ]]; then
        if [[ -L $dst && "$(readlink "$src")" == "$(readlink "$dst")" ]]; then echo same; else echo diff; fi
        return 0
    fi
    if [[ -L $dst ]]; then
        echo diff
        return 0
    fi
    if cmp -s -- "$src" "$dst"; then echo same; else echo diff; fi
}

# symlinked_parent <rel>: print the first parent directory (below TARGET_HOME) that is a symlink.
symlinked_parent() {
    local dir="$TARGET_HOME/$1"
    dir=$(dirname "$dir")
    while [[ $dir != "$TARGET_HOME" && $dir != / && $dir != . ]]; do
        if [[ -L $dir ]]; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# restore_file <backup_dir> <rel>: put a backed-up file back in place (atomic rename).
restore_file() {
    local bdir=$1 rel=$2
    local from="$bdir/files/$rel" to="$TARGET_HOME/$rel" tmp
    [[ -e $from || -L $from ]] || return 1
    mkdir -p -- "$(dirname "$to")"
    tmp="$to.monolith-restore.$$"
    cp -a -- "$from" "$tmp" && mv -fT -- "$tmp" "$to"
}

# acquire_lock: refuse to run two mutating scripts at the same time.
acquire_lock() {
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0
    command -v flock >/dev/null 2>&1 || return 0
    exec 9>"$STATE_DIR/lock"
    flock -n 9
}

# short_path <path>: show the user's home as "~" (display only).
short_path() {
    local p=$1
    # shellcheck disable=SC2088  # a literal "~" is intended: it is only displayed
    [[ $p == "$TARGET_HOME"/* ]] && p="~${p#"$TARGET_HOME"}"
    printf '%s' "$p"
}

# has_shebang <file>: true if the file starts with "#!".
has_shebang() {
    [[ -f $1 ]] && [[ "$(head -c2 -- "$1" 2>/dev/null)" == '#!' ]]
}