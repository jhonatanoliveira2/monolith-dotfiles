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
check "every key has English; a Portuguese one, when there, has the same placeholders" bash -c '
    source "$0/scripts/lib/common.sh"; source "$0/scripts/lib/i18n.sh"; source "$0/scripts/lib/messages.sh"
    for k in "${!MSG_en[@]}"; do
        [[ -n ${MSG_en[$k]} ]] || exit 1
        [[ -n ${MSG_pt_BR[$k]-} ]] || continue
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
check "Monolith-Icons written to ~/.local/share/icons" test -f "$MONOLITH_TARGET_HOME/.local/share/icons/Monolith-Icons/scalable/places/folder.svg"
check "Monolith-Icons index.theme inherits Adwaita" grep -q "^Inherits=Adwaita" "$MONOLITH_TARGET_HOME/.local/share/icons/Monolith-Icons/index.theme"
check "icon theme set to Monolith-Icons" grep -q "icon-theme='Monolith-Icons'" "$GSETTINGS_STATE"
printf 'my own edit\n' >"$MONOLITH_TARGET_HOME/Pictures/Wallpapers/landscape.png"
touch "$MONOLITH_TARGET_HOME/Pictures/Wallpapers/keep.png"

echo "== idempotency"
inst >"$TMP/second.out" 2>&1; rc=$?
[[ $rc == 0 ]] && ok "second run exits 0" || ko "second run exit $rc"
check "existing wallpapers are left alone" test -f "$MONOLITH_TARGET_HOME/Pictures/Wallpapers/keep.png"
check "a wallpaper you changed is never overwritten" grep -qx "my own edit" "$MONOLITH_TARGET_HOME/Pictures/Wallpapers/landscape.png"
check "gsettings is not rewritten when already set" test "$(wc -l <"$GSETTINGS_STATE.calls")" = 3
printf "org.gnome.desktop.interface icon-theme='Papirus-Dark'\n" >>"$GSETTINGS_STATE"
inst >"$TMP/third.out" 2>&1
check "an icon theme picked by the user is kept" test "$(grep -c "icon-theme Monolith-Icons" "$GSETTINGS_STATE.calls")" = 1
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

echo "== distributions (Arch Linux, CachyOS, other pacman distributions)"
D="$TMP/distro"
mkdir -p "$D/bin"
printf 'NAME="CachyOS Linux"\nPRETTY_NAME="CachyOS"\nID=cachyos\nID_LIKE=arch\n' >"$D/cachyos"
printf 'NAME="Arch Linux"\nPRETTY_NAME="Arch Linux"\nID=arch\n' >"$D/arch"
printf 'NAME="EndeavourOS"\nPRETTY_NAME="EndeavourOS"\nID="endeavouros"\nID_LIKE="arch"\n' >"$D/endeavouros"
printf 'NAME="Ubuntu"\nPRETTY_NAME="Ubuntu 24.04"\nID=ubuntu\nID_LIKE=debian\n' >"$D/ubuntu"
detect() { # detect <os-release fixture> [pacman 0|1] -> "<id>|<name>"
    MONOLITH_OS_RELEASE="$D/$1" bash -c 'source "$0/scripts/lib/common.sh"; source "$0/scripts/lib/packages.sh"
        PACMAN_AVAILABLE=$1; source "$0/scripts/lib/distro.sh"; distro_detect; echo "$DISTRO_ID|$DISTRO_NAME"' "$ROOT" "${2:-0}"
}
check "CachyOS is detected as cachyos" test "$(detect cachyos)" = "cachyos|CachyOS"
check "Arch Linux is detected as arch" test "$(detect arch)" = "arch|Arch Linux"
check "other Arch derivatives (ID_LIKE=arch) are arch-based" test "$(detect endeavouros)" = "arch-based|EndeavourOS"
check "a non-pacman distribution is unknown" test "$(detect ubuntu)" = "unknown|Ubuntu 24.04"
check "any distribution with pacman is arch-based" test "$(detect ubuntu 1)" = "arch-based|Ubuntu 24.04"
# a stub pacman shaped like a CachyOS install: tuned-ppd (instead of power-profiles-daemon) and
# pipewire-pulse installed, paru available in the repositories
cat >"$D/bin/pacman" <<'STUB'
#!/bin/bash
case $1 in
    -Qi) printf 'Name            : tuned-ppd\nConflicts With  : power-profiles-daemon\nName            : pipewire-pulse\nConflicts With  : pulseaudio\n                  pulseaudio-bluetooth\n' ;;
    -Si) case $2 in
            pulseaudio) printf 'Name            : pulseaudio\nConflicts With  : pipewire-pulse>=1.0\n' ;;
            power-profiles-daemon | btop) printf 'Name            : %s\nConflicts With  : None\n' "$2" ;;
            paru) [[ -n ${STUB_PARU-} ]] && printf 'Name            : paru\n' || exit 1 ;;
            *) exit 1 ;;
         esac ;;
    -T) case $2 in pipewire-pulse | tuned-ppd) exit 0 ;; *) exit 127 ;; esac ;;
