#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are shared with the scripts that source this file
# i18n.sh - tiny translation layer. English is the default language.
#   _m <key> "<english>" "<pt_BR>"   register a message (see messages.sh)
#   t <key> [printf args...]         print a message in the active language

declare -gA MSG_en=()
declare -gA MSG_pt_BR=()
MONOLITH_LANG_USER=${MONOLITH_LANG-}   # what the user exported (if anything)
MONOLITH_LANG=${MONOLITH_LANG:-en}

_m() {
    MSG_en[$1]=$2
    MSG_pt_BR[$1]=$3
}

# normalize_lang <value>: map user input to a supported language id (en | pt_BR).
normalize_lang() {
    local v=${1,,}
    v=${v//-/_}
    case $v in
        pt | pt_br | pt_br.* | pt_* | portuguese | 2) echo pt_BR ;;
        en | en_* | english | 1) echo en ;;
        *) return 1 ;;
    esac
}

# detect_system_lang: language suggested by the environment (defaults to en).
detect_system_lang() {
    local v=${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}
    normalize_lang "${v%%.*}" 2>/dev/null || echo en
}

# t <key> [args...]
t() {
    local key=$1 fmt
    shift
    case $MONOLITH_LANG in
        pt_BR) fmt=${MSG_pt_BR[$key]-} ;;
        *) fmt=${MSG_en[$key]-} ;;
    esac
    [[ -n $fmt ]] || fmt=${MSG_en[$key]-$key}
    # shellcheck disable=SC2059  # the message catalogue is the format string on purpose
    printf "$fmt" "$@"
}
