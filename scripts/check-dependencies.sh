#!/usr/bin/env bash
# check-dependencies.sh - verify packages, runtime prerequisites and referenced files.
#
# Usage: check-dependencies.sh [options]
#   --section packages|advice|all   what to report (default: all)
#   --where repo|target             where "expected files" are looked up (default: target)
#   --list-missing[=required|optional|all]
#                                   machine output: "<source><TAB><package>" for missing packages
#   --strict                        exit 1 when a required package is missing
#   --lang en|pt_BR  --no-color  -h
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
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"

SECTION=all WHERE=target LIST_MISSING="" STRICT=0

usage() {
    sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (( $# )); do
    case $1 in
        --section) SECTION=${2:?}; shift 2 ;;
        --section=*) SECTION=${1#*=}; shift ;;
        --where) WHERE=${2:?}; shift 2 ;;
        --where=*) WHERE=${1#*=}; shift ;;
        --list-missing) LIST_MISSING=all; shift ;;
        --list-missing=*) LIST_MISSING=${1#*=}; shift ;;
        --strict) STRICT=1; shift ;;
        --lang) MONOLITH_LANG=$(normalize_lang "${2:?}") || MONOLITH_LANG=en; shift 2 ;;
        --lang=*) MONOLITH_LANG=$(normalize_lang "${1#*=}") || MONOLITH_LANG=en; shift ;;
        --no-color) OPT_NO_COLOR=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done
export MONOLITH_LANG
ui_init

# Files referenced by the configurations but possibly absent from the repository/system.
# Format: "<path relative to $HOME>|<english reason>"
EXPECTED_FILES=(
    ".config/quickshell/shell.qml|Quickshell entry point (bar, menus, notifications)"
    ".config/hypr/hyprlock-colors.conf|sourced by hypr/hyprlock.conf"
    ".config/hypr/scripts/password-cursor.sh|used by hypr/hyprlock.conf (cursor label)"
    ".config/hypr/scripts/now-playing.sh|used by hypr/hyprlock.conf (media label)"
    ".local/bin/wallpaper-menu|used by the SUPER+D binding"
    ".local/bin/monolith-theme|palette generator of Settings > Themes (wpgtk)"
    ".config/fish/conf.d/monolith-theme.fish|fish colours of Settings > Themes"
    ".config/hypr/rofi/wallpaper-menu.rasi|theme of wallpaper-menu"
    ".config/fastfetch/monolith.txt|MONOLITH logo of fastfetch/config.jsonc"
)
# Directories that must exist and contain at least one file.
EXPECTED_DIRS=()

MISSING_REQUIRED=0

# ---------------------------------------------------------------- machine output
if [[ -n $LIST_MISSING ]]; then
    scopes=(required optional)
    [[ $LIST_MISSING == required ]] && scopes=(required)
    [[ $LIST_MISSING == optional ]] && scopes=(optional)
    for scope in "${scopes[@]}"; do
        for source in official aur; do
            while IFS= read -r pkg; do
                [[ -n $pkg ]] || continue
                pkg_installed "$pkg" || printf '%s\t%s\t%s\n' "$source" "$scope" "$pkg"
            done < <(pkg_list "$source:$scope")
        done
    done
    exit 0
fi

