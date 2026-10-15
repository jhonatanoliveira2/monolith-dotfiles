#!/bin/bash
# player.sh — player MPRIS compacto para a Waybar (YouTube Music no Zen/Firefox, Spotify, mpv...).
#
# Visual: recolhido mostra só "símbolo + título"; ao passar o mouse (drawer) aparecem
# anterior / play-pause / próxima + barra de progresso e tempo.
#
#   player.sh text                      módulo "custom/player"   (persistente: título + símbolo)
#   player.sh progress                  módulo "custom/player-progress" (barra + tempo)
#   player.sh button prev|toggle|next   botões ("interval":"once" + "signal")
#   player.sh ctl prev|toggle|next|seek+|seek-   ações de clique
#
# Escolhe o player ativo sozinho: o primeiro "Playing"; se nenhum, o primeiro "Paused".
# Só o módulo de texto consulta o playerctl; os demais leem arquivos em $XDG_RUNTIME_DIR.

export LC_ALL=C.UTF-8

SIGNAL=10            # precisa ser o "signal" dos 3 botões no config
TITLE_MAX=16         # tamanho máximo do título exibido (inclui o "…")
SHOW_ARTIST=0        # 1 = mostra "Título - Artista" (o artista também respeita ARTIST_MAX)
ARTIST_MAX=12
BAR_CELLS=8          # tamanho da barra de progresso
IGNORE=''            # regex de players a ignorar, ex.: '^(kdeconnect|chromecast)'

RUN="${XDG_RUNTIME_DIR:-/tmp}"
STATE="$RUN/waybar-player.state"
PROGRESS="$RUN/waybar-player.progress"

ICON_NOTE='󰺢'     		 # símbolo: tocando
ICON_PAUSED=$'\uf04c'    # símbolo: pausado
ICON_PREV=$'\uf048'
ICON_NEXT=$'\uf051'
ICON_PLAY=$'\uf04b'
ICON_PAUSE=$'\uf04c'

SEP=$'\x1f'
PLAYER="" STATUS="" TITLE="" ARTIST="" POS=0 LEN=0

# escapa para pango + JSON -> ESC
esc() {
    local s=$1
    s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}
    s=${s//\\/\\\\}; s=${s//\"/\\\"}
    s=${s//$'\n'/ }; s=${s//$'\r'/ }; s=${s//$'\t'/ }
    ESC=$s
}

# microssegundos -> m:ss ou h:mm:ss  (resultado em TIME)
fmt_time() {
    local s=$(( $1 / 1000000 )) h m sec
    h=$(( s / 3600 )); m=$(( s % 3600 / 60 )); sec=$(( s % 60 ))
    if (( h > 0 )); then printf -v TIME '%d:%02d:%02d' "$h" "$m" "$sec"
    else printf -v TIME '%d:%02d' "$m" "$sec"; fi
}

# barra de progresso ━━●─────  (resultado em BAR)
make_bar() {
    local idx i out=""
    idx=$(( $1 * BAR_CELLS / $2 ))
    (( idx >= BAR_CELLS )) && idx=$(( BAR_CELLS - 1 ))
    for (( i = 0; i < BAR_CELLS; i++ )); do
        if   (( i < idx )); then out+="━"
        elif (( i == idx )); then out+="●"
        else out+="─"
        fi
    done
    BAR=$out
}

# define PLAYER/STATUS/TITLE/ARTIST/POS/LEN do player ativo; retorna 1 se não houver
pick_player() {
    local inst st ti ar pos len p="" ps="" pt="" pa="" ppos=0 plen=0
    PLAYER="" STATUS="" TITLE="" ARTIST="" POS=0 LEN=0
    while IFS="$SEP" read -r inst st ti ar pos len; do
        [[ -n $inst ]] || continue
        [[ -n $IGNORE && $inst =~ $IGNORE ]] && continue
        [[ $pos =~ ^[0-9]+$ ]] || pos=0
        [[ $len =~ ^[0-9]+$ ]] || len=0
        case $st in
            Playing)
                PLAYER=$inst STATUS=$st TITLE=$ti ARTIST=$ar POS=$pos LEN=$len
                return 0 ;;
            Paused)
                if [[ -z $p ]]; then p=$inst ps=$st pt=$ti pa=$ar ppos=$pos plen=$len; fi ;;
        esac
    done < <(timeout 2 playerctl -a metadata \
        --format "{{playerInstance}}${SEP}{{status}}${SEP}{{title}}${SEP}{{artist}}${SEP}{{position}}${SEP}{{mpris:length}}" 2>/dev/null)

    [[ -n $p ]] || return 1
    PLAYER=$p STATUS=$ps TITLE=$pt ARTIST=$pa POS=$ppos LEN=$plen
}

