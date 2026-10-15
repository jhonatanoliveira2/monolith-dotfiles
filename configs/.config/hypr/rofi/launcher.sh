#!/bin/bash
# launcher.sh — lançador de aplicativos (Rofi, modo drun) no estilo da Waybar.
# Chamar de novo com o menu aberto fecha o menu.
#
# Variáveis opcionais:
LAUNCHER_ICONS=1  

export LC_ALL=C.UTF-8   # garante que $'\uXXXX' vire o glifo, não texto

THEME="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/launcher.rasi"

if pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi

command -v rofi >/dev/null 2>&1 || { echo "launcher: 'rofi' não encontrado" >&2; exit 1; }

args=(-show drun
      -theme "$THEME"
      -display-drun $'\uf002'
      -drun-display-format '{name}'
      -matching fuzzy
      -sort)
[[ ${LAUNCHER_ICONS:-0} == 1 ]] && args+=(-show-icons)

exec rofi "${args[@]}"
