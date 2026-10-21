#!/usr/bin/env bash
# sysmon-stream.sh - one line every N seconds for the bar (default 3):
#   cpu=<%> cputemp=<C> gpu=<%> gputemp=<C> ram=<%> ramused=<GiB> ramtotal=<GiB>      (-1 = unavailable)
# Sensors are detected once; the loop uses bash builtins only (no forks), so it costs almost nothing.
export LC_ALL=C
shopt -s nullglob
INTERVAL=${1:-3}

cpu_inputs=() gpu_inputs=() gpu_busy="" gpu_dir=""
for hw in /sys/class/hwmon/hwmon*; do
    { read -r name <"$hw/name"; } 2>/dev/null || continue
    case $name in
        coretemp | k10temp | zenpower | cpu_thermal) cpu_inputs+=("$hw"/temp*_input) ;;
        amdgpu | radeon | nouveau | xe | i915)
            gpu_inputs+=("$hw"/temp*_input)
            gpu_dir=$hw
            [[ -r $hw/device/gpu_busy_percent ]] && gpu_busy=$hw/device/gpu_busy_percent ;;
    esac
done

exec {fd}<> <(:)    # a pipe nobody writes to: "read -t" on it is a fork-free sleep

prev_total=0 prev_idle=0
while :; do
    # --- CPU usage (delta of /proc/stat) ---
    read -r _ u n s i w irq sirq st _ </proc/stat
    total=$(( u + n + s + i + w + irq + sirq + st )) idle=$(( i + w ))
    dt=$(( total - prev_total )) di=$(( idle - prev_idle ))
    cpu=-1
    (( prev_total > 0 && dt > 0 )) && cpu=$(( 100 * (dt - di) / dt ))
    prev_total=$total prev_idle=$idle

    # --- temperatures: hottest sensor of each device ---
    cputemp=-1 gputemp=-1 gpu=-1
    for f in "${cpu_inputs[@]}"; do
        { read -r v <"$f"; } 2>/dev/null || continue
        v=$(( v / 1000 )); (( v > cputemp )) && cputemp=$v
    done
    suspended=""
    [[ -n $gpu_dir ]] && { read -r suspended <"$gpu_dir/device/power/runtime_status"; } 2>/dev/null
    if [[ $suspended != suspended ]]; then
        for f in "${gpu_inputs[@]}"; do
            { read -r v <"$f"; } 2>/dev/null || continue
            v=$(( v / 1000 )); (( v > gputemp )) && gputemp=$v
        done
        [[ -n $gpu_busy ]] && { read -r gpu <"$gpu_busy"; } 2>/dev/null
    fi

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
    read -r -t "$INTERVAL" -u "$fd" _ || true
done
