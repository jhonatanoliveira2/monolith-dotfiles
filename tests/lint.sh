#!/usr/bin/env bash
# lint.sh - static checks for everything in the repository that runs: shell scripts (bash -n, shellcheck),
# the Hyprland Lua config (luac -p, luacheck), Python tools and the Quickshell QML (qmllint, syntax only: the
# Quickshell types are not known to qmllint, so its type warnings are not a failure).
# A tool that is not installed is reported as "skip" and does not fail the run, unless --strict is given.
# Usage: bash tests/lint.sh [--strict]
set -uo pipefail
export LC_ALL=C.UTF-8

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
STRICT=0; [[ ${1:-} == --strict ]] && STRICT=1
FAIL=0 SKIP=0
ok() { printf '  ok    %s\n' "$1"; }
ko() { FAIL=$(( FAIL + 1 )); printf '  FAIL  %s\n' "$1"; }
skip() { SKIP=$(( SKIP + 1 )); printf '  skip  %s (not installed)\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
run() { # run <description> <command...>: passes when the command succeeds; its output is shown on failure
    local d=$1 out
    shift
    if out=$("$@" 2>&1); then ok "$d"; else ko "$d"; printf '%s\n' "$out" | sed 's/^/        /' | head -n 40; fi
}

# tracked (and new, not ignored) files; every file outside a git checkout
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mapfile -t FILES < <(git ls-files -co --exclude-standard)
else
    mapfile -t FILES < <(find . -type f -not -path './.git/*' | sed 's#^\./##')
fi

SH=() LUA=() PY=() QML_DIRS=()
for f in "${FILES[@]}"; do
    [[ -f $f ]] || continue
    case $f in
        *.lua) case $f in configs/.config/hypr/*) LUA+=("$f") ;; esac; continue ;;
        *.py) PY+=("$f"); continue ;;
        *.sh) SH+=("$f"); continue ;;
        *.qml | *.md | *.png | *.jpg | *.jpeg | *.webp | *.svg | *.gif | *.mp4 | *.ttf | *.otf | *.nix | *.json | *.lock) continue ;;
    esac
    # extensionless scripts (configs/.local/bin/*): told by their shebang
    IFS= read -r first <"$f" 2>/dev/null || continue
    case $first in '#!'*bash* | '#!'*/sh | '#!'*' sh') SH+=("$f") ;; '#!'*python*) PY+=("$f") ;; esac
done
for d in configs/.config/quickshell greeter tests/qml; do [[ -d $d ]] && QML_DIRS+=("$d"); done

echo "== shell (${#SH[@]} scripts)"
run "bash -n" bash -c 'r=0; for f; do bash -n "$f" || r=1; done; exit $r' _ "${SH[@]}"
if have shellcheck; then run "shellcheck" shellcheck "${SH[@]}"; else skip shellcheck; fi

echo "== lua (${#LUA[@]} files)"
if (( ${#LUA[@]} )); then
    if have luac; then run "luac -p" luac -p "${LUA[@]}"; else skip luac; fi
    if have luacheck; then run "luacheck" luacheck -q --no-color "${LUA[@]}"; else skip luacheck; fi
fi

echo "== python (${#PY[@]} files)"
if (( ${#PY[@]} )); then
    if have python3; then
        run "python syntax" python3 -c 'import ast, sys
for p in sys.argv[1:]:
    ast.parse(open(p, encoding="utf-8").read(), p)' "${PY[@]}"
    else skip python3; fi
fi

echo "== qml"
QMLLINT=""
for c in qmllint qmllint6 qmllint-qt6 /usr/lib/qt6/bin/qmllint /usr/lib64/qt6/bin/qmllint; do
    if have "$c"; then QMLLINT=$c; break; fi
done
if [[ -n $QMLLINT ]]; then
    for d in "${QML_DIRS[@]}"; do
        mapfile -t Q < <(find "$d" -name '*.qml' | LC_ALL=C sort)
        # syntax errors only: they are the lines that start with "Error"
        errs=$("$QMLLINT" "${Q[@]}" 2>&1 | grep -E '^Error|: error:|Failed to parse' || true)
        if [[ -z $errs ]]; then ok "qmllint syntax: $d (${#Q[@]} files)"; else ko "qmllint syntax: $d"; printf '%s\n' "$errs" | sed 's/^/        /' | head -n 40; fi
    done
else
    skip qmllint
fi

echo
printf 'failed: %s   skipped: %s\n' "$FAIL" "$SKIP"
(( STRICT && SKIP > 0 )) && exit 1
(( FAIL == 0 ))
