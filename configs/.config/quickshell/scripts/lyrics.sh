#!/usr/bin/env bash
# lyrics.sh <artist> <title> <album> <seconds> [sources] - lyrics for services/Lyrics.qml, tried in order:
#   LRCLIB exact match, LRCLIB search (synced, community, strong pt-BR / en coverage), NetEase (synced, large
#   catalog), lyrics.ovh (plain). Synced lyrics win: a plain match is kept and used only when no source has
#   timestamps. Output: "<source><TAB>synced|plain" then the lyrics (LRC when synced), or "none".
# <sources> is a comma-separated list of lrclib, netease, ovh (default: all); the artist, title and album are
#   sent only to the listed ones (Settings > Bar > Player).
# Cache (~/.cache/quickshell-monolith/lyrics): synced lyrics for good; plain lyrics and misses for one day (a
#   synced version may have been added since). A miss is only cached when every source was asked.
export LC_ALL=C.UTF-8
artist=$1 title=$2 album=$3 secs=${4:-0} sources=",${5:-lrclib,netease,ovh},"
use() { [[ $sources == *",$1,"* ]]; }
dir=${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-monolith/lyrics
# file name: at most 200 bytes (a name may not exceed 255; characters can take up to 4), cut at a character boundary
blen() { local LC_ALL=C; BLEN=${#1}; }
key="$artist - $title"; key=${key//\//_}
blen "$key"; while (( BLEN > 200 )); do key=${key%?}; blen "$key"; done
file="$dir/$key.lrc"
mkdir -p "$dir"

if [[ -s $file ]]; then
    read -r head <"$file"
    if [[ $head == *synced ]] || [[ -n $(find "$file" -mmin -1440 2>/dev/null) ]]; then cat "$file"; exit 0; fi
fi

get() { curl -fsS --max-time 8 -A "monolith-shell" "$@" 2>/dev/null; }
plain="" plainSrc=""
emit() {   # emit <source> <synced lyrics> <plain lyrics>
    if [[ -n $2 ]]; then printf '%s\tsynced\n%s\n' "$1" "$2"; else printf '%s\tplain\n%s\n' "$1" "$3"; fi >"$file"
    cat "$file"; exit 0
}

# 1) LRCLIB, exact (duration within 2 s helps it choose the right version)
args=(--data-urlencode "artist_name=$artist" --data-urlencode "track_name=$title")
[[ -n $album ]] && args+=(--data-urlencode "album_name=$album")
(( secs > 0 )) && args+=(-d "duration=$secs")
if use lrclib && r=$(get -G https://lrclib.net/api/get "${args[@]}") && [[ -n $r ]]; then
    s=$(jq -r '.syncedLyrics // ""' <<<"$r"); p=$(jq -r '.plainLyrics // ""' <<<"$r")
    [[ -n $s ]] && emit lrclib "$s" ""
    [[ -n $p ]] && plain=$p plainSrc=lrclib
fi
# 2) LRCLIB search: prefer a synced result
if use lrclib && r=$(get -G https://lrclib.net/api/search --data-urlencode "track_name=$title" --data-urlencode "artist_name=$artist") && [[ -n $r ]]; then
    s=$(jq -r '[.[] | select(.syncedLyrics)][0].syncedLyrics // ""' <<<"$r"); p=$(jq -r '[.[] | select(.plainLyrics)][0].plainLyrics // ""' <<<"$r")
    [[ -n $s ]] && emit lrclib "$s" ""
    [[ -n $p && -z $plain ]] && plain=$p plainSrc=lrclib
fi
# 3) NetEase: the first result whose title matches; credit lines (作词 / 作曲 ...) dropped
if use netease && r=$(get -G https://music.163.com/api/search/get --data-urlencode "s=$artist $title" -d type=1 -d limit=5) && [[ -n $r ]]; then
    id=$(jq -r --arg t "${title,,}" --arg a "${artist,,}" '
        [.result.songs[]? | select((.name | ascii_downcase) == $t and ([.artists[].name | ascii_downcase] | any(. as $n | $a | contains($n))))][0].id // empty' <<<"$r")
    if [[ -n $id ]] && r=$(get "https://music.163.com/api/song/lyric?id=$id&lv=1") && [[ -n $r ]]; then
        s=$(jq -r '.lrc.lyric // ""' <<<"$r" | grep -vE '^\[[0-9:.]+\][^a-zA-Z]{0,20}(作|编|制|混|录|母|吉他|贝斯|鼓|和声|监|出品|发行|企划|统筹)[^:：]*[:：]')
        [[ $s == *"]"[[:alpha:]]* ]] && emit netease "$s" ""
    fi
fi
# 4) no timestamps anywhere: the plain match, else lyrics.ovh
[[ -n $plain ]] && emit "$plainSrc" "" "$plain"
if use ovh && r=$(get "https://api.lyrics.ovh/v1/$(jq -rn --arg a "$artist" '$a | @uri')/$(jq -rn --arg t "$title" '$t | @uri')") && [[ -n $r ]]; then
    p=$(jq -r '.lyrics // ""' <<<"$r" | sed 's/\r//')
    [[ -n $p ]] && emit lyrics.ovh "" "$p"
fi

if use lrclib && use netease && use ovh; then echo none >"$file"; fi
echo none
