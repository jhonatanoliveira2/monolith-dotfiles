#!/usr/bin/env bash
# perf-stream.sh [interval] - center menu Performance tab (services/Perf.qml); runs only while it is open.
# Every N seconds (default 2) a block of tab-separated lines, then "end":
#   net  <rx B/s> <tx B/s> <rx total> <tx total>          (all interfaces but lo, totals since boot)
#   cpu  name pct name pct name pct                         top 3 apps (same-name processes summed), % of the whole CPU
#   mem  name bytes ...                                     top 3 by resident memory
#   gpu  name pct ...                                       top 3 by GPU time (DRM fdinfo, engine gfx + compute)
#   self cpu% rss gpu%                                      the shell itself (the parent of this script)
# Bash builtins only (no forks): one /proc/<pid>/stat read per process per sample. DRM clients are found by
# scanning file descriptors once every 10 samples; in between only their fdinfo files are read.
export LC_ALL=C
shopt -s nullglob
INTERVAL=${1:-2}
SELF=$PPID
# page size and clock ticks of this kernel (16 KiB pages on some ARM systems); read once, the loop stays fork-free
PAGE=$(getconf PAGESIZE 2>/dev/null) || PAGE=4096
HZ=$(getconf CLK_TCK 2>/dev/null) || HZ=100
ncpu=0; while read -r k _; do [[ $k == processor ]] && (( ncpu++ )); done </proc/cpuinfo; (( ncpu > 0 )) || ncpu=1
nodes=(/dev/dri/renderD* /dev/dri/card*)

exec {fd}<> <(:)    # "read -t" on a pipe nobody writes to: a fork-free sleep

declare -A prevTicks prevGpu
declare -a gpuFiles=()
prevRx=0 prevTx=0 prevT=0 n=0

top3() {    # top3 <assoc name> -> "name<TAB>value..." of the three largest values
    local -n a=$1
    local k b1="" b2="" b3="" v1=-1 v2=-1 v3=-1
    for k in "${!a[@]}"; do
        local v=${a[$k]}
        if (( v > v1 )); then b3=$b2 v3=$v2 b2=$b1 v2=$v1 b1=$k v1=$v
        elif (( v > v2 )); then b3=$b2 v3=$v2 b2=$k v2=$v
        elif (( v > v3 )); then b3=$k v3=$v; fi
    done
    out=""
    [[ -n $b1 ]] && out+=$'\t'"$b1"$'\t'"$v1"
    [[ -n $b2 ]] && out+=$'\t'"$b2"$'\t'"$v2"
    [[ -n $b3 ]] && out+=$'\t'"$b3"$'\t'"$v3"
}

scan_gpu() {    # fdinfo paths of every open DRM node
    gpuFiles=()
    local d f node
    for d in /proc/[0-9]*; do
        for f in "$d"/fd/*; do
            for node in "${nodes[@]}"; do
                [[ $f -ef $node ]] && { gpuFiles+=("${d}/fdinfo/${f##*/}"); break; }
            done
        done
    done
}