# monta JSON (título + símbolo) e PROG (barra + tempo)
build_json() {
    local label cur tot text tip a sym ptxt
    label=$TITLE
    if (( ${#label} > TITLE_MAX )); then label="${label:0:TITLE_MAX-1}…"; fi
    if (( SHOW_ARTIST )) && [[ -n $ARTIST ]]; then
        a=$ARTIST
        if (( ${#a} > ARTIST_MAX )); then a="${a:0:ARTIST_MAX-1}…"; fi
        label+=" - $a"
    fi
    if [[ -z $label ]]; then
        label=${PLAYER%%.*}
        if (( ${#label} > TITLE_MAX )); then label="${label:0:TITLE_MAX-1}…"; fi
    fi

    fmt_time "$POS"; cur=$TIME
    if (( LEN > 0 )); then
        fmt_time "$LEN"; tot=$TIME
        make_bar "$POS" "$LEN"
        ptxt="$BAR  $cur/$tot"
    else
        tot=""
        ptxt=$cur
    fi

    if [[ $STATUS == Playing ]]; then sym=$ICON_NOTE; else sym=$ICON_PAUSED; fi
    esc "$label"; text="$sym  $ESC"

    esc "$TITLE";  tip=$ESC
    esc "$ARTIST"; [[ -n $ESC ]] && tip+="\\n$ESC"
    if [[ -n $tot ]]; then tip+="\\n$cur / $tot"; else tip+="\\n$cur"; fi
    esc "${PLAYER%%.*}"; tip+="\\n$ESC"

    JSON=$(printf '{"text":"%s","tooltip":"%s","class":"%s"}' "$text" "$tip" "${STATUS,,}")
    esc "$ptxt"
    PROG=$(printf '{"text":"%s","class":"%s"}' "$ESC" "${STATUS,,}")
}

text_loop() {
    local parent=$PPID last="" last_state="" state wait now
    trap 'exit 0' TERM INT HUP

    if ! command -v playerctl >/dev/null 2>&1; then
        echo '{"text":"playerctl?","tooltip":"instale o playerctl"}'
        exec sleep infinity
    fi

    while kill -0 "$parent" 2>/dev/null; do
        if pick_player; then
            state=$STATUS
            build_json
            wait=1
            [[ $STATUS == Playing ]] || wait=2
        else
            state=none
            JSON='{"text":""}'
            PROG='{"text":""}'
            wait=3
        fi

        if [[ $state != "$last_state" ]]; then
            printf '%s\n' "$state" >"$STATE.tmp" && mv -f "$STATE.tmp" "$STATE"
            pkill -RTMIN+"$SIGNAL" -x waybar 2>/dev/null
            last_state=$state
        fi

        # progresso: lido (sem playerctl) pelo módulo custom/player-progress
        printf -v now '%(%s)T' -1
        printf '%s\t%s\n' "$now" "$PROG" >"$PROGRESS"

        if [[ $JSON != "$last" ]]; then
            printf '%s\n' "$JSON"
            last=$JSON
        fi
        sleep "$wait"
    done
}

progress() {
    local ts json now
    if [[ -r $PROGRESS ]] && IFS=$'\t' read -r ts json <"$PROGRESS" \
        && [[ $ts =~ ^[0-9]+$ && $json == '{'*'}' ]]; then
        printf -v now '%(%s)T' -1
        if (( now - ts <= 6 )); then printf '%s\n' "$json"; return; fi
    fi
    echo '{"text":""}'
}

button() {
    local st="" icon
    [[ -r $STATE ]] && read -r st <"$STATE"
    case $st in
        Playing|Paused) ;;
        *) echo '{"text":""}'; return ;;
    esac
    case $1 in
        prev)   icon=$ICON_PREV ;;
        next)   icon=$ICON_NEXT ;;
        toggle) if [[ $st == Playing ]]; then icon=$ICON_PAUSE; else icon=$ICON_PLAY; fi ;;
        *)      echo '{"text":""}'; return ;;
    esac
    printf '{"text":"%s"}\n' "$icon"
}

ctl() {
    command -v playerctl >/dev/null 2>&1 || exit 0
    pick_player || exit 0
    case $1 in
        prev)   playerctl --player="$PLAYER" previous ;;
        next)   playerctl --player="$PLAYER" next ;;
        toggle) playerctl --player="$PLAYER" play-pause ;;
        seek+)  playerctl --player="$PLAYER" position 5+ ;;
        seek-)  playerctl --player="$PLAYER" position 5- ;;
    esac >/dev/null 2>&1
}

case $1 in
    text)     text_loop ;;
    progress) progress ;;
    button)   button "$2" ;;
    ctl)      ctl "$2" ;;
    *)        echo "uso: ${0##*/} text | progress | button prev|toggle|next | ctl prev|toggle|next|seek+|seek-" >&2; exit 1 ;;
esac
