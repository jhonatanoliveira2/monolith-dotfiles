#!/usr/bin/env bash
# test-installer.sh - self-contained tests for the installer scripts.
# They run against throw-away fixtures (never against your real ~/.config) and need no pacman.
# Usage: bash tests/test-installer.sh        (must NOT be run as root)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0 FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if (( EUID == 0 )); then echo "run the tests as a regular user" >&2; exit 1; fi

ok() { PASS=$(( PASS + 1 )); printf '  ok    %s\n' "$1"; }
ko() { FAIL=$(( FAIL + 1 )); printf '  FAIL  %s\n' "$1"; }
check() { # check <description> <command...>
    local d=$1
    shift
    if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi
}

new_env() { # new_env <name>: fresh fixtures + empty home
    local n=$1
    CUR_ENV=$n
    export MONOLITH_TARGET_HOME="$TMP/$n/home"
    export MONOLITH_CONFIGS_DIR="$TMP/$n/configs"
    unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME MONOLITH_TEST_FAIL_AT
    mkdir -p "$MONOLITH_TARGET_HOME" "$MONOLITH_CONFIGS_DIR/.config/app/dir with space" \
        "$MONOLITH_CONFIGS_DIR/.config/other" "$MONOLITH_CONFIGS_DIR/.local/bin"
    printf 'key = value\n' >"$MONOLITH_CONFIGS_DIR/.config/app/main.conf"
    printf '#!/bin/bash\necho hi\n' >"$MONOLITH_CONFIGS_DIR/.config/app/run.sh"
    chmod 644 "$MONOLITH_CONFIGS_DIR/.config/app/run.sh"       # simulates a zip without the exec bit
    printf 'with space\n' >"$MONOLITH_CONFIGS_DIR/.config/app/dir with space/file.txt"
    printf 'third\n' >"$MONOLITH_CONFIGS_DIR/.config/other/third.conf"
    printf '#!/bin/sh\necho tool\n' >"$MONOLITH_CONFIGS_DIR/.local/bin/tool"
    chmod 755 "$MONOLITH_CONFIGS_DIR/.local/bin/tool"
    : >"$MONOLITH_CONFIGS_DIR/.config/app/.gitkeep"
    # wallpapers shipped with the repository + a stub gsettings (state kept in a file)
    export MONOLITH_WALLPAPERS_DIR="$TMP/$n/wallpapers"
    mkdir -p "$MONOLITH_WALLPAPERS_DIR/static" "$MONOLITH_WALLPAPERS_DIR/live" "$TMP/$n/bin"
    printf 'png-data\n' >"$MONOLITH_WALLPAPERS_DIR/static/landscape.png"
    printf 'mp4-data\n' >"$MONOLITH_WALLPAPERS_DIR/live/loop.mp4"
    : >"$MONOLITH_WALLPAPERS_DIR/static/.gitkeep"
    cat >"$TMP/$n/bin/gsettings" <<'STUB'
#!/bin/bash
state="${GSETTINGS_STATE:?}"
case $1 in
    get) grep "^$2 $3=" "$state" 2>/dev/null | sed "s/^$2 $3=//" | tail -n1 | grep . || echo "''" ;;
    set) echo "$2 $3='$4'" >>"$state"; echo "set $3 $4" >>"$state.calls" ;;
esac
STUB
    chmod +x "$TMP/$n/bin/gsettings"
    export GSETTINGS_STATE="$TMP/$n/gsettings.state"
}

