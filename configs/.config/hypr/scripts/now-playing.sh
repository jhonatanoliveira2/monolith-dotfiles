#!/bin/bash
# Lock screen media controls (hypr/hyprlock.conf), polled every 500 ms:
#   (no arguments)                   title - artist, scrolling when long
#   previous | pause | next          the button glyphs
#   ctl previous|play-pause|next     runs the action on the active player
# Prints nothing (the labels stay empty) without playerctl or a player.

export LC_ALL=C.UTF-8

MAX_CHARS=60
DISPLAY_CHARS=30
ICON_PREV="⟨"
ICON_PAUSE=" Ⅱ "     # shown while playing
ICON_PLAY=" ▶ "      # shown while paused
ICON_NEXT="⟩"

command -v playerctl >/dev/null 2>&1 || exit 0

PLAYER="" STATUS="" TITLE="" ARTIST=""

# The first player that is playing, else the first paused one.
pick_player() {
    local sep=$'\x1f' inst st ti ar p="" ps="" pt="" pa=""
    while IFS="$sep" read -r inst st ti ar; do
        [ -n "$inst" ] || continue
        case $st in
            Playing)
                PLAYER=$inst STATUS=$st TITLE=$ti ARTIST=$ar
                return 0 ;;
            Paused)
                if [ -z "$p" ]; then p=$inst ps=$st pt=$ti pa=$ar; fi ;;
        esac
    done < <(playerctl -a metadata \
        --format "{{playerInstance}}${sep}{{status}}${sep}{{title}}${sep}{{artist}}" 2>/dev/null)

    [ -n "$p" ] || return 1
    PLAYER=$p STATUS=$ps TITLE=$pt ARTIST=$pa
}

pick_player || exit 0

case "$1" in
    ctl)
        case "$2" in
            previous|next|play-pause) exec playerctl --player="$PLAYER" "$2" >/dev/null 2>&1 ;;
        esac
        exit 0 ;;
    previous) printf '%s\n' "$ICON_PREV"; exit 0 ;;
    next)     printf '%s\n' "$ICON_NEXT"; exit 0 ;;
    pause)
        if [ "$STATUS" = "Playing" ]; then printf '%s\n' "$ICON_PAUSE"
        else printf '%s\n' "$ICON_PLAY"; fi
        exit 0 ;;
esac

# --- title ---
TITLE=${TITLE//$'\n'/ }
ARTIST=${ARTIST//$'\n'/ }
if [ -n "$ARTIST" ]; then text="$TITLE - $ARTIST"; else text="$TITLE"; fi
[ -n "$text" ] || exit 0

if [ "${#text}" -gt "$MAX_CHARS" ]; then
    text="${text:0:$((MAX_CHARS - 1))}…"
fi
text="$text     "
len=${#text}

if [ "$len" -le "$DISPLAY_CHARS" ]; then
    visible=$text
else
    printf -v now '%(%s)T' -1          # no `date` fork
    pos=$(( now % len ))
    doubled="$text$text"
    visible="${doubled:pos:DISPLAY_CHARS}"
fi

# escaped for the label's Pango markup
visible=${visible//&/&amp;}
visible=${visible//</&lt;}
visible=${visible//>/&gt;}

printf '♪  %s\n' "$visible"
