#!/bin/bash
# waybar-launch.sh — inicia a Waybar com a config certa para a máquina.
#   laptop:  usa config.jsonc inteira (bateria, perfil de energia, sliders de brilho e volume).
#   desktop: gera uma cópia sem as linhas marcadas "@laptop-only" e com o volume simples.
#
# Modo: automático (bateria de sistema => laptop). Para forçar, crie o arquivo
#   ~/.config/waybar/mode   contendo  laptop  ou  desktop   (o install.sh --mode faz isso).
#
# No Hyprland:  exec-once = ~/.config/waybar/scripts/waybar-launch.sh
# (rodar de novo reinicia a Waybar — útil como atalho de "recarregar")

DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
SRC="$DIR/config.jsonc"
STYLE="$DIR/style.css"

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

MODE=auto
[[ -r $DIR/mode ]] && read -r MODE <"$DIR/mode"
case $MODE in
    laptop)  laptop=1 ;;
    desktop) laptop=0 ;;
    *)       if has_battery; then laptop=1; else laptop=0; fi ;;
esac

if (( laptop )); then
    CONFIG=$SRC
else
    CONFIG="${XDG_RUNTIME_DIR:-/tmp}/waybar-desktop.jsonc"
    sed -e '/@laptop-only/d' \
        -e '/@laptop-swap/ s#"group/volume"#"pulseaudio"#' \
        "$SRC" >"$CONFIG"
fi

pkill -x waybar 2>/dev/null && sleep 0.3
exec waybar -c "$CONFIG" -s "$STYLE"
