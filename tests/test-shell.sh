#!/usr/bin/env bash
# test-shell.sh - tests of the Quickshell code that can run without a compositor: singletons are loaded by small
# harnesses (tests/qml/*.qml) on Qt's "offscreen" platform, in a throw-away HOME / XDG_RUNTIME_DIR with a private
# session bus and no system bus, so nothing of the real session (settings, notifications, Bluetooth) is touched.
# Needs quickshell (qs) and dbus-run-session; without them the tests are skipped (exit 0).
# Usage: bash tests/test-shell.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$ROOT/configs/.config/quickshell"
PASS=0 FAIL=0
ok() { PASS=$(( PASS + 1 )); printf '  ok    %s\n' "$1"; }
ko() { FAIL=$(( FAIL + 1 )); printf '  FAIL  %s\n' "$1"; }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi; }

QS=$(command -v qs || command -v quickshell || true)
if [[ -z $QS ]] || ! command -v dbus-run-session >/dev/null 2>&1; then
    echo "skip: quickshell and dbus-run-session are needed"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# run_harness <name> [VAR=value...]: runs tests/qml/<name>.qml next to links to the shell's folders in a fresh
# environment; the log goes to $LOG, the state dir is $STATE
run_harness() {
    local name=$1
    shift
    local h="$TMP/$name-$RANDOM"
    mkdir -p "$h/shell" "$h/run"
    chmod 700 "$h/run"
    cp "$ROOT/tests/qml/$name.qml" "$h/shell/shell.qml"
    local d
    for d in core services components scripts; do ln -s "$SHELL_DIR/$d" "$h/shell/$d"; done
    LOG="$h/log"
    env -i PATH="$PATH" HOME="${HOME_DIR:-$h/home}" XDG_RUNTIME_DIR="$h/run" LANG=C.UTF-8 QT_QPA_PLATFORM=offscreen \
        DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent "$@" \
        timeout 20 dbus-run-session -- "$QS" -p "$h/shell" >"$LOG" 2>&1
    sed -i 's/\x1b\[[0-9;]*m//g' "$LOG"
}
result() { sed -n "s/^.*RESULT $1=//p" "$LOG" | tail -n 1; }
no_qml_errors() { ! grep -E 'TypeError|ReferenceError|is not a type|Failed to load configuration|Unable to assign|Cannot assign' "$LOG"; }

new_home() { HOME_DIR="$TMP/home-$RANDOM"; STATE="$HOME_DIR/.local/state/quickshell-monolith"; mkdir -p "$STATE"; }

echo "== settings.json"
new_home
run_harness settings
check "no file: loads without QML errors" no_qml_errors
check "no file: settings.json is created" test -s "$STATE/settings.json"
check "no file: what was created is a JSON object" jq -e 'type == "object"' "$STATE/settings.json"
[[ $(result corrupted) == false ]] && ok "no file: not reported as unusable" || ko "no file: not reported as unusable"

new_home
printf '{ "dnd": true, "volumeStep": 7, "unknownKey": 1 }\n' >"$STATE/settings.json"
run_harness settings
[[ $(result dnd) == true && $(result volumeStep) == 7 ]] && ok "valid file: values are read" || ko "valid file: values are read"
[[ $(result corrupted) == false && -z $(find "$STATE" -name 'settings.json.bad-*') ]] && ok "valid file: no copy is made" || ko "valid file: no copy is made"

new_home
printf '{ "dnd": true, "volumeStep": 7,\n' >"$STATE/settings.json"      # cut in the middle
cp "$STATE/settings.json" "$TMP/broken"
run_harness settings MONOLITH_TEST_CHANGE=1
check "broken file: loads without QML errors" no_qml_errors
bad=$(find "$STATE" -name 'settings.json.bad-*' | head -n 1)
[[ -n $bad ]] && cmp -s "$bad" "$TMP/broken" && ok "broken file: an identical copy is kept (settings.json.bad-*)" || ko "broken file: an identical copy is kept (settings.json.bad-*)"
[[ $(result corrupted) == true && $(result backup) == "$bad" ]] && ok "broken file: the shell is told where the copy is" || ko "broken file: the shell is told where the copy is"
check "broken file: after the copy, a change is saved as valid JSON" jq -e '.dnd == true' "$STATE/settings.json"

new_home
printf '[1, 2, 3]\n' >"$STATE/settings.json"
run_harness settings
[[ -n $(find "$STATE" -name 'settings.json.bad-*') ]] && ok "not an object: copied aside as well" || ko "not an object: copied aside as well"

new_home
: >"$STATE/settings.json"
run_harness settings
[[ -z $(find "$STATE" -name 'settings.json.bad-*') ]] && jq -e 'type == "object"' "$STATE/settings.json" >/dev/null 2>&1 &&
    ok "empty file: replaced by the defaults, no copy" || ko "empty file: replaced by the defaults, no copy"

new_home
printf '{ "dnd": true,\n' >"$STATE/settings.json"
chmod 500 "$STATE"                                                        # the copy cannot be created
run_harness settings MONOLITH_TEST_CHANGE=1
chmod 700 "$STATE"
[[ $(cat "$STATE/settings.json") == '{ "dnd": true,' && $(result writeBlocked) == true ]] &&
    ok "broken file, copy impossible: the file is left untouched" || ko "broken file, copy impossible: the file is left untouched"

echo "== singletons (core/ and services/)"
new_home
run_harness services
check "every singleton loads without QML errors" no_qml_errors
n=$(( $(grep -c "^singleton " "$SHELL_DIR/core/qmldir") + $(grep -c "^singleton " "$SHELL_DIR/services/qmldir") ))
[[ $(result singletons) == "$n/$n" ]] && ok "all $n singletons are instantiated" || ko "all $n singletons are instantiated ($(result singletons))"