while :; do
    now=$(( 10#${EPOCHREALTIME/[.,]/} ))    # µs (either decimal separator)
    dt=$(( now - prevT )); (( prevT > 0 && dt > 0 )) || dt=0
    prevT=$now

    # --- network ---
    rx=0 tx=0
    { read -r _; read -r _
      while read -r ifc r _ _ _ _ _ _ _ t _; do
          [[ $ifc == lo: ]] && continue
          (( rx += r, tx += t ))
      done; } </proc/net/dev
    if (( dt > 0 && prevRx > 0 )); then
        printf 'net\t%d\t%d\t%d\t%d\n' $(( (rx - prevRx) * 1000000 / dt )) $(( (tx - prevTx) * 1000000 / dt )) "$rx" "$tx"
    else
        printf 'net\t0\t0\t%d\t%d\n' "$rx" "$tx"
    fi
    prevRx=$rx prevTx=$tx

    # --- processes: CPU ticks and resident memory ---
    declare -A cpuBy=() memBy=() curTicks=()
    selfCpu=0 selfRss=0
    for d in /proc/[0-9]*; do
        { read -r st <"$d/stat"; } 2>/dev/null || continue
        pid=${d#/proc/}
        name=${st#*(}; name=${name%)*}
        # the name is chosen by the process (prctl) and becomes an array subscript inside (( )): keep only harmless
        # characters, so no bash version can expand it (older ones evaluate $(...) and `...` in a subscript)
        name=${name//[^A-Za-z0-9 ._:+@\/-]/_}
        # shellcheck disable=SC2086  # word splitting wanted: the fields of /proc/<pid>/stat
        set -- ${st##*) }
        ticks=$(( ${12} + ${13} )) rss=$(( ${22} * PAGE ))
        curTicks[$pid]=$ticks
        p=${prevTicks[$pid]:-$ticks}
        dtk=$(( ticks - p )); (( dtk < 0 )) && dtk=0
        (( cpuBy[$name] += dtk, memBy[$name] += rss ))
        if (( pid == SELF )); then selfCpu=$dtk selfRss=$rss; fi
    done
    prevTicks=()
    for k in "${!curTicks[@]}"; do prevTicks[$k]=${curTicks[$k]}; done
    # ticks -> % of the whole CPU, x10 for one decimal
    scale=$(( dt > 0 ? dt * HZ * ncpu / 1000000 : 0 ))
    if (( scale > 0 )); then
        for k in "${!cpuBy[@]}"; do cpuBy[$k]=$(( cpuBy[$k] * 1000 / scale )); done
        selfCpu=$(( selfCpu * 1000 / scale ))
    else
        for k in "${!cpuBy[@]}"; do cpuBy[$k]=0; done
        selfCpu=0
    fi
    top3 cpuBy; printf 'cpu%s\n' "$out"
    top3 memBy; printf 'mem%s\n' "$out"

    # --- GPU time per DRM client ---
    (( n++ % 10 == 0 )) && scan_gpu
    declare -A gpuBy=() seen=() curGpu=()
    selfGpu=0
    for f in "${gpuFiles[@]}"; do
        id="" ns=0
        { while read -r k v _; do
              case $k in
                  drm-client-id:) id=$v ;;
                  drm-engine-gfx:|drm-engine-compute:) (( ns += v )) ;;
              esac
          done <"$f"; } 2>/dev/null || continue
        [[ -n $id && -z ${seen[$id]} ]] || continue
        seen[$id]=1
        pdir=${f%/fdinfo/*}; pid=${pdir#/proc/}
        curGpu[$id]=$ns
        p=${prevGpu[$id]:-$ns}
        dns=$(( ns - p )); (( dns < 0 )) && dns=0
        { read -r st <"$pdir/stat"; } 2>/dev/null || continue
        name=${st#*(}; name=${name%)*}; name=${name//[^A-Za-z0-9 ._:+@\/-]/_}
        # ns busy / µs elapsed -> % x10
        v=$(( dt > 0 ? dns / dt : 0 ))
        (( gpuBy[$name] += v ))
        (( pid == SELF )) && (( selfGpu += v ))
    done
    prevGpu=()
    for k in "${!curGpu[@]}"; do prevGpu[$k]=${curGpu[$k]}; done
    top3 gpuBy; printf 'gpu%s\n' "$out"

    printf 'self\t%d\t%d\t%d\nend\n' "$selfCpu" "$selfRss" "$selfGpu"
    unset cpuBy memBy curTicks gpuBy seen curGpu
    # wait; if the pipe ever returns early (EOF on some systems), fall back to sleep instead of spinning
    read -r -t "$INTERVAL" -u "$fd" _
    (( 10#${EPOCHREALTIME/[.,]/} - now < INTERVAL * 500000 )) && sleep "$INTERVAL"
done
