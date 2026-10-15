#!/bin/bash
# power-profile.sh — perfil de energia (power-profiles-daemon) para a Waybar.
# SÓ APARECE EM NOTEBOOK: sem bateria de sistema (desktop) ou sem powerprofilesctl,
# o texto sai vazio e a Waybar esconde o módulo.
#   power-profile.sh status   -> JSON do módulo
#   power-profile.sh cycle    -> power-saver -> balanced -> performance -> ...

export LC_ALL=C.UTF-8

SIGNAL=11            # "signal" do módulo no config
ORDER=(power-saver balanced performance)

ICON_SAVER=$'\uf06c'
ICON_BALANCED=$'\uf24e'
ICON_PERF=$'\uf0e4'

# há bateria do sistema? (ignora baterias de periféricos, scope=Device)
has_battery() {
    local ps type scope
    for ps in /sys/class/power_supply/*; do
        { read -r type <"$ps/type"; } 2>/dev/null || continue
        [[ $type == Battery ]] || continue
        if { read -r scope <"$ps/scope"; } 2>/dev/null && [[ $scope == Device ]]; then continue; fi
        return 0
    done
    return 1
}

get_profile() {
    local out
    PROFILE=""
    if out=$(busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles \
                net.hadess.PowerProfiles ActiveProfile 2>/dev/null) && [[ $out =~ \"(.*)\" ]]; then
        PROFILE=${BASH_REMATCH[1]}
    else
        PROFILE=$(powerprofilesctl get 2>/dev/null)
    fi
    [[ -n $PROFILE ]]
}

status() {
    command -v powerprofilesctl >/dev/null 2>&1 && has_battery && get_profile || { echo '{"text":""}'; return; }
    local icon label
    case $PROFILE in
        power-saver) icon=$ICON_SAVER;    label="Economia" ;;
        performance) icon=$ICON_PERF;     label="Desempenho" ;;
        *)           icon=$ICON_BALANCED; label="Equilibrado" ;;
    esac
    printf '{"text":"%s","tooltip":"Perfil de energia: %s\\nClique para alternar","class":"%s"}\n' "$icon" "$label" "$PROFILE"
}

cycle() {
    command -v powerprofilesctl >/dev/null 2>&1 || exit 0
    get_profile || exit 0
    local line p avail=() i next=""
    # perfis realmente disponíveis (performance pode não existir)
    while IFS= read -r line; do
        [[ $line =~ ^[\ \*]\ ([a-z-]+):$ ]] || continue
        avail+=("${BASH_REMATCH[1]}")
    done < <(powerprofilesctl list 2>/dev/null)
    local seq=()
    for p in "${ORDER[@]}"; do
        for i in "${avail[@]}"; do [[ $i == "$p" ]] && seq+=("$p"); done
    done
    (( ${#seq[@]} > 1 )) || exit 0
    for i in "${!seq[@]}"; do
        if [[ ${seq[i]} == "$PROFILE" ]]; then next=${seq[(i + 1) % ${#seq[@]}]}; break; fi
    done
    [[ -n $next ]] || next=${seq[0]}
    powerprofilesctl set "$next" >/dev/null 2>&1
    pkill -RTMIN+"$SIGNAL" -x waybar 2>/dev/null
}

case $1 in
    status) status ;;
    cycle)  cycle ;;
    *)      echo "uso: ${0##*/} status | cycle" >&2; exit 1 ;;
esac
