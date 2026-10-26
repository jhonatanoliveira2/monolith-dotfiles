#!/usr/bin/env bash
# install.sh - MONOLITH Dotfiles installer (entry point).
#
# Flow: language -> pre-flight -> dependency report -> packages -> plan -> backup -> deploy -> verify.
# Nothing in $HOME is touched before the backup succeeds; if deployment fails midway, every file
# already written is rolled back. Running it again is safe (identical files are skipped).
#
# Usage: ./scripts/install.sh [options]      (see --help)
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

TOTAL_STEPS=7
OPT_LANG="" OPT_YES=0 OPT_DRY=0 OPT_NO_DEPS=0 OPT_OPTIONAL=0 OPT_NO_AUR=0
OPT_AUR_HELPER="" OPT_NO_COLOR=0 OPT_NO_CLEAR=0 OPT_FORCE_SYMLINKS=0

# plan + journal (used for rollback)
declare -a PLAN_NEW=() PLAN_DIFF=() PLAN_SAME=()
declare -a JOURNAL_NEW=() JOURNAL_DIFF=() CREATED_DIRS=() WARNINGS=()
declare -A IS_DIFF=()
BACKUP_DIR="" DEPLOY_STARTED=0 ROLLED_BACK=0 TMP_DIR=""

usage() {
    cat <<USAGE
MONOLITH Dotfiles installer v$MONOLITH_VERSION

Usage: ./scripts/install.sh [options]

  --lang en|pt_BR      choose the interface language (skips the language menu)
  -y, --yes            non-interactive: accept defaults, never prompt
  -n, --dry-run        show what would be done without changing anything
  --no-deps            do not install packages
  --with-optional      also install optional packages (packages.txt)
  --no-aur             never use an AUR helper (print the manual commands instead)
  --aur-helper NAME    use this AUR helper (default: paru, then yay)
  --force-symlinks     allow writing through symlinked directories under \$HOME
  --no-color           disable colours        --no-clear   do not clear the screen
  -h, --help           this help              --version    print the version

Environment: MONOLITH_LANG=en|pt_BR (same as --lang), MONOLITH_TARGET_HOME (deploy somewhere else; tests).
USAGE
}

parse_args() {
    while (( $# )); do
        case $1 in
            --lang) OPT_LANG=${2:?--lang needs a value}; shift 2 ;;
            --lang=*) OPT_LANG=${1#*=}; shift ;;
            -y | --yes) OPT_YES=1; shift ;;
            -n | --dry-run) OPT_DRY=1; shift ;;
            --no-deps) OPT_NO_DEPS=1; shift ;;
            --with-optional) OPT_OPTIONAL=1; shift ;;
            --no-aur) OPT_NO_AUR=1; shift ;;
            --aur-helper) OPT_AUR_HELPER=${2:?}; shift 2 ;;
            --aur-helper=*) OPT_AUR_HELPER=${1#*=}; shift ;;
            --force-symlinks) OPT_FORCE_SYMLINKS=1; shift ;;
            --no-color) OPT_NO_COLOR=1; shift ;;
            --no-clear) OPT_NO_CLEAR=1; shift ;;
            --version) echo "$MONOLITH_VERSION"; exit 0 ;;
            -h | --help) usage; exit 0 ;;
            *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
        esac
    done
}

# ----------------------------------------------------------------------------- helpers
warn_later() { WARNINGS+=("$1"); log WARN "$1"; }

die() {
    local code=${2:-1}
    ui_err "$1"
    log ERROR "$1"
    exit "$code"
}

