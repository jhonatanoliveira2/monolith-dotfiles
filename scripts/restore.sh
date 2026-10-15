#!/usr/bin/env bash
# restore.sh - put back the original files saved by backup.sh / install.sh.
#
# Usage:
#   restore.sh --list                 list snapshots
#   restore.sh [--id ID] [options]    restore a snapshot (default: the latest one)
# Options:
#   --remove-new   also delete files that did not exist before the installation
#   --yes          do not ask for confirmation
#   --dry-run      show what would happen
#   --lang en|pt_BR  --no-color
# Before overwriting anything, the current state of those files is snapshotted again, so a
# restore can itself be undone.
# shellcheck disable=SC2034  # option/config variables are consumed by the sourced libraries
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

ID=latest REMOVE_NEW=0 DRY=0 LIST=0 OPT_YES=0

usage() {
    sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (( $# )); do
    case $1 in
        --id) ID=${2:?--id needs a value}; shift 2 ;;
        --id=*) ID=${1#*=}; shift ;;
        --remove-new) REMOVE_NEW=1; shift ;;
        --yes | -y) OPT_YES=1; shift ;;
        --dry-run | -n) DRY=1; shift ;;
        --list | -l) LIST=1; shift ;;
        --lang) MONOLITH_LANG=$(normalize_lang "${2:?}") || MONOLITH_LANG=en; shift 2 ;;
        --lang=*) MONOLITH_LANG=$(normalize_lang "${1#*=}") || MONOLITH_LANG=en; shift ;;
        --no-color) OPT_NO_COLOR=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done
export MONOLITH_LANG
ui_init
init_logging restore

if (( LIST )); then
    exec bash "$SCRIPT_DIR/backup.sh" --list --lang "$MONOLITH_LANG" ${OPT_NO_COLOR:+--no-color}
fi

[[ -d $BACKUP_ROOT ]] || { ui_err "$(t backup.none_found "$BACKUP_ROOT")"; exit 1; }
if [[ $ID == latest ]]; then
    ID=$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort | tail -n1)
fi
bdir="$BACKUP_ROOT/$ID"
[[ -n $ID && -f $bdir/manifest.tsv ]] || { ui_err "$(t restore.bad_id "$ID")"; exit 1; }

declare -a RESTORE=() NEWFILES=()
while IFS=$'\t' read -r status rel; do
    case $status in
        replace) RESTORE+=("$rel") ;;
        new) NEWFILES+=("$rel") ;;
    esac
done <"$bdir/manifest.tsv"

ui_info "$(t restore.snapshot "$ID")"
ui_kv "$(t restore.files_back)" "${#RESTORE[@]}"
(( REMOVE_NEW )) && ui_kv "$(t restore.files_remove)" "${#NEWFILES[@]}"

if (( DRY )); then
    ui_info "$(t restore.dry_run)"
    exit 0
fi
if (( ! OPT_YES )); then
    ui_confirm "$(t restore.confirm)" n || { ui_warn "$(t common.aborted)"; exit 3; }
fi

acquire_lock || { ui_err "$(t common.locked)"; exit 1; }

# snapshot the current state first, so the restore can be undone
plan=$(mktemp)
trap 'rm -f "$plan"' EXIT
for rel in "${RESTORE[@]}"; do
    [[ -e $TARGET_HOME/$rel || -L $TARGET_HOME/$rel ]] && printf 'replace\t%s\n' "$rel"
done >"$plan"
if [[ -s $plan ]]; then
    pre=$(bash "$SCRIPT_DIR/backup.sh" --plan "$plan" --porcelain --lang "$MONOLITH_LANG")
    ui_ok "$(t restore.pre_backup "$pre")"
fi

restored=0
for rel in "${RESTORE[@]}"; do
    if restore_file "$bdir" "$rel"; then
        restored=$(( restored + 1 ))
        log INFO "restored $rel"
    else
        ui_warn "$(t restore.missing_in_backup "$rel")"
    fi
done

removed=0
if (( REMOVE_NEW )); then
    for rel in "${NEWFILES[@]}"; do
        dst="$TARGET_HOME/$rel"
        [[ -e $dst || -L $dst ]] || continue
        rm -f -- "$dst"
        removed=$(( removed + 1 ))
        log INFO "removed $rel"
        d=$(dirname "$dst")
        while [[ $d != "$TARGET_HOME" && $d != / && $d == "$TARGET_HOME"/* ]]; do
            rmdir -- "$d" 2>/dev/null || break
            d=$(dirname "$d")
        done
    done
fi
ui_ok "$(t restore.done "$restored" "$removed")"
