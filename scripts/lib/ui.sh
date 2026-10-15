#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are shared with the scripts that source this file
# ui.sh - terminal interface: colours (graphite + cyan), banner, panels, steps, progress, prompts.
# Falls back to plain ASCII / no colour when the terminal cannot handle it (or NO_COLOR is set).

UI_COLOR=0
UI_UTF8=0
UI_TTY=0
UI_INTERACTIVE=0
UI_WIDTH=72
OPT_YES=${OPT_YES:-0}

C_RESET="" C_BOLD="" C_DIM="" C_CYAN="" C_CYAN2="" C_GRAPH="" C_GRAPH2="" C_TEXT="" C_WARN="" C_ERR=""
UI_GRADIENT=()

# ui_init: detect capabilities. Honour NO_COLOR and --no-color (OPT_NO_COLOR=1).
ui_init() {
    [[ -t 1 ]] && UI_TTY=1
    [[ -t 0 && -t 1 ]] && UI_INTERACTIVE=1
    local loc=${LC_ALL:-${LC_CTYPE:-${LANG:-}}}
    [[ $loc =~ [Uu][Tt][Ff]-?8 ]] && UI_UTF8=1
    local colors=0
    if (( UI_TTY )) && [[ -z ${NO_COLOR-} && ${TERM:-dumb} != dumb && ${OPT_NO_COLOR:-0} != 1 ]]; then
        UI_COLOR=1
        colors=$(tput colors 2>/dev/null || echo 8)
    fi
    if (( UI_COLOR )); then
        C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_DIM=$'\e[2m'
        if (( colors >= 256 )); then
            C_CYAN=$'\e[38;5;51m' C_CYAN2=$'\e[38;5;37m'
            C_GRAPH=$'\e[38;5;245m' C_GRAPH2=$'\e[38;5;240m'
            C_TEXT=$'\e[38;5;252m' C_WARN=$'\e[38;5;179m' C_ERR=$'\e[38;5;167m'
            UI_GRADIENT=($'\e[38;5;240m' $'\e[38;5;242m' $'\e[38;5;245m' $'\e[38;5;37m' $'\e[38;5;44m' $'\e[38;5;51m')
        else
            C_CYAN=$'\e[36m' C_CYAN2=$'\e[36m' C_GRAPH=$'\e[90m' C_GRAPH2=$'\e[90m'
            C_TEXT=$'\e[37m' C_WARN=$'\e[33m' C_ERR=$'\e[31m'
            UI_GRADIENT=($'\e[90m' $'\e[90m' $'\e[37m' $'\e[36m' $'\e[36m' $'\e[36m')
        fi
    fi
    if (( UI_UTF8 )); then
        G_TL='╭' G_TR='╮' G_BL='╰' G_BR='╯' G_H='─' G_V='│'
        G_ON='━' G_OFF='─' G_OK='✔' G_ERR='✘' G_WARN='▲' G_INFO='◆' G_ARROW='›' G_DOT='•'
        G_SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    else
        G_TL='+' G_TR='+' G_BL='+' G_BR='+' G_H='-' G_V='|'
        G_ON='#' G_OFF='-' G_OK='ok' G_ERR='xx' G_WARN='!!' G_INFO='*' G_ARROW='>' G_DOT='-'
        G_SPIN=('|' '/' '-' '\')
    fi
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    UI_WIDTH=$(( cols < 72 ? cols - 2 : 72 ))
    (( UI_WIDTH >= 50 )) || UI_WIDTH=50
}

ui_clear() { (( UI_TTY )) && [[ ${OPT_NO_CLEAR:-0} != 1 ]] && printf '\e[H\e[2J\e[3J'; return 0; }

# repeat <string> <count>
_rep() {
    local s=$1 n=$2 out=""
    (( n > 0 )) || return 0
    printf -v out '%*s' "$n" ''
    printf '%s' "${out// /$s}"
}

ui_banner() {
    local rows=(
    '███╗   ███╗ ██████╗ ███╗   ██╗ ██████╗ ██╗     ██╗████████╗██╗  ██╗'
    '████╗ ████║██╔═══██╗████╗  ██║██╔═══██╗██║     ██║╚══██╔══╝██║  ██║'
    '██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║██║     ██║   ██║   ███████║'
    '██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║██║     ██║   ██║   ██╔══██║'
    '██║ ╚═╝ ██║╚██████╔╝██║ ╚████║╚██████╔╝███████╗██║   ██║   ██║  ██║'
    '╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝   ╚═╝  ╚═╝'
    ) i row color
    printf '\n'
    if (( UI_UTF8 )); then
        for i in "${!rows[@]}"; do
            row=${rows[i]}
            color=${UI_GRADIENT[i]-}
            printf '  %s%s%s\n' "$color" "$row" "$C_RESET"
        done
    else
        printf '  %s%s%s\n' "$C_CYAN" 'M O N O L I T H' "$C_RESET"
    fi
    printf '\n  %s%s%s %s%s%s\n' "$C_CYAN" "$G_INFO" "$C_RESET" "$C_GRAPH" "$(t banner.tagline)" "$C_RESET"
    printf '  %s%s  v%s%s\n\n' "$C_GRAPH2" "$(_rep "$G_H" $(( UI_WIDTH - 4 )))" "${MONOLITH_VERSION:-0}" "$C_RESET"
}

# _panel_row <inner> <text>: one boxed row, padded by characters (not bytes).
_panel_row() {
    local LC_ALL=C.UTF-8 inner=$1 line=$2 pad
    pad=$(( inner - ${#line} ))
    (( pad >= 0 )) || pad=0
    printf '  %s%s%s %s%s%*s %s%s%s\n' "$C_GRAPH2" "$G_V" "$C_RESET" "$C_TEXT" "$line" "$pad" '' "$C_GRAPH2" "$G_V" "$C_RESET"
}

# ui_panel <title> <line...>: boxed panel; long lines are wrapped at spaces.
ui_panel() {
    local LC_ALL=C.UTF-8 title=$1 line piece first inner=$(( UI_WIDTH - 4 ))
    shift
    printf '  %s%s%s %s%s%s %s%s%s\n' "$C_GRAPH2" "$G_TL" "$G_H" "$C_CYAN" "$title" "$C_GRAPH2" \
        "$(_rep "$G_H" $(( inner - ${#title} - 1 )))" "$G_TR" "$C_RESET"
    for line in "$@"; do
        if (( ${#line} <= inner )); then
            _panel_row "$inner" "$line"
            continue
        fi
        first=1
        while IFS= read -r piece; do
            piece=${piece%" "}
            if (( first )); then first=0; else piece="     ${piece# }"; fi
            _panel_row "$inner" "$piece"
        done < <(printf '%s\n' "$line" | fold -s -w $(( inner - 5 )))
    done
    printf '  %s%s%s%s%s\n' "$C_GRAPH2" "$G_BL" "$(_rep "$G_H" $(( inner + 2 )))" "$G_BR" "$C_RESET"
}

# ui_bar <current> <total> [width]: print a bar like ━━━━────  (no newline)
ui_bar() {
    local cur=$1 total=$2 width=${3:-24} filled
    (( total > 0 )) || total=1
    filled=$(( cur * width / total ))
    (( filled > width )) && filled=$width
    printf '%s%s%s%s%s' "$C_CYAN" "$(_rep "$G_ON" "$filled")" "$C_GRAPH2" "$(_rep "$G_OFF" $(( width - filled )))" "$C_RESET"
}

# ui_step <n> <total> <title>
ui_step() {
    printf '\n  %s%s%s %s[%s/%s]%s %s%s%s\n' "$C_CYAN" "$G_INFO" "$C_RESET" "$C_GRAPH" "$1" "$2" "$C_RESET" "$C_BOLD$C_TEXT" "$3" "$C_RESET"
    printf '    '
    ui_bar "$1" "$2" 30
    printf '\n\n'
}

ui_info() { printf '    %s%s%s %s\n' "$C_GRAPH" "$G_ARROW" "$C_RESET" "$*"; }
ui_ok()   { printf '    %s%s%s %s\n' "$C_CYAN" "$G_OK" "$C_RESET" "$*"; }
ui_warn() { printf '    %s%s%s %s%s%s\n' "$C_WARN" "$G_WARN" "$C_RESET" "$C_WARN" "$*" "$C_RESET" >&2; }
ui_err()  { printf '    %s%s%s %s%s%s\n' "$C_ERR" "$G_ERR" "$C_RESET" "$C_ERR" "$*" "$C_RESET" >&2; }
ui_dim()  { printf '      %s%s%s\n' "$C_GRAPH" "$*" "$C_RESET"; }
ui_kv()   { printf '    %s%-22s%s %s\n' "$C_GRAPH" "$1" "$C_RESET" "$2"; }

# ui_progress <current> <total> <label>: single-line progress (TTY only).
ui_progress() {
    (( UI_TTY )) || return 0
    local LC_ALL=C.UTF-8 cur=$1 total=$2 label=${3:-} pct
    (( total > 0 )) || total=1
    pct=$(( cur * 100 / total ))
    printf '\r\e[K    '
    ui_bar "$cur" "$total" 24
    printf ' %s%3d%%%s  %s%s%s' "$C_TEXT" "$pct" "$C_RESET" "$C_GRAPH" "${label:0:34}" "$C_RESET"
}
ui_progress_end() { (( UI_TTY )) && printf '\r\e[K'; return 0; }

# ui_spin <label> <command...>: run an external command with a spinner (output goes to the log).
ui_spin() {
    local label=$1 pid i=0 rc
    shift
    if (( ! UI_TTY )); then
        ui_info "$label"
        "$@" >>"$LOG_FILE" 2>&1
        return $?
    fi
    "$@" >>"$LOG_FILE" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r\e[K    %s%s%s %s' "$C_CYAN" "${G_SPIN[i % ${#G_SPIN[@]}]}" "$C_RESET" "$label"
        i=$(( i + 1 ))
        sleep 0.1
    done
    rc=0
    wait "$pid" || rc=$?
    printf '\r\e[K'
    return "$rc"
}

# ui_confirm <prompt> [default y|n]: yes/no question. With --yes it answers the default.
ui_confirm() {
    local prompt=$1 def=${2:-y} ans hint
    if (( OPT_YES )); then
        [[ $def == y ]]
        return
    fi
    if [[ $def == y ]]; then hint="$(t prompt.yes_hint)"; else hint="$(t prompt.no_hint)"; fi
    while true; do
        printf '    %s?%s %s %s[%s]%s ' "$C_CYAN" "$C_RESET" "$prompt" "$C_GRAPH" "$hint" "$C_RESET"
        IFS= read -r ans || return 1
        case ${ans,,} in
            '') [[ $def == y ]]; return ;;
            y | yes | s | sim) return 0 ;;
            n | no | nao | não) return 1 ;;
        esac
    done
}

# ui_choose_language <suggested>: interactive language menu; prints the chosen id.
ui_choose_language() {
    local suggested=${1:-en} ans def=1 out
    [[ $suggested == pt_BR ]] && def=2
    out=/dev/stderr
    {
        printf '\n'
        ui_panel "Language / Idioma" \
            "" \
            "  1) English" \
            "  2) Português (Brasil)" \
            ""
        printf '\n'
    } >"$out"
    while true; do
        printf '    %s?%s Select / Selecione [1-2] %s(Enter = %s)%s ' "$C_CYAN" "$C_RESET" "$C_GRAPH" "$def" "$C_RESET" >"$out"
        IFS= read -r ans || { echo "$suggested"; return; }
        [[ -z $ans ]] && ans=$def
        if normalize_lang "$ans"; then return; fi
    done
}