rollback() {
    (( ROLLED_BACK )) && return 0
    ROLLED_BACK=1
    (( DEPLOY_STARTED )) || return 0
    ui_warn "$(t rollback.start)"
    log WARN "rolling back deployment"
    local rel i
    for rel in ${JOURNAL_NEW[@]+"${JOURNAL_NEW[@]}"}; do
        rm -f -- "$TARGET_HOME/$rel" 2>/dev/null || true
    done
    for rel in ${JOURNAL_DIFF[@]+"${JOURNAL_DIFF[@]}"}; do
        restore_file "$BACKUP_DIR" "$rel" 2>/dev/null || ui_err "$(t rollback.file_failed "$rel")"
    done
    for (( i = ${#CREATED_DIRS[@]} - 1; i >= 0; i-- )); do
        rmdir -- "${CREATED_DIRS[i]}" 2>/dev/null || true
    done
    ui_ok "$(t rollback.done)"
}

on_error() {
    local code=$1 line=$2
    trap - ERR
    log ERROR "unexpected failure (exit $code) at line $line"
    ui_err "$(t common.unexpected "$line")"
    rollback
    ui_dim "$(t common.log_hint "$LOG_FILE")"
    exit "$code"
}

on_exit() {
    [[ -n $TMP_DIR && -d $TMP_DIR ]] && rm -rf -- "$TMP_DIR"
    return 0
}

on_signal() {
    trap - INT TERM
    printf '\n'
    ui_warn "$(t common.interrupted)"
    rollback
    exit 130
}

# ----------------------------------------------------------------------------- steps
select_language() {
    local suggested
    suggested=$(detect_system_lang)
    if [[ -n $OPT_LANG ]]; then
        MONOLITH_LANG=$(normalize_lang "$OPT_LANG") || { echo "unsupported language: $OPT_LANG (use en or pt_BR)" >&2; exit 1; }
    elif [[ -n ${MONOLITH_LANG_USER-} ]] && normalize_lang "$MONOLITH_LANG_USER" >/dev/null; then
        MONOLITH_LANG=$(normalize_lang "$MONOLITH_LANG_USER")
    elif (( UI_INTERACTIVE && ! OPT_YES )); then
        MONOLITH_LANG=$(ui_choose_language "$suggested")
    else
        MONOLITH_LANG=$suggested
    fi
    export MONOLITH_LANG
    log INFO "language: $MONOLITH_LANG"
}

welcome() {
    ui_clear
    ui_banner
    ui_panel "$(t welcome.title)" \
        "" \
        "  $(t welcome.intro)" \
        "" \
        "   1. $(t step.preflight)" \
        "   2. $(t step.deps)" \
        "   3. $(t step.packages)" \
        "   4. $(t step.plan)" \
        "   5. $(t step.backup)" \
        "   6. $(t step.deploy)" \
        "   7. $(t step.verify)" \
        ""
    printf '\n'
    if (( OPT_DRY )); then ui_info "$(t welcome.dry_run)"; fi
    ui_dim "$(t welcome.safe)"
    printf '\n'
}

step_preflight() {
    ui_step 1 "$TOTAL_STEPS" "$(t step.preflight)"
    if (( EUID == 0 )); then die "$(t preflight.no_root)" 4; fi
    if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
        die "$(t preflight.bash_old "$BASH_VERSION")" 4
    fi
    ui_ok "$(t preflight.user "$(id -un)")"

    if [[ -r /etc/os-release ]] && grep -qiE '^(ID|ID_LIKE)=.*(arch)' /etc/os-release; then
        ui_ok "$(t preflight.arch)"
    elif (( PACMAN_AVAILABLE )); then
        ui_ok "$(t preflight.arch)"
    else
        warn_later "$(t preflight.not_arch)"
        ui_warn "$(t preflight.not_arch)"
    fi

    [[ -d $TARGET_HOME && -w $TARGET_HOME ]] || die "$(t preflight.home_not_writable "$TARGET_HOME")" 4
    [[ $TARGET_HOME != / ]] || die "$(t preflight.home_not_writable "$TARGET_HOME")" 4

    list_managed_files
    if (( ${#MANAGED[@]} == 0 )); then
        ui_err "$(t preflight.no_configs "$MONOLITH_CONFIGS_DIR")"
        ui_dim "$(t preflight.no_configs_hint)"
        exit 2
    fi
    ui_ok "$(t preflight.configs "${#MANAGED[@]}")"

    # refuse to write through symlinked directories unless explicitly allowed
    local rel link
    local -A seen=()
    for rel in "${MANAGED[@]}"; do
        if link=$(symlinked_parent "$rel"); then
            [[ -n ${seen[$link]-} ]] && continue
            seen[$link]=1
            if (( OPT_FORCE_SYMLINKS )); then
                ui_warn "$(t preflight.symlink_allowed "$link")"
            else
                ui_err "$(t preflight.symlink_dir "$link")"
                ui_dim "$(t preflight.symlink_hint)"
                exit 4
            fi
        fi
    done

    if (( ! OPT_DRY )); then
        acquire_lock || die "$(t common.locked)" 1
    fi
    ui_ok "$(t preflight.log "$(short_path "$LOG_FILE")")"
}

step_dependency_report() {
    ui_step 2 "$TOTAL_STEPS" "$(t step.deps)"
    bash "$SCRIPT_DIR/check-dependencies.sh" --section packages ${OPT_NO_COLOR:+--no-color} || true
    printf '\n'
    bash "$SCRIPT_DIR/check-dependencies.sh" --section advice --where repo ${OPT_NO_COLOR:+--no-color} || true
}

# run a command (or just print it in dry-run mode)
run_cmd() {
    log INFO "run: $*"
    if (( OPT_DRY )); then
        ui_dim "\$ $*"
        return 0
    fi
    "$@"
}

step_packages() {
    ui_step 3 "$TOTAL_STEPS" "$(t step.packages)"
    if (( OPT_NO_DEPS )); then
        ui_info "$(t pkg.skipped_flag)"
        return 0
    fi
    if (( ! PACMAN_AVAILABLE )); then
        warn_later "$(t pkg.no_pacman)"
        ui_warn "$(t pkg.no_pacman)"
        return 0
    fi

    local scope_arg=required
    if (( OPT_OPTIONAL )); then
        scope_arg=all
    elif (( ! OPT_YES && UI_INTERACTIVE )) && [[ -n $(bash "$SCRIPT_DIR/check-dependencies.sh" --list-missing=optional) ]]; then
        ui_confirm "$(t pkg.ask_optional)" n && scope_arg=all
    fi

    local -a official=() aur=()
    local source pkg
    while IFS=$'\t' read -r source _scope pkg; do
        [[ -n $pkg ]] || continue
        if [[ $source == official ]]; then
            if pkg_in_repos "$pkg"; then official+=("$pkg"); else
                log INFO "$pkg not in official repos, moving to the AUR list"
                aur+=("$pkg")
            fi
        else
            # AUR entries that already live in the official repositories are installed with pacman
            if pkg_in_repos "$pkg"; then official+=("$pkg"); else aur+=("$pkg"); fi
        fi
    done < <(bash "$SCRIPT_DIR/check-dependencies.sh" --list-missing="$scope_arg")

    if (( ${#official[@]} == 0 && ${#aur[@]} == 0 )); then
        ui_ok "$(t pkg.all_present)"
        return 0
    fi

    if (( ${#official[@]} > 0 )); then
        ui_info "$(t pkg.official_list "${#official[@]}")"
        ui_dim "${official[*]}"
        if ! command -v sudo >/dev/null 2>&1; then
            warn_later "$(t pkg.no_sudo)"
            ui_warn "$(t pkg.no_sudo)"
            ui_dim "sudo pacman -S --needed ${official[*]}"
        elif ui_confirm "$(t pkg.confirm_install)" y; then
            local -a cmd=(sudo pacman -S --needed)
            (( OPT_YES )) && cmd+=(--noconfirm)
            if ! run_cmd "${cmd[@]}" "${official[@]}"; then
                die "$(t pkg.pacman_failed)" 5
            fi
            ui_ok "$(t pkg.official_done)"
        else
            warn_later "$(t pkg.declined)"
        fi
    fi

    if (( ${#aur[@]} > 0 )); then
        ui_info "$(t pkg.aur_list "${#aur[@]}")"
        ui_dim "${aur[*]}"
        local helper=""
        (( OPT_NO_AUR )) || helper=$(aur_helper "$OPT_AUR_HELPER") || helper=""
        if [[ -z $helper ]]; then
            warn_later "$(t pkg.no_aur_helper)"
            ui_warn "$(t pkg.no_aur_helper)"
            ui_dim "paru -S --needed ${aur[*]}"
        elif ui_confirm "$(t pkg.confirm_aur "$helper")" y; then
            local -a acmd=("$helper" -S --needed)
            (( OPT_YES )) && acmd+=(--noconfirm)
            if run_cmd "${acmd[@]}" "${aur[@]}"; then
                ui_ok "$(t pkg.aur_done)"
            else
                warn_later "$(t pkg.aur_failed)"
                ui_warn "$(t pkg.aur_failed)"
            fi
        else
            warn_later "$(t pkg.declined)"
        fi
    fi
}

step_plan() {
    ui_step 4 "$TOTAL_STEPS" "$(t step.plan)"
    local rel kind i=0 total=${#MANAGED[@]}
    for rel in "${MANAGED[@]}"; do
        kind=$(classify_file "$rel")
        case $kind in
            new) PLAN_NEW+=("$rel") ;;
            diff) PLAN_DIFF+=("$rel"); IS_DIFF[$rel]=1 ;;
            same) PLAN_SAME+=("$rel") ;;
            conflict) die "$(t plan.conflict "$TARGET_HOME/$rel")" 4 ;;
        esac
        i=$(( i + 1 ))
        ui_progress "$i" "$total" "$rel"
    done
    ui_progress_end
    ui_kv "$(t plan.new)" "${#PLAN_NEW[@]}"
    ui_kv "$(t plan.changed)" "${#PLAN_DIFF[@]}"
    ui_kv "$(t plan.same)" "${#PLAN_SAME[@]}"
    log INFO "plan: new=${#PLAN_NEW[@]} changed=${#PLAN_DIFF[@]} same=${#PLAN_SAME[@]}"

    if (( ${#PLAN_DIFF[@]} > 0 )); then
        printf '\n'
        ui_info "$(t plan.will_replace)"
        local shown=0
        for rel in "${PLAN_DIFF[@]}"; do
            (( shown < 10 )) || break
            # shellcheck disable=SC2088  # a literal "~/" is intended: it is only displayed
            ui_dim "~/$rel"
            shown=$(( shown + 1 ))
        done
        (( ${#PLAN_DIFF[@]} <= 10 )) || ui_dim "$(t plan.and_more $(( ${#PLAN_DIFF[@]} - 10 )))"
    fi
}

step_backup() {
    ui_step 5 "$TOTAL_STEPS" "$(t step.backup)"
    if (( ${#PLAN_NEW[@]} + ${#PLAN_DIFF[@]} == 0 )); then
        ui_ok "$(t backup.not_needed)"
        return 0
    fi
    if (( ${#PLAN_DIFF[@]} > 0 && ! OPT_DRY )); then
        ui_confirm "$(t backup.confirm "${#PLAN_DIFF[@]}")" y || { ui_warn "$(t common.aborted)"; exit 3; }
    fi
    TMP_DIR=$(mktemp -d)
    local plan="$TMP_DIR/plan.tsv" rel
    {
        for rel in "${PLAN_DIFF[@]}"; do printf 'replace\t%s\n' "$rel"; done
        for rel in "${PLAN_NEW[@]}"; do printf 'new\t%s\n' "$rel"; done
    } >"$plan"
    if (( OPT_DRY )); then
        ui_info "$(t backup.dry_run "${#PLAN_DIFF[@]}" "$(short_path "$BACKUP_ROOT")")"
        return 0
    fi
    BACKUP_DIR=$(bash "$SCRIPT_DIR/backup.sh" --plan "$plan" --porcelain --lang "$MONOLITH_LANG") \
        || die "$(t backup.failed_abort)" 6
    ui_ok "$(t backup.created "${#PLAN_DIFF[@]}" "$(short_path "$BACKUP_DIR")")"
    log INFO "backup directory: $BACKUP_DIR"
}

# apply_one <rel>: write one file atomically (temp file + rename), recording the journal.
apply_one() {
    local rel=$1 kind=$2 src="$MONOLITH_CONFIGS_DIR/$1" dst="$TARGET_HOME/$1" dir tmp d
    dir=$(dirname "$dst")
    if [[ ! -d $dir ]]; then
        d=$dir
        local -a missing=()
        while [[ ! -d $d && $d != / ]]; do
            missing+=("$d")
            d=$(dirname "$d")
        done
        mkdir -p -- "$dir" || return 1
        for d in "${missing[@]}"; do CREATED_DIRS+=("$d"); done
    fi
    tmp="$dst.monolith-tmp.$$"
    if [[ -L $src ]]; then
        ln -s -- "$(readlink "$src")" "$tmp" || return 1
    else
        cp -p -- "$src" "$tmp" || { rm -f -- "$tmp"; return 1; }
    fi
    mv -fT -- "$tmp" "$dst" || { rm -f -- "$tmp"; return 1; }
    if [[ $kind == new ]]; then JOURNAL_NEW+=("$rel"); else JOURNAL_DIFF+=("$rel"); fi
    log INFO "deployed ($kind): $rel"
}

step_deploy() {
    ui_step 6 "$TOTAL_STEPS" "$(t step.deploy)"
    local total=$(( ${#PLAN_NEW[@]} + ${#PLAN_DIFF[@]} )) i=0 rel
    if (( total == 0 )); then
        ui_ok "$(t deploy.nothing)"
        return 0
    fi
    if (( OPT_DRY )); then
        ui_info "$(t deploy.dry_run "$total")"
        return 0
    fi
    DEPLOY_STARTED=1
    for rel in "${PLAN_DIFF[@]}" "${PLAN_NEW[@]}"; do
        if [[ ${MONOLITH_TEST_FAIL_AT-} == "$(( i + 1 ))" ]]; then
            log ERROR "simulated failure (MONOLITH_TEST_FAIL_AT=$MONOLITH_TEST_FAIL_AT)"
            ui_progress_end
            ui_err "$(t deploy.failed "$rel")"
            rollback
            exit 7
        fi
        local kind=new
        [[ -n ${IS_DIFF[$rel]-} ]] && kind="diff"
        if ! apply_one "$rel" "$kind"; then
            ui_progress_end
            ui_err "$(t deploy.failed "$rel")"
            rollback
            exit 7
        fi
        i=$(( i + 1 ))
        ui_progress "$i" "$total" "$rel"
    done
    ui_progress_end
    ui_ok "$(t deploy.done "$total")"
    # scripts keep their executable bit even when the repository was extracted from a zip
    local fixed=0
    for rel in "${MANAGED[@]}"; do
        if has_shebang "$MONOLITH_CONFIGS_DIR/$rel" && [[ ! -x $TARGET_HOME/$rel ]]; then
            chmod u+x -- "$TARGET_HOME/$rel" && fixed=$(( fixed + 1 ))
        fi
    done
    (( fixed == 0 )) || ui_ok "$(t deploy.exec_fixed "$fixed")"
}

# Folders that must exist after the installation (created empty when missing; content is never touched).
USER_DIRS=(Pictures/Wallpapers Videos/wallpaper-live .config/nwg-look .config/wpg)

ensure_user_dirs() {
    local d
    for d in "${USER_DIRS[@]}"; do
        [[ -d $TARGET_HOME/$d ]] && continue
        if (( OPT_DRY )); then
            ui_info "$(t dirs.would_create "$d")"
        elif mkdir -p -- "$TARGET_HOME/$d"; then
            ui_ok "$(t dirs.created "$d")"
            log INFO "created folder: $d"
        fi
    done
}

# Copy the wallpapers shipped in wallpapers/{static,live} into the folders used by wallpaper-menu.
# An existing file with the same name is never overwritten.
install_wallpapers() {
    local root=$MONOLITH_WALLPAPERS_DIR pair sub dest f name tmp
    [[ -d $root ]] || return 0
    for pair in "static:Pictures/Wallpapers" "live:Videos/wallpaper-live"; do
        sub=${pair%%:*}
        dest=${pair#*:}
        [[ -d $root/$sub ]] || continue
        while IFS= read -r -d '' f; do
            name=${f##*/}
            if [[ -e $TARGET_HOME/$dest/$name ]]; then
                cmp -s -- "$f" "$TARGET_HOME/$dest/$name" || ui_dim "$(t wallpapers.kept "$dest/$name")"
                continue
            fi
            if (( OPT_DRY )); then
                ui_info "$(t wallpapers.would_copy "$dest/$name")"
                continue
            fi
            mkdir -p -- "$TARGET_HOME/$dest"
            tmp="$TARGET_HOME/$dest/.$name.monolith-tmp.$$"
            if cp -p -- "$f" "$tmp" && mv -f -- "$tmp" "$TARGET_HOME/$dest/$name"; then
                ui_ok "$(t wallpapers.copied "$dest/$name")"
                log INFO "wallpaper copied: $dest/$name"
            else
                rm -f -- "$tmp"
                warn_later "$(t wallpapers.failed "$name")"
            fi
        done < <(find "$root/$sub" -maxdepth 1 -type f ! -name '.gitkeep' -print0 | LC_ALL=C sort -z)
    done
}

# True when deploying to the real home (gsettings and the running session are per-user).
# MONOLITH_APPLY_GSETTINGS=1 lets the tests exercise these steps against fixtures.
real_session() { [[ -z ${MONOLITH_TARGET_HOME-} || ${MONOLITH_APPLY_GSETTINGS-0} == 1 ]]; }

# Quickshell replaces Waybar: check the binary and, in an interactive Wayland session, offer to switch now.
configure_quickshell() {
    [[ -f $TARGET_HOME/.config/quickshell/shell.qml ]] || return 0
    ui_ok "$(t shell.ready)"
    if ! command -v quickshell >/dev/null 2>&1; then
        warn_later "$(t shell.no_binary)"
        return 0
    fi
    real_session || return 0
    # Quickshell hot-reloads each file as it is copied: an intermediate state (a new file not there yet)
    # can stay loaded, so finish with one full reload of the deployed tree.
    if (( ! OPT_DRY )) && pgrep -x quickshell >/dev/null 2>&1 && command -v qs >/dev/null 2>&1; then
        qs ipc call shell reload >/dev/null 2>&1 || true
    fi
    if (( ! OPT_DRY && ! OPT_YES && UI_INTERACTIVE )) && [[ -n ${WAYLAND_DISPLAY-} ]] && pgrep -x waybar >/dev/null 2>&1; then
        if ui_confirm "$(t shell.ask_switch)" n; then
            pkill -x waybar 2>/dev/null
            setsid -f quickshell >/dev/null 2>&1
            ui_ok "$(t shell.started)"
        fi
    fi
}

# Materia-dark is what makes the transparency in gtk-4.0/gtk.css work (Nautilus).
# Skipped when deploying to another home (MONOLITH_TARGET_HOME), because gsettings is per-user.
apply_gtk_theme() {
    local schema=org.gnome.desktop.interface pair key want cur
    local -a runner=()
    real_session || return 0
    if ! command -v gsettings >/dev/null 2>&1; then
        warn_later "$(t gtk.no_gsettings)"
        return 0
    fi
    # outside a graphical session there is no D-Bus session: use a temporary one so dconf can persist it
    if [[ -z ${DBUS_SESSION_BUS_ADDRESS-} ]] && command -v dbus-run-session >/dev/null 2>&1; then
        runner=(dbus-run-session --)
    fi
    local changed=0
    for pair in "gtk-theme:Materia-dark" "color-scheme:prefer-dark"; do
        key=${pair%%:*}
        want=${pair#*:}
        cur=$("${runner[@]}" gsettings get "$schema" "$key" 2>/dev/null) || cur=""
        [[ $cur == "'$want'" ]] && continue
        changed=1
        (( OPT_DRY )) && continue
        if ! "${runner[@]}" gsettings set "$schema" "$key" "$want" >>"$LOG_FILE" 2>&1; then
            warn_later "$(t gtk.failed)"
            return 0
        fi
        log INFO "gsettings $schema $key = $want"
    done
    if (( ! changed )); then
        ui_ok "$(t gtk.already)"
    elif (( OPT_DRY )); then
        ui_info "$(t gtk.would_apply)"
    else
        ui_ok "$(t gtk.applied)"
    fi
}

step_verify() {
    ui_step 7 "$TOTAL_STEPS" "$(t step.verify)"
    if (( OPT_DRY )); then
        ui_info "$(t verify.dry_run)"
        ensure_user_dirs
        install_wallpapers
        apply_gtk_theme
        configure_quickshell
        return 0
    fi
    local rel bad=0 ok=0
    for rel in "${MANAGED[@]}"; do
        if [[ -L $MONOLITH_CONFIGS_DIR/$rel ]]; then
            [[ -L $TARGET_HOME/$rel ]] && ok=$(( ok + 1 )) || bad=$(( bad + 1 ))
        elif cmp -s -- "$MONOLITH_CONFIGS_DIR/$rel" "$TARGET_HOME/$rel"; then
            ok=$(( ok + 1 ))
        else
            bad=$(( bad + 1 ))
            ui_err "$(t verify.mismatch "$rel")"
        fi
    done
    if (( bad > 0 )); then
        warn_later "$(t verify.failed "$bad")"
        return 0
    fi
    ui_ok "$(t verify.ok "$ok")"
    ensure_user_dirs
    install_wallpapers
    apply_gtk_theme
    configure_quickshell
    printf '\n'
    bash "$SCRIPT_DIR/check-dependencies.sh" --section advice --where target ${OPT_NO_COLOR:+--no-color} || true
}

summary() {
    local -a lines=()
    lines+=("")
    if (( OPT_DRY )); then
        lines+=("  $(t summary.dry_run)")
    else
        lines+=("  $(t summary.deployed "${#PLAN_NEW[@]}" "${#PLAN_DIFF[@]}" "${#PLAN_SAME[@]}")")
    fi
    [[ -z $BACKUP_DIR ]] || lines+=("  $(t summary.backup "$(short_path "$BACKUP_DIR")")")
    lines+=("  $(t summary.log "$(short_path "$LOG_FILE")")")
    if (( ${#WARNINGS[@]} > 0 )); then
        lines+=("" "  $(t summary.warnings "${#WARNINGS[@]}")")
    fi
    lines+=("" "  $(t summary.next)" "   - $(t summary.next1)" "   - $(t summary.next2)" "   - $(t summary.next3)" "")
    printf '\n'
    ui_panel "$(t summary.title)" "${lines[@]}"
    printf '\n'
    if (( ${#WARNINGS[@]} > 0 )); then
        local w
        for w in "${WARNINGS[@]}"; do ui_warn "$w"; done
        printf '\n'
    fi
}

main() {
    parse_args "$@"
    ui_init
    init_logging install
    log INFO "MONOLITH installer $MONOLITH_VERSION started (dry_run=$OPT_DRY)"

    if (( ! UI_INTERACTIVE && ! OPT_YES )); then
        # no terminal to ask questions on: refuse to guess
        MONOLITH_LANG=${OPT_LANG:+$(normalize_lang "$OPT_LANG" || echo en)}
        MONOLITH_LANG=${MONOLITH_LANG:-$(detect_system_lang)}
        export MONOLITH_LANG
        die "$(t common.need_yes)" 1
    fi

    trap 'on_error $? $LINENO' ERR
    trap on_exit EXIT
    trap on_signal INT TERM

    select_language
    welcome
    if (( UI_INTERACTIVE && ! OPT_YES )); then
        ui_confirm "$(t welcome.continue)" y || { ui_warn "$(t common.aborted)"; exit 3; }
    fi

    step_preflight
    step_dependency_report
    step_packages
    step_plan
    step_backup
    step_deploy
    step_verify
    summary
    log INFO "finished"
}

main "$@"