echo "== Nothing theme is optional (same configs/ on Arch and NixOS)"
[[ $(result nothing) == "false/false bar=top/capsule lookDone=false" ]] && ok "without nothing.json: theme unavailable, the standard bar (top, capsule)" || ko "without nothing.json: theme unavailable, the standard bar (top, capsule) [$(result nothing)]"
new_home
mkdir -p "$HOME_DIR/.config/monolith"
printf '{ "defaults": { "enabled": true }, "palette": {} }\n' >"$HOME_DIR/.config/monolith/nothing.json"
run_harness services
check "with nothing.json: loads without QML errors" no_qml_errors
[[ $(result nothing) == "true/true bar=left/frame lookDone=true" ]] && ok "with nothing.json: theme active, its bar look applied" || ko "with nothing.json: theme active, its bar look applied [$(result nothing)]"
jq '.barPosition = "bottom"' "$STATE/settings.json" >"$TMP/s.json" && cp "$TMP/s.json" "$STATE/settings.json"
run_harness services
[[ $(result nothing) == "true/true bar=bottom/frame lookDone=true" ]] && ok "the look is applied once: a later choice in Settings stays" || ko "the look is applied once: a later choice in Settings stays [$(result nothing)]"
printf '{ "defaults": { "enabled": false } }\n' >"$HOME_DIR/.config/monolith/nothing.json"
run_harness services
[[ $(result nothing) == true/false* ]] && ok "theme present but disabled: not active" || ko "theme present but disabled: not active [$(result nothing)]"

echo "== YouTube Music token"
if command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    # a local server that records the Authorization header of every request
    python3 - "$TMP/ytm.port" "$TMP/ytm.auth" <<'PY' &
import http.server, sys
class H(http.server.BaseHTTPRequestHandler):
    def reply(self):
        open(sys.argv[2], "a").write((self.headers.get("Authorization") or "-") + "\n")
        self.send_response(200); self.end_headers(); self.wfile.write(b"{}")
    do_GET = do_POST = reply
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(s.server_address[1]))
s.serve_forever()
PY
    srv=$!
    for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -s $TMP/ytm.port ]] && break; sleep 0.2; done
    new_home
    run_harness services MONOLITH_TEST=ytm MONOLITH_TEST_PORT="$(cat "$TMP/ytm.port")"
    kill "$srv" 2>/dev/null
    [[ $(grep -c '^Bearer s3cret-token$' "$TMP/ytm.auth" 2>/dev/null) == 3 ]] && ok "the token reaches the API (action + two state reads)" || ko "the token reaches the API (action + two state reads)"
    # it must not be built into the command line
    ! grep -nE 'push\(.*ytmToken|"Authorization: Bearer " \+' "$SHELL_DIR/services/Media.qml" >/dev/null && ok "the token is not part of a command line" || ko "the token is not part of a command line"
else
    echo "  skip  python3 / curl not installed"
fi

echo "== VS Code colours"
new_home
mkdir -p "$HOME_DIR/.config/Code/User" "$HOME_DIR/.config/VSCodium/User" "$HOME_DIR/real"
printf '{\n  "editor.fontSize": 14\n}\n' >"$HOME_DIR/real/settings.json"
ln -s "$HOME_DIR/real/settings.json" "$HOME_DIR/.config/Code/User/settings.json"       # dotfiles managed by links
printf '{\n  // a comment\n  "editor.fontSize": 14,\n}\n' >"$HOME_DIR/.config/VSCodium/User/settings.json"
cp "$HOME_DIR/.config/VSCodium/User/settings.json" "$TMP/jsonc"
run_harness services MONOLITH_TEST=vscode
check "plain JSON: colours are added, other keys kept" jq -e '."editor.fontSize" == 14 and (."workbench.colorCustomizations" | type == "object")' "$HOME_DIR/real/settings.json"
check "a symlinked settings.json stays a link" test -L "$HOME_DIR/.config/Code/User/settings.json"
[[ -z $(find "$HOME_DIR" -name '*.monolith-tmp') ]] && ok "no temporary file is left" || ko "no temporary file is left"
check "JSON with comments: left untouched" cmp -s "$HOME_DIR/.config/VSCodium/User/settings.json" "$TMP/jsonc"
check "JSON with comments: the reason is logged" grep -q 'VS Code colours not written' "$LOG"

echo "== notifications"
if command -v gdbus >/dev/null 2>&1; then
    new_home
    run_harness services MONOLITH_TEST=notifs
    check "25 notifications: no QML errors" no_qml_errors
    is_r() { [[ $(result "$2") == "$3" ]] && ok "$1" || ko "$1 [$(result "$2")]"; }
    is_r "all of them were delivered to the shell's own server" sent true
    is_r "history capped at the limit, no toast and no timing entry left after they expire" notifs "history:10 popups:0 expiry:0 held:0"
else
    echo "  skip  gdbus not installed"
fi

echo "== Bluetooth pairing agent (bluetoothctl prompts)"
new_home
run_harness services MONOLITH_TEST=bt
check "prompts are parsed without QML errors" no_qml_errors
[[ $(result bt) == ok,ok,ok,ok,ok,ok,ok,ok,ok,ok,ok ]] && ok "confirm, PIN, passkey, authorize, service, displayed codes, split and coloured prompts" || ko "prompt parsing [$(result bt)]"

echo
printf 'passed: %s   failed: %s\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
