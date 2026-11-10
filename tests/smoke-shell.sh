#!/usr/bin/env bash
# smoke-shell.sh - starts the whole shell (bar, menus, overlays, Settings app, widgets) in a nested Hyprland and
# fails on any QML error in its log. It is the only test that loads the windows: the headless harnesses of
# tests/test-shell.sh cannot (Quickshell's panels need a Wayland compositor with layer-shell).
#
# It must be started from a running Wayland session and OPENS A WINDOW on it (the nested compositor) for about
# 40 seconds. Everything else is isolated: throw-away HOME and XDG_RUNTIME_DIR, private session bus, no system
# bus (no NetworkManager / BlueZ / UPower), no PipeWire, no network (a failing `curl` shadows the real one) - the
# real shell, settings and devices are not touched.
# Usage: bash tests/smoke-shell.sh [--keep] [--nothing]
#   --keep      leaves the log folder and prints its path
#   --nothing   with the Nothing theme active (a nothing.json like the one the Nix module writes), which is the only
#               way to load its LED components outside NixOS
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$ROOT/configs/.config/quickshell"
KEEP=0 NOTHING=0
for a; do case $a in --keep) KEEP=1 ;; --nothing) NOTHING=1 ;; *) echo "usage: $0 [--keep] [--nothing]" >&2; exit 2 ;; esac; done
PASS=0 FAIL=0
ok() { PASS=$(( PASS + 1 )); printf '  ok    %s\n' "$1"; }
ko() { FAIL=$(( FAIL + 1 )); printf '  FAIL  %s\n' "$1"; }

for t in Hyprland hyprctl dbus-run-session; do command -v "$t" >/dev/null 2>&1 || { echo "skip: $t is needed"; exit 0; }; done
QS=$(command -v qs || command -v quickshell || true)
[[ -n $QS ]] || { echo "skip: quickshell is needed"; exit 0; }
[[ -n ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} ]] || { echo "skip: no Wayland session to nest in"; exit 0; }

# short paths: Hyprland's sockets live under XDG_RUNTIME_DIR/hypr/<long signature>/ and a socket path is limited
# to 108 bytes
TMP="$(mktemp -d /tmp/mono.XXXXXX)"
HPID=""
cleanup() {
    [[ -n $HPID ]] && kill "$HPID" 2>/dev/null
    wait 2>/dev/null
    if (( KEEP )); then echo "logs: $TMP"; else rm -rf "$TMP"; fi
}
trap cleanup EXIT
mkdir -p "$TMP/run" "$TMP/home/.config"
chmod 700 "$TMP/run"
case $WAYLAND_DISPLAY in /*) PARENT=$WAYLAND_DISPLAY ;; *) PARENT="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ;; esac
if (( NOTHING )); then
    mkdir -p "$TMP/home/.config/monolith"
    printf '{ "defaults": { "enabled": true, "monochrome": true, "edgeGlow": true, "ledShape": "circle", "ledSize": 6, "ledSpacing": 3, "wallpaperStyle": "original" }, "palette": {} }\n' \
        >"$TMP/home/.config/monolith/nothing.json"
fi
printf -- '-- empty configuration for the nested compositor of tests/smoke-shell.sh\n' >"$TMP/hyprland.lua"

# no network either: a `curl` that always fails comes first in PATH (weather, lyrics, covers, update check)
mkdir -p "$TMP/bin"
printf '#!/bin/sh\nexit 22\n' >"$TMP/bin/curl"
chmod +x "$TMP/bin/curl"
ENVV=(env -i PATH="$TMP/bin:$PATH" HOME="$TMP/home" XDG_RUNTIME_DIR="$TMP/run" LANG=C.UTF-8
    DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent)

echo "== nested Hyprland"
"${ENVV[@]}" WAYLAND_DISPLAY="$PARENT" Hyprland -c "$TMP/hyprland.lua" >"$TMP/hyprland.log" 2>&1 &
HPID=$!
SIG=""
for _ in $(seq 50); do
    for d in "$TMP/run/hypr"/*/; do [[ -d $d ]] && SIG=$(basename "$d"); done
    [[ -n $SIG && -S $TMP/run/hypr/$SIG/.socket.sock ]] && break
    sleep 0.2
done
if [[ -z $SIG ]] || ! kill -0 "$HPID" 2>/dev/null; then
    ko "the nested compositor did not start (see $TMP/hyprland.log)"; KEEP=1; exit 1
fi
ok "compositor up"
NEST=""
for f in "$TMP/run"/wayland-*; do [[ -S $f ]] && { NEST=$(basename "$f"); break; }; done
INNER=("${ENVV[@]}" WAYLAND_DISPLAY="$NEST" HYPRLAND_INSTANCE_SIGNATURE="$SIG" XDG_CURRENT_DESKTOP=Hyprland)

echo "== shell"
"${INNER[@]}" timeout 60 dbus-run-session -- "$QS" -p "$SHELL_DIR" >"$TMP/shell.log" 2>&1 &
QPID=$!
ipc() { "${INNER[@]}" timeout 5 "$QS" -p "$SHELL_DIR" ipc call "$@" >>"$TMP/ipc.log" 2>&1; }
for _ in $(seq 40); do ipc shell close && break; sleep 0.3; done
if ! kill -0 "$QPID" 2>/dev/null; then ko "the shell exited at start"; else ok "shell started and answers IPC"; fi

# every menu, both overlays, every Settings page, the widget editor and one widget of each kind
for m in audio media network bluetooth power brightness notifications calendar center stats settings; do
    ipc shell toggle "$m"; sleep 0.7
done
ipc shell close
ipc shell launcher; sleep 0.8; ipc shell launcher
ipc shell wallpaper; sleep 0.8; ipc shell wallpaper
pages=$(grep -oE '\{ id: "[a-z]+", glyph' "$SHELL_DIR/settings/Registry.qml" | sed -E 's/.*"([a-z]+)".*/\1/' | sort -u)
for p in ${pages:-system}; do ipc shell settings "$p"; sleep 0.7; done
ipc shell close
for w in clock weather media system lyrics; do ipc widgets add "$w"; sleep 0.3; done
ipc widgets edit; sleep 0.8; ipc widgets edit
for pos in left bottom right top; do ipc shell bar "$pos"; sleep 0.8; done
ipc screenshot notify /nonexistent.png; sleep 0.5
ipc shell welcome; sleep 0.8; ipc shell close
sleep 1
kill -0 "$QPID" 2>/dev/null && ok "still running after every menu, page, overlay, widget and bar position" || ko "the shell died during the tour"
kill "$QPID" 2>/dev/null; wait "$QPID" 2>/dev/null

sed -i 's/\x1b\[[0-9;]*m//g' "$TMP/shell.log"
errs=$(grep -E 'TypeError|ReferenceError|RangeError|SyntaxError|is not a type|is not defined|Unable to assign|Cannot assign|Cannot read property|Failed to load|Binding loop|unavailable' "$TMP/shell.log" | sed -E 's/^ *(WARN|ERROR)[^:]*: //' | sort | uniq -c | sort -rn)
if [[ -z $errs ]]; then ok "no QML error in the log ($(wc -l <"$TMP/shell.log") lines)"
else ko "QML errors in the log:"; printf '%s\n' "$errs" | head -n 40 | sed 's/^/        /'; KEEP=1; fi

echo
printf 'passed: %s   failed: %s\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