# ---------------------------------------------------------------- packages
report_packages() {
    if (( ! PACMAN_AVAILABLE )); then
        ui_warn "$(t deps.no_pacman)"
        return 0
    fi
    local source scope pkg total missing desc
    for scope in required optional; do
        for source in official aur; do
            total=0 missing=0
            local -a lacking=()
            while IFS= read -r pkg; do
                [[ -n $pkg ]] || continue
                total=$(( total + 1 ))
                if ! pkg_installed "$pkg"; then
                    missing=$(( missing + 1 ))
                    lacking+=("$pkg")
                fi
            done < <(pkg_list "$source:$scope")
            (( total > 0 )) || continue
            if (( missing == 0 )); then
                ui_ok "$(t deps.group_ok "$source" "$scope" "$total")"
            else
                ui_warn "$(t deps.group_missing "$source" "$scope" "$missing" "$total")"
                for pkg in "${lacking[@]}"; do
                    desc=$(pkg_desc "$pkg")
                    ui_dim "$pkg  $G_DOT  $desc"
                done
                [[ $scope == required ]] && MISSING_REQUIRED=$(( MISSING_REQUIRED + missing ))
            fi
        done
    done
    local manual
    manual=$(pkg_list manual | tr '\n' ' ')
    [[ -z $manual ]] || ui_info "$(t deps.manual_list "$manual")"
}

# ---------------------------------------------------------------- advice
report_advice() {
    local root entry rel why found=0 d
    if [[ $WHERE == repo ]]; then
        root=$MONOLITH_CONFIGS_DIR
        ui_info "$(t deps.files_where_repo)"
    else
        root=$TARGET_HOME
        ui_info "$(t deps.files_where_target)"
    fi
    for entry in "${EXPECTED_FILES[@]}"; do
        rel=${entry%%|*} why=${entry#*|}
        if [[ -e $root/$rel || -L $root/$rel ]]; then
            continue
        fi
        found=1
        ui_warn "$(t deps.file_missing "$rel")"
        ui_dim "$why"
    done
    for entry in "${EXPECTED_DIRS[@]}"; do
        rel=${entry%%|*} why=${entry#*|}
        d=$root/$rel
        if [[ -d $d ]] && [[ -n $(find "$d" -type f -print -quit 2>/dev/null) ]]; then
            continue
        fi
        found=1
        ui_warn "$(t deps.file_missing "$rel/")"
        ui_dim "$why"
    done
    (( found )) || ui_ok "$(t deps.files_ok)"

    # the session must start Quickshell instead of Waybar (informational)
    if [[ $WHERE == target && -d $root/.config/hypr ]]; then
        if grep -rqI --include='*.lua' --include='*.conf' -E '(^|[^[:alnum:]_-])waybar([^[:alnum:]_-]|$)' "$root/.config/hypr" 2>/dev/null; then
            ui_warn "$(t deps.waybar_autostart)"
        elif ! grep -rqI --include='*.lua' --include='*.conf' -E '(^|[^[:alnum:]_-])(quickshell|qs)([^[:alnum:]_-]|$)' "$root/.config/hypr" 2>/dev/null; then
            ui_info "$(t deps.qs_missing)"
        fi
        if grep -rqI --include='*.lua' --include='*.conf' -E '(^|[^[:alnum:]_-])swaync([^[:alnum:]_-]|$)' "$root/.config/hypr" 2>/dev/null; then
            ui_info "$(t deps.swaync_conflict)"
        fi
    fi

    # runtime advisories (informational, never fatal)
    if command -v locale >/dev/null 2>&1 && ! locale -a 2>/dev/null | grep -qiE '^pt_BR\.utf-?8$'; then
        ui_warn "$(t deps.locale_missing)"
    fi
    local login_shell=${SHELL:-}
    if [[ -n $login_shell && ${login_shell##*/} != fish ]] && command -v fish >/dev/null 2>&1; then
        ui_info "$(t deps.shell_note "${login_shell##*/}")"
    fi
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        systemctl is-enabled NetworkManager.service >/dev/null 2>&1 || ui_info "$(t deps.service_note NetworkManager.service)"
        systemctl is-enabled bluetooth.service >/dev/null 2>&1 || ui_info "$(t deps.service_note bluetooth.service)"
    fi
}

case $SECTION in
    packages) report_packages ;;
    advice) report_advice ;;
    all) report_packages; report_advice ;;
    *) echo "unknown section: $SECTION" >&2; exit 1 ;;
esac

if (( STRICT && MISSING_REQUIRED > 0 )); then exit 1; fi
exit 0