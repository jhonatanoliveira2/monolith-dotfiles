#!/bin/bash
# audio-menu.sh — menu Rofi para escolher a saída de áudio (PipeWire/WirePlumber via pactl).
# Clique com o botão direito de novo (ou Esc) fecha o menu.

export LC_ALL=C
THEME="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/rofi/audio-menu.rasi"

# segundo clique fecha o menu aberto
if pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi

for c in pactl rofi; do
    command -v "$c" >/dev/null 2>&1 || { echo "audio-menu: '$c' não encontrado" >&2; exit 1; }
done

default=$(pactl get-default-sink 2>/dev/null)

names=() descs=()
while IFS=$'\t' read -r n d; do
    [[ -n $n ]] || continue
    names+=("$n")
    descs+=("${d:-$n}")
done < <(pactl list sinks 2>/dev/null | awk '
    /^Sink #/            { if (n != "") print n "\t" d; n = ""; d = "" }
    /^\tName: /          { sub(/^\tName: /, "");        n = $0 }
    /^\tDescription: /   { sub(/^\tDescription: /, ""); d = $0 }
    END                  { if (n != "") print n "\t" d }')

if (( ${#names[@]} == 0 )); then
    rofi -theme "$THEME" -e "Nenhuma saída de áudio disponível"
    exit 0
fi

lines=() current=0
for i in "${!names[@]}"; do
    if [[ ${names[i]} == "$default" ]]; then
        lines+=("●  ${descs[i]}"); current=$i
    else
        lines+=("   ${descs[i]}")
    fi
done

sel=$(printf '%s\n' "${lines[@]}" | rofi -dmenu -i -no-custom -p "" \
        -format i -selected-row "$current" -theme "$THEME")
[[ $sel =~ ^[0-9]+$ ]] || exit 0

target=${names[sel]}
pactl set-default-sink "$target" || exit 1

# move os streams que já estão tocando para a nova saída
while read -r id _; do
    pactl move-sink-input "$id" "$target" 2>/dev/null
done < <(pactl list short sink-inputs 2>/dev/null)
