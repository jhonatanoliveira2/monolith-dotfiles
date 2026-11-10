#!/usr/bin/env bash
# test-scripts.sh - the shell's helper scripts (configs/.config/quickshell/scripts) against throw-away fixtures:
# a fake `curl` that records every URL and answers from canned files (no network), a local git remote, an empty
# HOME. Nothing of the real system is read or changed, and no quickshell is needed (this runs in CI).
# Usage: bash tests/test-scripts.sh
set -uo pipefail
export LC_ALL=C.UTF-8

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$ROOT/configs/.config/quickshell/scripts"
PASS=0 FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ok() { PASS=$(( PASS + 1 )); printf '  ok    %s\n' "$1"; }
ko() { FAIL=$(( FAIL + 1 )); printf '  FAIL  %s\n' "$1"; }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi; }
is() { if [[ $2 == "$3" ]]; then ok "$1"; else ko "$1 (got: ${2:0:80})"; fi; } # is <description> <actual> <expected>

for t in jq git; do command -v "$t" >/dev/null 2>&1 || { echo "skip: $t is needed"; exit 0; }; done

# --- fake curl: logs the URL (the argument that starts with http) and prints $FAKE/<host> when it exists --------
FAKE="$TMP/fake"; BIN="$TMP/bin"
mkdir -p "$FAKE" "$BIN"
cat >"$BIN/curl" <<'SH'
#!/usr/bin/env bash
url=""
for a; do case $a in http://* | https://*) url=$a ;; esac; done
host=${url#*://}; host=${host%%/*}
echo "$host" >>"$FAKE/requests"
[[ -f $FAKE/$host ]] && { cat "$FAKE/$host"; exit 0; }
exit 22
SH
chmod +x "$BIN/curl"
requests() { sort -u "$FAKE/requests" 2>/dev/null | tr '\n' ' '; }
fresh() { rm -f "$FAKE"/*; export XDG_CACHE_HOME="$TMP/cache-$RANDOM" HOME="$TMP/home"; mkdir -p "$HOME"; }
run() { FAKE="$FAKE" PATH="$BIN:$PATH" bash "$@"; }

echo "== lyrics.sh"
fresh
printf '{ "syncedLyrics": "[00:01.00]hello", "plainLyrics": "hello" }' >"$FAKE/lrclib.net"
out=$(run "$S/lyrics.sh" "Artist" "Title" "Album" 200)
is "synced lyrics from LRCLIB" "$(head -n 1 <<<"$out")" $'lrclib\tsynced'
is "only LRCLIB was asked (the first source answered)" "$(requests)" "lrclib.net "
check "the result is cached" test -s "$XDG_CACHE_HOME/quickshell-monolith/lyrics/Artist - Title.lrc"
rm -f "$FAKE/requests"
run "$S/lyrics.sh" "Artist" "Title" "Album" 200 >/dev/null
is "a cached song makes no request" "$(requests)" ""

fresh
out=$(run "$S/lyrics.sh" "Artist" "Title" "" 0)
is "no source has it: none" "$out" "none"
is "every source was asked" "$(requests)" "api.lyrics.ovh lrclib.net music.163.com "
check "a miss with every source is cached" test -s "$XDG_CACHE_HOME/quickshell-monolith/lyrics/Artist - Title.lrc"

fresh
out=$(run "$S/lyrics.sh" "Artist" "Title" "" 0 "lrclib")
is "sources = lrclib: nothing is sent to the others" "$(requests)" "lrclib.net "
check "a miss with a limited list is not cached" test ! -e "$XDG_CACHE_HOME/quickshell-monolith/lyrics/Artist - Title.lrc"
fresh
run "$S/lyrics.sh" "Artist" "Title" "" 0 "ovh" >/dev/null
is "sources = ovh: only lyrics.ovh" "$(requests)" "api.lyrics.ovh "

fresh
printf '{ "syncedLyrics": "[00:01.00]x" }' >"$FAKE/lrclib.net"
long=$(printf '歌%.0s' {1..150})                       # 150 characters, 450 bytes: over the 255-byte name limit
out=$(run "$S/lyrics.sh" "歌手" "$long" "" 0)
is "a very long multibyte title still returns lyrics" "$(head -n 1 <<<"$out")" $'lrclib\tsynced'
n=$(find "$XDG_CACHE_HOME/quickshell-monolith/lyrics" -name '*.lrc' | wc -l)
is "and is cached under a name that fits" "$n" "1"
fresh
printf '{ "syncedLyrics": "[00:01.00]x" }' >"$FAKE/lrclib.net"
run "$S/lyrics.sh" "AC/DC" "../../escape" "" 0 >/dev/null
is "slashes in the names stay inside the cache folder" "$(find "$TMP" -name '*.lrc' -not -path '*/quickshell-monolith/lyrics/*' | wc -l)$(find "$XDG_CACHE_HOME/quickshell-monolith/lyrics" -mindepth 2 | wc -l)" "00"

echo "== weather.sh"
fresh
run "$S/weather.sh" "" "" "" "" en 0 >/dev/null 2>&1
is "no city and locating by IP off: exit 3" "$?" "3"
is "and nothing was requested" "$(requests)" ""
fresh
printf '{ "city": "Testville", "loc": "10.5,-20.25" }' >"$FAKE/ipinfo.io"
printf '{ "current": {} }' >"$FAKE/api.open-meteo.com"
out=$(run "$S/weather.sh" "" "" "" "" en 1 2>/dev/null)
is "located by IP when allowed" "$(head -n 1 <<<"$out")" $'Testville\t10.5\t-20.25'
fresh
printf '{ "results": [ { "name": "Lisboa", "latitude": 38.7, "longitude": -9.1 } ] }' >"$FAKE/geocoding-api.open-meteo.com"
printf '{ "current": {} }' >"$FAKE/api.open-meteo.com"
out=$(run "$S/weather.sh" "Lisboa" "" "" "" pt 0 2>/dev/null)
is "a city is geocoded" "$(head -n 1 <<<"$out")" $'Lisboa\t38.7\t-9.1'
grep -q ipinfo "$FAKE/requests" && ko "a city never asks ipinfo.io" || ok "a city never asks ipinfo.io"
is "three lines: place, forecast, air quality ({} when unavailable)" "$(wc -l <<<"$out")" "3"

echo "== update-check.sh"
fresh
G() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main -c commit.gpgsign=false "$@"; }
G init -q "$TMP/origin"
mkdir -p "$TMP/origin/scripts"
echo 1 >"$TMP/origin/file"; echo 1 >"$TMP/origin/scripts/install.sh"
G -C "$TMP/origin" add -A; G -C "$TMP/origin" commit -qm "first"
G clone -q "$TMP/origin" "$TMP/clone"
out=$(run "$S/update-check.sh" "$TMP/clone" "")
is "up to date: behind=0" "$(sed -n 's/^behind=//p' <<<"$out")" "0"
is "up to date: no change listed" "$(grep -c '^change=' <<<"$out")" "0"
echo 2 >"$TMP/origin/file"; G -C "$TMP/origin" commit -qam "second: a file"
echo 2 >"$TMP/origin/scripts/install.sh"; G -C "$TMP/origin" commit -qam "third: the installer"
out=$(run "$S/update-check.sh" "$TMP/clone" "")
is "behind=2 after two new commits" "$(sed -n 's/^behind=//p' <<<"$out")" "2"
is "both commits are listed" "$(grep -c '^change=' <<<"$out")" "2"
grep -q '^change=[0-9a-f]* [0-9-]* third: the installer$' <<<"$out" && ok "a change line is: hash date subject" || ko "a change line is: hash date subject"
is "the target is the remote head" "$(sed -n 's/^target=//p' <<<"$out")" "$(G -C "$TMP/origin" rev-parse HEAD)"
is "installer=1: one file under scripts/ changes" "$(sed -n 's/^installer=//p' <<<"$out")" "1"
out=$(run "$S/update-check.sh" "$TMP/nowhere" "https://github.com/owner/repo" 2>/dev/null)
is "no clone: clone=0" "$(sed -n 's/^clone=//p' <<<"$out")" "0"
is "no clone: the repository is taken from the fallback URL" "$(sed -n 's/^slug=//p' <<<"$out")" "owner/repo"
is "no temporary file is left behind" "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'tmp.*' -newer "$TMP/origin/file" -user "$(id -u)" -type f 2>/dev/null | wc -l)" "0"

echo "== perf-stream.sh / sysmon-stream.sh"
out=$(timeout 4 bash "$S/perf-stream.sh" 1 2>&1 | head -n 6)
is "one block: net, cpu, mem, gpu, self, end" "$(cut -f1 <<<"$out" | tr '\n' ' ')" "net cpu mem gpu self end "
# a process whose name tries to be evaluated as an array subscript
cat >"$TMP/evil.c" <<'C'
#include <sys/prctl.h>
#include <unistd.h>
int main(void) { prctl(PR_SET_NAME, "a]$(touch X)", 0, 0, 0); sleep(4); return 0; }
C
if command -v cc >/dev/null 2>&1 && cc -o "$TMP/evil" "$TMP/evil.c" 2>/dev/null; then
    ( cd "$TMP" && ./evil & )
    sleep 0.3
    err=$( cd "$TMP" && timeout 3 bash "$S/perf-stream.sh" 1 2>&1 >/dev/null | head -n 3 )
    [[ ! -e $TMP/X && -z $err ]] && ok "a hostile process name is neither evaluated nor an error" || ko "a hostile process name is neither evaluated nor an error ($err)"
else
    echo "  skip  no C compiler for the process-name test"
fi
check "sysmon-stream.sh --probe" bash "$S/sysmon-stream.sh" --probe
line=$(timeout 3 bash "$S/sysmon-stream.sh" 1 | head -n 1)
[[ $line =~ ^cpu=-?[0-9]+\ cputemp=-?[0-9]+\ gpu=-?[0-9]+\ gputemp=-?[0-9]+\ ram=[0-9]+\ ramused=[0-9.]+\ ramtotal=[0-9.]+$ ]] && ok "sysmon line format" || ko "sysmon line format ($line)"

echo "== cleanup.sh"
fresh
mkdir -p "$XDG_CACHE_HOME/thumbnails/large" "$XDG_CACHE_HOME/pip"
head -c 2048 /dev/zero >"$XDG_CACHE_HOME/thumbnails/large/a.png"
export XDG_DATA_HOME="$TMP/data-$RANDOM"
out=$(PATH="$BIN:$PATH" bash "$S/cleanup.sh" scan 2>/dev/null)
grep -q "^thumbs|[0-9]*|1|$XDG_CACHE_HOME/thumbnails$" <<<"$out" && ok "scan lists the thumbnails with size and count" || ko "scan lists the thumbnails with size and count"
check "scan removes nothing" test -s "$XDG_CACHE_HOME/thumbnails/large/a.png"
bash "$S/cleanup.sh" run thumbs
check "run thumbs empties the folder" test ! -e "$XDG_CACHE_HOME/thumbnails/large"
bash "$S/cleanup.sh" run nonsense >/dev/null 2>&1
is "an unknown target is refused (exit 2)" "$?" "2"

echo
printf 'passed: %s   failed: %s\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
