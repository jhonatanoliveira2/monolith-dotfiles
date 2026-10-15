#!/usr/bin/env bash
# backup.sh - snapshot the files MONOLITH is about to replace (or list existing snapshots).
#
# Usage:
#   backup.sh                      snapshot every managed file that already exists in $HOME
#   backup.sh --plan FILE          snapshot according to a plan (TSV: "replace|new<TAB>relative/path")
#   backup.sh --list               list existing snapshots
# Options: --dry-run  --porcelain (print only the snapshot directory)  --lang en|pt_BR  --no-color
#
# A snapshot lives in $BACKUP_ROOT/<timestamp>/ with:
#   files/<relative path>   original copies (symlinks are preserved as symlinks)
#   manifest.tsv            "replace<TAB>path" (backed up) and "new<TAB>path" (did not exist before)
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

PLAN_FILE="" DRY=0 PORCELAIN=0 LIST=0

usage() {
    sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (( $# )); do
    case $1 in
        --plan) PLAN_FILE=${2:?--plan needs a file}; shift 2 ;;
        --plan=*) PLAN_FILE=${1#*=}; shift ;;
        --dry-run | -n) DRY=1; shift ;;
        --porcelain) PORCELAIN=1; shift ;;
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
init_logging backup

say() { (( PORCELAIN )) || "$@"; }

list_backups() {
    local d n count=0
    if [[ ! -d $BACKUP_ROOT ]]; then
        ui_info "$(t backup.none_found "$BACKUP_ROOT")"
        return 0
    fi
    ui_info "$(t backup.list_header "$BACKUP_ROOT")"
    while IFS= read -r d; do
        n=$(grep -c '^replace' "$d/manifest.tsv" 2>/dev/null || true)
        ui_kv "$(basename "$d")" "$(t backup.list_entry "${n:-0}")"
        count=$(( count + 1 ))
    done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)
    (( count > 0 )) || ui_info "$(t backup.none_found "$BACKUP_ROOT")"
}

if (( LIST )); then
    list_backups
    exit 0
fi

# ---- build the plan (status<TAB>relative path) -------------------------------------------
declare -a PLAN_REPLACE=() PLAN_NEW=()
if [[ -n $PLAN_FILE ]]; then
    [[ -r $PLAN_FILE ]] || { ui_err "$(t backup.plan_unreadable "$PLAN_FILE")"; exit 1; }
    while IFS=$'\t' read -r status rel; do
        case $status in
            replace) PLAN_REPLACE+=("$rel") ;;
            new) PLAN_NEW+=("$rel") ;;
        esac
    done <"$PLAN_FILE"
else
    list_managed_files
    for rel in "${MANAGED[@]}"; do
        if [[ -e $TARGET_HOME/$rel || -L $TARGET_HOME/$rel ]]; then PLAN_REPLACE+=("$rel"); else PLAN_NEW+=("$rel"); fi
    done
fi

if (( ${#PLAN_REPLACE[@]} + ${#PLAN_NEW[@]} == 0 )); then
    say ui_ok "$(t backup.nothing)"
    exit 0
fi

if (( DRY )); then
    say ui_info "$(t backup.dry_run "${#PLAN_REPLACE[@]}" "$BACKUP_ROOT")"
    exit 0
fi

# ---- create the snapshot ------------------------------------------------------------------
umask 077
mkdir -p "$BACKUP_ROOT"
stamp=$(date +%Y%m%d-%H%M%S)
bdir="$BACKUP_ROOT/$stamp"
n=1
while [[ -e $bdir ]]; do bdir="$BACKUP_ROOT/$stamp-$n"; n=$(( n + 1 )); done
mkdir -p "$bdir/files"
log INFO "creating snapshot $bdir (${#PLAN_REPLACE[@]} files to back up, ${#PLAN_NEW[@]} new)"

fail() {
    log ERROR "$1"
    rm -rf -- "$bdir"
    ui_err "$(t backup.failed "$1")"
    exit 1
}

for rel in "${PLAN_REPLACE[@]}"; do
    src="$TARGET_HOME/$rel"
    dst="$bdir/files/$rel"
    mkdir -p -- "$(dirname "$dst")" || fail "mkdir for $rel"
    cp -a -- "$src" "$dst" || fail "copy $rel"
    if [[ ! -L $src ]] && ! cmp -s -- "$src" "$dst"; then fail "verify $rel"; fi
done

{
    printf '# monolith-dotfiles backup manifest v1\n'
    printf '# created\t%s\n' "$(date '+%F %T')"
    printf '# installer\t%s\n' "$MONOLITH_VERSION"
    for rel in "${PLAN_REPLACE[@]}"; do printf 'replace\t%s\n' "$rel"; done
    for rel in "${PLAN_NEW[@]}"; do printf 'new\t%s\n' "$rel"; done
} >"$bdir/manifest.tsv" || fail "write manifest"

if (( PORCELAIN )); then
    printf '%s\n' "$bdir"
else
    ui_ok "$(t backup.created "${#PLAN_REPLACE[@]}" "$bdir")"
fi
