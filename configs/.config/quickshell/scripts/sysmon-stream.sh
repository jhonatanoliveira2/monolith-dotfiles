#!/usr/bin/env bash
# sysmon-stream.sh - one line every N seconds for the bar (default 3):
#   cpu=<%> cputemp=<C> gpu=<%> gputemp=<C> ram=<%> ramused=<GiB> ramtotal=<GiB>      (-1 = unavailable)
# Sensors are detected once; the loop uses bash builtins only (no forks), so it costs almost nothing.
#   sysmon-stream.sh --probe     prints the sensors found (CPU, each GPU and its power state) and exits
#
# GPUs: every DRM device is handled on its own (laptops often have an integrated and a dedicated one).
# A device in runtime suspend is skipped entirely: reading its sensors would wake it up. The values are the
# busiest / hottest of the awake devices.
export LC_ALL=C
shopt -s nullglob
INTERVAL=${1:-3}

cpu_inputs=()
for hw in /sys/class/hwmon/hwmon*; do
    { read -r name <"$hw/name"; } 2>/dev/null || continue
    case $name in coretemp | k10temp | zenpower | cpu_thermal) cpu_inputs+=("$hw"/temp*_input) ;; esac
done

gpu_dev=() gpu_busy=() gpu_temps=()
for card in /sys/class/drm/card[0-9] /sys/class/drm/card[0-9][0-9]; do
    dev=$card/device
    [[ -d $dev ]] || continue
    gpu_dev+=("$dev")
    busy=""; [[ -r $dev/gpu_busy_percent ]] && busy=$dev/gpu_busy_percent
    gpu_busy+=("$busy")
    temps=("$dev"/hwmon/hwmon*/temp*_input)
    gpu_temps+=("${temps[*]}")
done

if [[ $1 == --probe ]]; then
    echo "cpu temperature inputs: ${cpu_inputs[*]:-none}"
    for i in "${!gpu_dev[@]}"; do
        d=${gpu_dev[i]} st=""
        { read -r st <"$d/power/runtime_status"; } 2>/dev/null
        echo "gpu $i: $(readlink -f "$d") driver=$(basename "$(readlink -f "$d/driver")") boot_vga=$(cat "$d/boot_vga" 2>/dev/null || echo -)"
        echo "    power: ${st:-n/a}   busy: ${gpu_busy[i]:-none}   temps: ${gpu_temps[i]:-none}"
        if [[ $st != suspend* && -n ${gpu_busy[i]} ]]; then echo "    busy now: $(cat "${gpu_busy[i]}")%"; fi
    done
    exit 0
fi

exec {fd}<> <(:)    # a pipe nobody writes to: "read -t" on it is a fork-free sleep

prev_total=0 prev_idle=0
while :; do
    t0=${EPOCHREALTIME/[.,]/}
    # --- CPU usage (delta of /proc/stat) ---
    read -r _ u n s i w irq sirq st _ </proc/stat
    total=$(( u + n + s + i + w + irq + sirq + st )) idle=$(( i + w ))
    dt=$(( total - prev_total )) di=$(( idle - prev_idle ))
    cpu=-1
    (( prev_total > 0 && dt > 0 )) && cpu=$(( 100 * (dt - di) / dt ))
    prev_total=$total prev_idle=$idle

    # --- CPU temperature: hottest sensor ---
    cputemp=-1
    for f in "${cpu_inputs[@]}"; do
        { read -r v <"$f"; } 2>/dev/null || continue
        v=$(( v / 1000 )); (( v > cputemp )) && cputemp=$v
    done

    # --- GPUs: busiest / hottest awake device; suspended ones are not touched ---
    gpu=-1 gputemp=-1
    for i in "${!gpu_dev[@]}"; do
        state=""
        { read -r state <"${gpu_dev[i]}/power/runtime_status"; } 2>/dev/null
        [[ $state == suspend* ]] && continue
        if [[ -n ${gpu_busy[i]} ]] && { read -r v <"${gpu_busy[i]}"; } 2>/dev/null; then
            (( v > gpu )) && gpu=$v
        fi
        for f in ${gpu_temps[i]}; do
            { read -r v <"$f"; } 2>/dev/null || continue
            v=$(( v / 1000 )); (( v > gputemp )) && gputemp=$v
        done
    done

    # --- RAM ---
    total_kb=0 avail_kb=0
    while read -r k v _; do
        case $k in MemTotal:) total_kb=$v ;; MemAvailable:) avail_kb=$v; break ;; esac
    done </proc/meminfo
    used_kb=$(( total_kb - avail_kb ))
    pct=0; (( total_kb > 0 )) && pct=$(( used_kb * 100 / total_kb ))
    ut=$(( used_kb * 10 / 1048576 )) tt=$(( total_kb * 10 / 1048576 ))

    printf 'cpu=%d cputemp=%d gpu=%d gputemp=%d ram=%d ramused=%d.%d ramtotal=%d.%d\n' \
        "$cpu" "$cputemp" "$gpu" "$gputemp" "$pct" $(( ut / 10 )) $(( ut % 10 )) $(( tt / 10 )) $(( tt % 10 ))

    # wait; if the pipe ever returns early (EOF on some systems), fall back to sleep instead of spinning
    read -r -t "$INTERVAL" -u "$fd" _
    t1=${EPOCHREALTIME/[.,]/}
    (( 10#$t1 - 10#$t0 < INTERVAL * 500000 )) && sleep "$INTERVAL"
done