esac
STUB
chmod +x "$D/bin/pacman"
pk() { PATH="$D/bin:$PATH" bash -c 'source "$0/scripts/lib/common.sh"; source "$0/scripts/lib/packages.sh"; '"$1" "$ROOT"; }
out=$(pk 'pkg_split_conflicts btop pulseaudio power-profiles-daemon; echo "ok=${PKG_OK[*]}"; printf "c=%s\n" "${PKG_CONFLICT[@]}"')
check "a package without conflicts is installed" grep -qx "ok=btop" <<<"$out"
check "its own declared conflict is detected (pulseaudio vs pipewire-pulse)" grep -qx "c=pulseaudio: pipewire-pulse" <<<"$out"
check "a conflict declared by the installed package is detected (tuned-ppd)" grep -qx "c=power-profiles-daemon: tuned-ppd" <<<"$out"
check "an AUR helper shipped in the repositories is found (CachyOS)" test "$(STUB_PARU=1 pk 'aur_helper_in_repos')" = paru
check "no repository AUR helper on Arch" test -z "$(pk 'aur_helper_in_repos')"
new_env distro
MONOLITH_OS_RELEASE="$D/cachyos" inst --dry-run >"$TMP/cachy.out" 2>&1
check "the installer reports CachyOS" grep -q "CachyOS detected" "$TMP/cachy.out"
MONOLITH_OS_RELEASE="$D/cachyos" bash "$ROOT/scripts/install.sh" --lang pt_BR --yes --no-deps --no-color --no-clear --dry-run </dev/null >"$TMP/cachy-pt.out" 2>&1
check "the installer reports CachyOS (pt_BR)" grep -q "CachyOS detectado" "$TMP/cachy-pt.out"

