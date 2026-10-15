#!/bin/bash
# network-status.sh — indicador de internet REAL para a Waybar (script persistente).
#   Conectado     = há rota padrão E uma requisição HTTP de teste funcionou
#   Sem internet  = há rota padrão (cabo/Wi-Fi), mas a requisição falhou
#   Desconectado  = não há rota padrão
# Uso no módulo: "exec" sem "interval" (+ "restart-interval").

export LC_ALL=C.UTF-8

# URLs de teste (a 1ª deve devolver HTTP 204; a 2ª é a do próprio Arch/NetworkManager)
URL_PRIMARY="http://connectivitycheck.gstatic.com/generate_204"
URL_FALLBACK="https://archlinux.org/check_network_status.txt"

CHECK_ONLINE=20     # s entre testes enquanto há internet
CHECK_OFFLINE=4     # s entre testes enquanto não há (detecta a volta mais rápido)
LOOP=2              # s entre leituras da interface

ICON_WIFI_OK=$'\U000f05a9'
ICON_WIFI_NO=$'\U000f05aa'
ICON_WIRED_OK=$'\U000f0318'
ICON_WIRED_NO=$'\U000f0319'
ICON_OFF=$'\U000f092d'

PARENT=$PPID
trap 'exit 0' TERM INT HUP

esc() {   # escapa para pango + JSON
    local s=$1
    s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}
    s=${s//\\/\\\\}; s=${s//\"/\\\"}
    ESC=$s
}

# interface da rota padrão (menor métrica) -> IFACE
default_iface() {
    local name dest gw flags rc use metric rest best=-1
    IFACE=""
    while read -r name dest gw flags rc use metric rest; do
        [[ $dest == 00000000 ]] || continue
        (( (16#$flags & 3) == 3 )) || continue      # UP + GATEWAY
        if (( best < 0 || metric < best )); then best=$metric; IFACE=$name; fi
    done </proc/net/route
}

# qualidade do Wi-Fi (0-100) -> SIGNAL (vazio se não for Wi-Fi)
wifi_signal() {
    local ifc status link rest q
    SIGNAL=""
    [[ -d /sys/class/net/$1/wireless ]] || return
    while read -r ifc status link rest; do
        [[ $ifc == "$1:" ]] || continue
        q=${link%%.*}
        [[ $q =~ ^[0-9]+$ ]] || return
        SIGNAL=$(( q * 100 / 70 ))
        (( SIGNAL > 100 )) && SIGNAL=100
    done </proc/net/wireless
}

has_internet() {
    local code
    code=$(curl -s -o /dev/null -m 3 --connect-timeout 2 -w '%{http_code}' "$URL_PRIMARY" 2>/dev/null)
    [[ $code == 204 ]] && return 0
    [[ $(curl -fs -m 3 --connect-timeout 2 "$URL_FALLBACK" 2>/dev/null) == *online* ]]
}

command -v curl >/dev/null 2>&1 || { echo '{"text":"curl?","tooltip":"instale o curl","class":"disconnected"}'; exec sleep infinity; }

online=0 last_check=0 prev_iface="" conn="" last=""

while kill -0 "$PARENT" 2>/dev/null; do
    default_iface
    printf -v now '%(%s)T' -1

    if [[ -z $IFACE ]]; then
        online=0 prev_iface="" conn=""
        class="disconnected"; label="Desconectado"; icon=$ICON_OFF
        tip="Sem rede"
    else
        interval=$(( online ? CHECK_ONLINE : CHECK_OFFLINE ))
        if [[ $IFACE != "$prev_iface" ]] || (( now - last_check >= interval )); then
            if has_internet; then online=1; else online=0; fi
            last_check=$now
            if [[ $IFACE != "$prev_iface" ]]; then
                conn=""
                if command -v nmcli >/dev/null 2>&1; then
                    conn=$(timeout 2 nmcli -g GENERAL.CONNECTION device show "$IFACE" 2>/dev/null)
                fi
            fi
            prev_iface=$IFACE
        fi

        wifi_signal "$IFACE"
        if [[ -n $SIGNAL ]]; then ok=$ICON_WIFI_OK no=$ICON_WIFI_NO; else ok=$ICON_WIRED_OK no=$ICON_WIRED_NO; fi

        if (( online )); then
            class="online";      label="Conectado";    icon=$ok
        else
            class="nointernet";  label="Sem internet"; icon=$no
        fi

        esc "$IFACE"; tip="$label\\nInterface: $ESC"
        if [[ -n $conn ]]; then esc "$conn"; tip+="\\nRede: $ESC"; fi
        if [[ -n $SIGNAL ]]; then tip+="\\nSinal: ${SIGNAL}%"; fi
    fi

    json=$(printf '{"text":"%s %s","tooltip":"%s","class":"%s"}' "$icon" "$label" "$tip" "$class")
    if [[ $json != "$last" ]]; then
        printf '%s\n' "$json"
        last=$json
    fi
    sleep "$LOOP"
done
