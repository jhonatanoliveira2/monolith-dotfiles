#!/usr/bin/env bash
# start.sh - launches quickshell with transparent huge pages off for its process (prctl PR_SET_THP_DISABLE).
# With THP set to "always" (Arch's default), every partly used malloc / Mesa region is rounded up to 2 MiB pages:
# the shell measured ~164 MiB of anonymous memory at startup with THP and ~71 MiB without it, and the gap grows
# with uptime. Nothing else changes (same binary, environment and arguments; `exec` keeps the process name).
# Without python3 it simply starts quickshell.
command -v python3 >/dev/null 2>&1 &&
    exec python3 -c 'import ctypes, os, sys; ctypes.CDLL(None).prctl(41, 1, 0, 0, 0); os.execvp("quickshell", ["quickshell"] + sys.argv[1:])' "$@"
exec quickshell "$@"