echo "== Nothing theme (scripts/nothing-theme.sh)"
new_env nothing
NT_HOME=$MONOLITH_TARGET_HOME
NT_STATE="$NT_HOME/.local/state/monolith-dotfiles/nothing-theme"
# a fake curl that answers every download with the wrong bytes: the fixed sha256 must refuse them
cat >"$TMP/nothing/bin/curl" <<'STUB'
#!/bin/bash
out=""
while (( $# )); do [[ $1 == -o ]] && { out=$2; shift; }; shift; done
[[ -n $out ]] && echo "not a font" >"$out"
exit 0
STUB
chmod +x "$TMP/nothing/bin/curl"
printf 'org.gnome.desktop.interface icon-theme=%s\n' "'Adwaita'" >"$GSETTINGS_STATE"
mkdir -p "$NT_HOME/.config/cava"
printf 'my own cava config\n' >"$NT_HOME/.config/cava/config"
mkdir -p "$NT_HOME/.config/gtk-4.0"   # the default gtk.css, as install.sh deploys it
cp "$ROOT/configs/.config/gtk-4.0/gtk.css" "$NT_HOME/.config/gtk-4.0/gtk.css"
NT_GTK=$(cat "$ROOT/configs/.config/gtk-4.0/gtk.css" "$ROOT/nix/nothing/nautilus.css" | md5sum)
nt() { PATH="$TMP/nothing/bin:$PATH" MONOLITH_APPLY_GSETTINGS=1 bash "$ROOT/scripts/nothing-theme.sh" --lang en --yes --no-color "$@" </dev/null; }
has_pil=0; python3 -I -c 'import PIL' 2>/dev/null && has_pil=1

nt on --dry-run >"$TMP/nt-dry.out" 2>&1
check "dry-run writes nothing" test ! -e "$NT_HOME/.config/monolith/nothing.json" -a ! -e "$NT_STATE"
check "dry-run lists what it would write" grep -q "Would write ~/.config/monolith/nothing.json" "$TMP/nt-dry.out"

nt on >"$TMP/nt-on.out" 2>&1
check "on: exits 0" test $? -eq 0
J="$NT_HOME/.config/monolith/nothing.json"
check "nothing.json is valid JSON with the theme enabled" jq -e '.defaults.enabled == true and .version == 1' "$J"
check "palette and fonts come from tokens.json" jq -e '.palette.ink == "#f2f2f2" and .palette.alert == "#d71921" and .fonts.dot == "Doto"' "$J"
check "no build-time wallpapers on Arch" jq -e '.wallpapers.dir == "" and .wallpapers.outputs == []' "$J"
# the defaults written here are the ones of the Nix options (nix/modules/nothing-options.nix)
declare -A NIXDEF=()
while IFS='=' read -r k v; do NIXDEF[$k]=$v; done < <(awk '
    match($0, /^ *[A-Za-z]+ = (mkOption )?\{/) {
        d = int(index($0, $1) / 2); split($1, a, " "); name[d] = a[1]; depth = d; next }
    /default = / && depth >= 0 {
        v = $0; sub(/.*default = /, "", v); sub(/;.*/, "", v); gsub(/"/, "", v)
        p = name[1]; for (i = 2; i <= depth; i++) p = p "." name[i]; print p "=" v }
' "$ROOT/nix/modules/nothing-options.nix")
bad=""
for pair in led.size:ledSize led.spacing:ledSpacing led.shape:ledShape monochrome:monochrome edgeGlow:edgeGlow \
    wallpaper.style:wallpaperStyle wallpaper.dither:dither wallpaper.levels:levels wallpaper.invert:invert \
    wallpaper.contrast:contrast wallpaper.brightness:brightness wallpaper.colors.lit:lit \
    wallpaper.colors.off:off wallpaper.colors.background:background; do
    nix=${NIXDEF[${pair%%:*}]-missing} got=$(jq -r ".defaults.${pair#*:}" "$J")
    [[ $nix == "$got" ]] || bad+=" ${pair%%:*}(nix=$nix json=$got)"
done
[[ -z $bad ]] && ok "defaults equal the Nix options" || ko "defaults differ from the Nix options:$bad"
check "a font that fails its checksum is discarded" test ! -e "$NT_HOME/.local/share/fonts/monolith-nothing"
check "... and reported" grep -q "did not match its checksum" "$TMP/nt-on.out"
check "monolith-dotmatrix installed, executable" test -x "$NT_HOME/.local/bin/monolith-dotmatrix"
check "monolith-cava installed, executable" test -x "$NT_HOME/.local/bin/monolith-cava"
check "a cava config of the user's own is saved" grep -qx "my own cava config" "$NT_STATE/saved/.config/cava/config"
check "the theme's cava config is in place" cmp -s "$ROOT/nix/nothing/cava.conf" "$NT_HOME/.config/cava/config"
check "fish functions for cava and fastfetch" test -f "$NT_HOME/.config/fish/functions/cava.fish" -a -f "$NT_HOME/.config/fish/functions/fastfetch.fish"
check "fastfetch: valid JSON, the distribution's name instead of NixOS" \
    bash -c '! grep -q "N I X O S" "$1" && grep -v "^//" "$1" | jq -e ".logo.source" >/dev/null' _ "$NT_HOME/.config/fastfetch/nothing.jsonc"
check "fastfetch: the Arch LED logo" cmp -s "$ROOT/nix/nothing/fastfetch-logo-arch.txt" "$NT_HOME/.config/fastfetch/nothing-logo.txt"
check "nautilus: gtk.css is the default one with the Nothing block after it" \
    test "$(md5sum <"$NT_HOME/.config/gtk-4.0/gtk.css")" = "$NT_GTK"
check "... and the default gtk.css is saved for off" cmp -s "$ROOT/configs/.config/gtk-4.0/gtk.css" "$NT_STATE/saved/.config/gtk-4.0/gtk.css"
check "icon theme drawn" test -f "$NT_HOME/.local/share/icons/Monolith-Dots-Icons/index.theme"
check "gsettings icon-theme set" grep -q "set icon-theme Monolith-Dots-Icons" "$GSETTINGS_STATE.calls"
if (( has_pil )); then
    check "cursor theme drawn" test -f "$NT_HOME/.icons/Monolith-Dots/cursors/pointer" -o -L "$NT_HOME/.icons/Monolith-Dots/cursors/pointer"
    check "Hyprland cursor file" grep -qx "Monolith-Dots 24" "$NT_HOME/.config/monolith/cursor"
    check "gsettings cursor-theme set" grep -q "set cursor-theme Monolith-Dots" "$GSETTINGS_STATE.calls"
else
    check "without Pillow the cursor is left out, with a warning" grep -q "Cursor left out" "$TMP/nt-on.out"
fi
nt status >"$TMP/nt-status.out" 2>&1
check "status lists what it installed" grep -q ".config/monolith/nothing.json" "$TMP/nt-status.out"
before=$(cd "$NT_HOME" && find . -path ./.local/state -prune -o -type f -print | LC_ALL=C sort | md5sum)
nt on >/dev/null 2>&1
after=$(cd "$NT_HOME" && find . -path ./.local/state -prune -o -type f -print | LC_ALL=C sort | md5sum)
check "on again changes nothing" test "$before" = "$after"
check "on again does not save its own files" test ! -e "$NT_STATE/saved/.config/monolith"

nt on --no-icons >/dev/null 2>&1
check "--no-icons removes the icon theme" test ! -e "$NT_HOME/.local/share/icons/Monolith-Dots-Icons"
check "... and puts the previous icon-theme back" bash -c 'tail -n1 "$1" | grep -q "set icon-theme '"'"'Adwaita'"'"'"' _ "$GSETTINGS_STATE.calls"
inst >"$TMP/nt-inst.out" 2>&1
check "install.sh refreshes the theme when it is on" grep -qE "nothing-theme.sh on .*--refresh" "$NT_HOME"/.local/state/monolith-dotfiles/install-*.log
check "... keeping the parts chosen before" bash -c 'grep -qx icons=0 "$1" && test ! -e "$2"' _ "$NT_STATE/parts" "$NT_HOME/.local/share/icons/Monolith-Dots-Icons"
check "... and the Nothing Nautilus stays after install.sh deploys the default gtk.css" \
    test "$(md5sum <"$NT_HOME/.config/gtk-4.0/gtk.css")" = "$NT_GTK"
nt on --refresh --no-nautilus >/dev/null 2>&1
check "--no-nautilus puts the default gtk.css back" cmp -s "$ROOT/configs/.config/gtk-4.0/gtk.css" "$NT_HOME/.config/gtk-4.0/gtk.css"
nt on --refresh >/dev/null 2>&1
check "--refresh keeps Nautilus out once left out" grep -qx nautilus=0 "$NT_STATE/parts"
nt on >/dev/null 2>&1

nt off >/dev/null 2>&1
check "off removes nothing.json and the record" test ! -e "$J" -a ! -e "$NT_STATE"
check "off removes the renderer and the fish functions" test ! -e "$NT_HOME/.local/bin/monolith-dotmatrix" -a ! -e "$NT_HOME/.config/fish/functions"
check "off puts the user's cava config back" grep -qx "my own cava config" "$NT_HOME/.config/cava/config"
check "off puts the default gtk.css back" cmp -s "$ROOT/configs/.config/gtk-4.0/gtk.css" "$NT_HOME/.config/gtk-4.0/gtk.css"
check "off leaves no theme folder" test ! -e "$NT_HOME/.icons/Monolith-Dots" -a ! -e "$NT_HOME/.config/fastfetch/nothing.jsonc"
nt off >"$TMP/nt-off2.out" 2>&1
check "off when it is off: nothing to do" grep -q "is not on" "$TMP/nt-off2.out"

new_env nothing-flag
cp "$TMP/nothing/bin/curl" "$TMP/nothing-flag/bin/curl"
inst --nothing-theme >"$TMP/nt-flag.out" 2>&1
check "install.sh --nothing-theme turns it on" jq -e '.defaults.enabled' "$MONOLITH_TARGET_HOME/.config/monolith/nothing.json"
inst --theme nothing >/dev/null 2>&1
check "--theme nothing when it is on: refreshed, still on" jq -e '.defaults.enabled' "$MONOLITH_TARGET_HOME/.config/monolith/nothing.json"
inst --theme default >"$TMP/nt-default.out" 2>&1
check "--theme default turns the Nothing theme off" test ! -e "$MONOLITH_TARGET_HOME/.config/monolith/nothing.json" -a ! -e "$MONOLITH_TARGET_HOME/.local/state/monolith-dotfiles/nothing-theme"
inst --theme=default >"$TMP/nt-default2.out" 2>&1
check "--theme default when it is off: nothing to undo" grep -q "Theme: default." "$TMP/nt-default2.out"
check "--theme refuses other values" bash -c '! PATH="$1:$PATH" bash "$2" --lang en --yes --no-deps --no-color --no-clear --theme glow </dev/null >/dev/null 2>&1' _ "$TMP/nothing-flag/bin" "$ROOT/scripts/install.sh"
new_env nothing-none
inst >/dev/null 2>&1
check "without a choice (--yes) install.sh leaves the theme off" test ! -e "$MONOLITH_TARGET_HOME/.config/monolith/nothing.json"

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