inst() { PATH="$TMP/${CUR_ENV:-x}/bin:$PATH" MONOLITH_APPLY_GSETTINGS=1 bash "$ROOT/scripts/install.sh" --lang en --yes --no-deps --no-color --no-clear "$@" </dev/null; }
home_files() { (cd "$MONOLITH_TARGET_HOME" && find .config .local/bin -type f 2>/dev/null | LC_ALL=C sort); }
backups() { find "$MONOLITH_TARGET_HOME/.local/share/monolith-dotfiles/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort; }

echo "== static checks"
for f in "$ROOT"/scripts/*.sh "$ROOT"/scripts/lib/*.sh "$ROOT"/tests/*.sh; do
    check "bash -n $(basename "$f")" bash -n "$f"
done
if command -v shellcheck >/dev/null 2>&1; then
    check "shellcheck (all scripts)" shellcheck -x -S warning "$ROOT"/scripts/*.sh "$ROOT"/scripts/lib/*.sh
else
    echo "  skip  shellcheck not installed"
fi

echo "== i18n catalogue"
check "every key has English and Portuguese, same placeholders" bash -c '
    source "$0/scripts/lib/common.sh"; source "$0/scripts/lib/i18n.sh"; source "$0/scripts/lib/messages.sh"
    for k in "${!MSG_en[@]}"; do
        [[ -n ${MSG_pt_BR[$k]-} ]] || exit 1
        a=$(grep -o "%s" <<<"${MSG_en[$k]}" | wc -l); b=$(grep -o "%s" <<<"${MSG_pt_BR[$k]}" | wc -l)
        [[ $a == "$b" ]] || exit 1
    done' "$ROOT"
check "every t() key used by the scripts exists" bash -c '
    source "$0/scripts/lib/common.sh"; source "$0/scripts/lib/i18n.sh"; source "$0/scripts/lib/messages.sh"
    cd "$0/scripts"
    for k in $(grep -rhoE "\$\(t [a-z_0-9]+\.[a-z_0-9]+" ./*.sh lib/*.sh | sed "s/\$(t //" | sort -u); do
        [[ -n ${MSG_en[$k]-} ]] || { echo "missing $k"; exit 1; }
    done' "$ROOT"

echo "== repository without configs"
new_env empty
rm -rf "$MONOLITH_CONFIGS_DIR/.config/app" "$MONOLITH_CONFIGS_DIR/.config/other" "$MONOLITH_CONFIGS_DIR/.local/bin/tool"
inst >/dev/null 2>&1; rc=$?
[[ $rc == 2 ]] && ok "exits with code 2 and touches nothing" || ko "expected exit 2, got $rc"

echo "== dry-run"
new_env dry
inst --dry-run >/dev/null 2>&1; rc=$?
[[ $rc == 0 ]] && ok "dry-run succeeds" || ko "dry-run exit $rc"
[[ -z $(home_files) ]] && ok "dry-run created no files" || ko "dry-run changed the home"
check "dry-run creates no folders or wallpapers" test ! -e "$MONOLITH_TARGET_HOME/Pictures"
check "dry-run does not touch gsettings" test ! -e "$GSETTINGS_STATE.calls"

echo "== fresh installation"
new_env fresh
inst >"$TMP/fresh.out" 2>&1; rc=$?
[[ $rc == 0 ]] && ok "installer exits 0" || { ko "installer exit $rc"; sed -n '1,40p' "$TMP/fresh.out"; }
check "main.conf identical" cmp -s "$MONOLITH_CONFIGS_DIR/.config/app/main.conf" "$MONOLITH_TARGET_HOME/.config/app/main.conf"
check "path with spaces copied" cmp -s "$MONOLITH_CONFIGS_DIR/.config/app/dir with space/file.txt" "$MONOLITH_TARGET_HOME/.config/app/dir with space/file.txt"
check ".local/bin/tool copied and executable" test -x "$MONOLITH_TARGET_HOME/.local/bin/tool"
check "script with shebang became executable" test -x "$MONOLITH_TARGET_HOME/.config/app/run.sh"
check ".gitkeep placeholders are not deployed" test ! -e "$MONOLITH_TARGET_HOME/.config/app/.gitkeep"
check "no temporary files left behind" bash -c '! find "$0" -name "*.monolith-*" | grep -q .' "$MONOLITH_TARGET_HOME"
check "technical log is in English" grep -q "plan: new=5" "$MONOLITH_TARGET_HOME/.local/state/monolith-dotfiles/"install-*.log
n_before=$(backups | wc -l)

check "wallpaper and config folders were created" bash -c 'for d in Pictures/Wallpapers Videos/wallpaper-live .config/nwg-look .config/wpg; do test -d "$0/$d" || exit 1; done' "$MONOLITH_TARGET_HOME"
check "static wallpaper copied to ~/Pictures/Wallpapers" cmp -s "$MONOLITH_WALLPAPERS_DIR/static/landscape.png" "$MONOLITH_TARGET_HOME/Pictures/Wallpapers/landscape.png"
check "live wallpaper copied to ~/Videos/wallpaper-live" cmp -s "$MONOLITH_WALLPAPERS_DIR/live/loop.mp4" "$MONOLITH_TARGET_HOME/Videos/wallpaper-live/loop.mp4"
check ".gitkeep is not copied as a wallpaper" test ! -e "$MONOLITH_TARGET_HOME/Pictures/Wallpapers/.gitkeep"
check "GTK theme set to Materia-dark" grep -q "gtk-theme='Materia-dark'" "$GSETTINGS_STATE"
check "dark color scheme set" grep -q "color-scheme='prefer-dark'" "$GSETTINGS_STATE"
printf 'my own edit\n' >"$MONOLITH_TARGET_HOME/Pictures/Wallpapers/landscape.png"
touch "$MONOLITH_TARGET_HOME/Pictures/Wallpapers/keep.png"

echo "== idempotency"
inst >"$TMP/second.out" 2>&1; rc=$?
[[ $rc == 0 ]] && ok "second run exits 0" || ko "second run exit $rc"
check "existing wallpapers are left alone" test -f "$MONOLITH_TARGET_HOME/Pictures/Wallpapers/keep.png"
check "a wallpaper you changed is never overwritten" grep -qx "my own edit" "$MONOLITH_TARGET_HOME/Pictures/Wallpapers/landscape.png"
check "gsettings is not rewritten when already set" test "$(wc -l <"$GSETTINGS_STATE.calls")" = 2
check "second run reports nothing to copy" grep -q "Nothing to copy" "$TMP/second.out"
[[ $(backups | wc -l) == "$n_before" ]] && ok "second run created no new backup" || ko "second run created a backup"

echo "== backup of modified files"
printf 'key = MY OWN VALUE\n' >"$MONOLITH_TARGET_HOME/.config/app/main.conf"
inst >"$TMP/third.out" 2>&1; rc=$?
[[ $rc == 0 ]] && ok "run over a modified file exits 0" || ko "exit $rc"
check "file restored to repository content" cmp -s "$MONOLITH_CONFIGS_DIR/.config/app/main.conf" "$MONOLITH_TARGET_HOME/.config/app/main.conf"
bdir=$(backups | tail -n1)
check "backup holds the user's version" grep -q "MY OWN VALUE" "$bdir/files/.config/app/main.conf"
check "manifest lists the replaced file" grep -q "^replace.\.config/app/main.conf" "$bdir/manifest.tsv"
check "backup directory is private (700)" test "$(stat -c %a "$bdir")" = 700

echo "== restore"
bash "$ROOT/scripts/restore.sh" --lang en --yes --no-color </dev/null >"$TMP/restore.out" 2>&1; rc=$?
[[ $rc == 0 ]] && ok "restore exits 0" || { ko "restore exit $rc"; cat "$TMP/restore.out"; }
check "user's version is back" grep -q "MY OWN VALUE" "$MONOLITH_TARGET_HOME/.config/app/main.conf"
check "restore snapshotted the state it overwrote" test "$(backups | wc -l)" -gt "$(( n_before + 1 ))"

echo "== restore --remove-new"
new_env rmnew
inst >/dev/null 2>&1
bash "$ROOT/scripts/restore.sh" --lang en --yes --remove-new --no-color </dev/null >/dev/null 2>&1; rc=$?
[[ $rc == 0 ]] && ok "restore --remove-new exits 0" || ko "exit $rc"
[[ -z $(home_files) ]] && ok "files created by the installer were removed" || { ko "files left: $(home_files | tr '\n' ' ')"; }
check "empty directories were cleaned" test ! -d "$MONOLITH_TARGET_HOME/.config/app"

echo "== rollback on failure"
new_env roll
mkdir -p "$MONOLITH_TARGET_HOME/.config/app"
printf 'precious\n' >"$MONOLITH_TARGET_HOME/.config/app/main.conf"
printf 'precious-too\n' >"$MONOLITH_TARGET_HOME/.config/other-existing"
MONOLITH_TEST_FAIL_AT=3 inst >"$TMP/roll.out" 2>&1; rc=$?
[[ $rc == 7 ]] && ok "failure is reported with exit 7" || ko "expected exit 7, got $rc"
check "replaced file is back to the original" grep -qx precious "$MONOLITH_TARGET_HOME/.config/app/main.conf"
check "unrelated file untouched" grep -qx precious-too "$MONOLITH_TARGET_HOME/.config/other-existing"
check "new files were removed" bash -c '! [ -e "$0/.config/other/third.conf" ] && ! [ -e "$0/.local/bin/tool" ]' "$MONOLITH_TARGET_HOME"
check "directories created by the run were removed" test ! -d "$MONOLITH_TARGET_HOME/.local/bin"

echo "== safety checks"
new_env sym
mkdir -p "$TMP/sym/elsewhere" "$MONOLITH_TARGET_HOME/.config"
ln -s "$TMP/sym/elsewhere" "$MONOLITH_TARGET_HOME/.config/app"
inst >/dev/null 2>&1; rc=$?
[[ $rc == 4 ]] && ok "refuses to write through a symlinked directory" || ko "expected exit 4, got $rc"
[[ -z $(ls -A "$TMP/sym/elsewhere") ]] && ok "symlink target untouched" || ko "symlink target was modified"
new_env conflict
mkdir -p "$MONOLITH_TARGET_HOME/.config/app/main.conf"
inst >/dev/null 2>&1; rc=$?
[[ $rc == 4 ]] && ok "directory where a file is expected is a hard error" || ko "expected exit 4, got $rc"
new_env notty
bash "$ROOT/scripts/install.sh" --no-deps --no-color </dev/null >"$TMP/notty.out" 2>&1; rc=$?
[[ $rc == 1 ]] && grep -q -- "--yes" "$TMP/notty.out" && ok "without a terminal and without --yes it refuses to guess" || ko "no-tty handling (exit $rc)"
check "refuses root-like invalid language" bash -c '! bash "$0/scripts/install.sh" --lang xx --yes --no-deps --dry-run </dev/null >/dev/null 2>&1' "$ROOT"

echo "== import-configs"
new_env imp
src="$TMP/imp/source"
mkdir -p "$src/hypr/modules" "$src/micro/backups" "$src/fish/conf.d" "$src/wpg/schemes" "$src/nvim/lua" "$src/untracked-app"
printf 'hl.config({})\n' >"$src/hypr/hyprland.lua"
printf '#!/bin/sh\necho x\n' >"$src/hypr/modules/run.sh"; chmod 755 "$src/hypr/modules/run.sh"
printf 'secret backup\n' >"$src/micro/backups/%2Fhome%2Fuser%2Fnotes"
printf 'set -g fish_greeting\n' >"$src/fish/config.fish"
printf 'SETUVAR PATH:/home/user/bin\n' >"$src/fish/fish_variables"
printf 'export X=1\n' >"$src/fish/conf.d/uv.env.fish"
printf '{}\n' >"$src/wpg/schemes/generated.json"
printf 'a\n' >"$src/nvim/lua/a.lua"; printf 'old\n' >"$src/nvim/lua/a.lua.bak"
printf 'unrelated\n' >"$src/untracked-app/file"
bash "$ROOT/scripts/import-configs.sh" --from "$src" --lang en --yes --no-color </dev/null >"$TMP/import.out" 2>&1; rc=$?
[[ $rc == 0 ]] && ok "import exits 0" || { ko "import exit $rc"; cat "$TMP/import.out"; }
dst="$MONOLITH_CONFIGS_DIR/.config"
check "files copied with identical content" cmp -s "$src/hypr/hyprland.lua" "$dst/hypr/hyprland.lua"
check "executable bit preserved" test -x "$dst/hypr/modules/run.sh"
check "micro/backups left out" test ! -e "$dst/micro/backups"
check "fish_variables left out" test ! -e "$dst/fish/fish_variables"
check "generated *.env.fish left out" test ! -e "$dst/fish/conf.d/uv.env.fish"
check "wpg/schemes left out" test ! -e "$dst/wpg/schemes"
check "*.bak left out" test ! -e "$dst/nvim/lua/a.lua.bak"
check "regular fish config kept" test -f "$dst/fish/config.fish"
check "folders outside the list are not imported" test ! -e "$dst/untracked-app"
check "import never modifies the source" test -f "$src/micro/backups/%2Fhome%2Fuser%2Fnotes"
check "exclusions are reported to the user" grep -q "Left out on purpose" "$TMP/import.out"

echo "== languages"
new_env lang
inst --dry-run >"$TMP/en.out" 2>&1
check "English output" grep -q "Summary" "$TMP/en.out"
bash "$ROOT/scripts/install.sh" --lang pt_BR --yes --no-deps --no-color --no-clear --dry-run </dev/null >"$TMP/pt.out" 2>&1
check "Portuguese output (--lang pt_BR)" grep -q "Resumo" "$TMP/pt.out"
LANG=pt_BR.UTF-8 bash "$ROOT/scripts/install.sh" --yes --no-deps --no-color --no-clear --dry-run </dev/null >"$TMP/auto.out" 2>&1
check "system language is respected (LANG=pt_BR.UTF-8)" grep -q "Resumo" "$TMP/auto.out"
LANG=C LC_ALL=C bash "$ROOT/scripts/install.sh" --yes --no-deps --no-color --no-clear --dry-run </dev/null >"$TMP/c.out" 2>&1
MONOLITH_LANG=pt_BR bash "$ROOT/scripts/install.sh" --yes --no-deps --no-color --no-clear --dry-run </dev/null >"$TMP/envlang.out" 2>&1
check "MONOLITH_LANG environment variable is honoured" grep -q "Resumo" "$TMP/envlang.out"
check "default is English with LANG=C, plain ASCII fallback works" grep -q "Summary" "$TMP/c.out"
LANG=C.UTF-8 LC_ALL=C.UTF-8 bash "$ROOT/scripts/install.sh" --lang en --yes --no-deps --no-color --no-clear --dry-run </dev/null >"$TMP/utf8.out" 2>&1
check "UTF-8 output uses box-drawing panels" grep -q "╭" "$TMP/utf8.out"
check "boxed panels are rectangular (all rows same width)" bash -c '
    export LC_ALL=C.UTF-8
    ref=0 n=0 bad=0
    while IFS= read -r line; do
        case $line in
            "  ╭"*) ref=${#line}; n=$((n + 1)) ;;
            "  │"* | "  ╰"*) [[ ${#line} == "$ref" ]] || bad=1 ;;
        esac
    done <"$0"
    (( n > 0 && bad == 0 ))' "$TMP/utf8.out"
check "banner present" grep -q "M O N O L I T H\|███╗" "$TMP/c.out" "$TMP/en.out"

echo
printf 'passed: %s   failed: %s\n' "$PASS" "$FAIL"
(( FAIL == 0 ))