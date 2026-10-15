#!/bin/bash
# sysmon.sh — CPU (temp. máxima), GPU (temp. máxima) e RAM para a Waybar.
# Texto da barra: temperaturas + RAM. Tooltip: temperatura E uso de CPU/GPU.
# Lê direto do sysfs/procfs (sem sensors, sem awk, sem forks).
# Saída: JSON {"text","tooltip","class"} -> usar com "interval" no módulo.

export LC_ALL=C.UTF-8
shopt -s nullglob

# ícones (troque aqui se algum glifo não renderizar na sua fonte)
ICON_CPU=$'\uf2db'
ICON_GPU=$'\U000f08ae'
ICON_RAM=$'\U000f035b'

WARN=80    # °C -> classe "warning"
CRIT=90    # °C -> classe "critical"

HWMON=/sys/class/hwmon
CPU_STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-sysmon.cpu"

# maior temp*_input (°C inteiro) de um diretório hwmon -> TEMP (vazio se não houver)
max_temp() {
    local f v max=""
    for f in "$1"/temp*_input; do
        { read -r v <"$f"; } 2>/dev/null || continue
        [[ $v =~ ^-?[0-9]+$ ]] || continue
        v=$(( v / 1000 ))
        if [[ -z $max ]] || (( v > max )); then max=$v; fi
    done
    TEMP=$max
}

cpu_temp() {
    local hw name z type v best=""
    for hw in "$HWMON"/hwmon*; do
        { read -r name <"$hw/name"; } 2>/dev/null || continue
        case $name in
            coretemp|k10temp|zenpower|cpu_thermal|cpu-thermal) ;;
            *) continue ;;
        esac
        max_temp "$hw"
        if [[ -n $TEMP ]] && { [[ -z $best ]] || (( TEMP > best )); }; then best=$TEMP; fi
    done
    # fallback: zona térmica do pacote x86
    if [[ -z $best ]]; then
        for z in /sys/class/thermal/thermal_zone*; do
            { read -r type <"$z/type"; } 2>/dev/null || continue
            [[ $type == x86_pkg_temp ]] || continue
            if { read -r v <"$z/temp"; } 2>/dev/null && [[ $v =~ ^[0-9]+$ ]]; then best=$(( v / 1000 )); fi
        done
    fi
    CPU=$best
}

# uso de CPU (%) = variação desde a última execução (guardada em $CPU_STATE)
read_stat() {
    local cpu user nice sys idle iow irq sirq steal _
    read -r cpu user nice sys idle iow irq sirq steal _ </proc/stat
    T=$(( user + nice + sys + idle + iow + irq + sirq + steal ))
    I=$(( idle + iow ))
}

cpu_usage() {
    local pt pi dt di
    CPU_USE=""
    read_stat
    if [[ -r $CPU_STATE ]] && read -r pt pi <"$CPU_STATE" && [[ $pt =~ ^[0-9]+$ && $pi =~ ^[0-9]+$ ]]; then
        :
    else
        pt=$T pi=$I          # 1ª execução: amostra curta
        sleep 0.2
        read_stat
    fi
    printf '%s %s\n' "$T" "$I" >"$CPU_STATE" 2>/dev/null
    dt=$(( T - pt )); di=$(( I - pi ))
    (( dt > 0 )) || return
    CPU_USE=$(( 100 * (dt - di) / dt ))
    (( CPU_USE < 0 )) && CPU_USE=0
    (( CPU_USE > 100 )) && CPU_USE=100
}

# GPU -> GPU (temp. máx.) e GPU_USE (uso %, vazio se o driver não expõe)
gpu_info() {
    local hw name st v u s t best="" use="" suspended=0
    for hw in "$HWMON"/hwmon*; do
        { read -r name <"$hw/name"; } 2>/dev/null || continue
        case $name in
            amdgpu|radeon|nouveau|xe|i915) ;;
            *) continue ;;
        esac
        # dGPU em runtime-suspend (notebook híbrido): não acordar a placa
        if { read -r st <"$hw/device/power/runtime_status"; } 2>/dev/null && [[ $st == suspended ]]; then
            continue
        fi
        max_temp "$hw"
        if [[ -n $TEMP ]] && { [[ -z $best ]] || (( TEMP > best )); }; then best=$TEMP; fi
        # amdgpu expõe o uso em gpu_busy_percent
        if { read -r u <"$hw/device/gpu_busy_percent"; } 2>/dev/null && [[ $u =~ ^[0-9]+$ ]]; then
            if [[ -z $use ]] || (( u > use )); then use=$u; fi
        fi
    done
    # NVIDIA proprietário não expõe hwmon -> nvidia-smi (só se a placa estiver acordada)
    if [[ -z $best ]] && command -v nvidia-smi >/dev/null 2>&1; then
        for s in /sys/bus/pci/drivers/nvidia/*/power/runtime_status; do
            if { read -r st <"$s"; } 2>/dev/null && [[ $st == suspended ]]; then suspended=1; fi
        done
        if (( ! suspended )); then
            while IFS=', ' read -r t u; do
                [[ $t =~ ^[0-9]+$ ]] || continue
                if [[ -z $best ]] || (( t > best )); then best=$t; fi
                if [[ $u =~ ^[0-9]+$ ]] && { [[ -z $use ]] || (( u > use )); }; then use=$u; fi
            done < <(timeout 2 nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>/dev/null)
        fi
    fi
    GPU=$best GPU_USE=$use
}

ram_usage() {
    local k v _ total=0 avail=0 used t
    while read -r k v _; do
        case $k in
            MemTotal:)     total=$v ;;
            MemAvailable:) avail=$v; break ;;
        esac
    done </proc/meminfo
    (( total > 0 )) || { RAM_PCT=""; return; }
    used=$(( total - avail ))
    RAM_PCT=$(( used * 100 / total ))
    t=$(( used * 10 / 1048576 ));  printf -v RAM_USED  '%d.%d' $(( t / 10 )) $(( t % 10 ))
    t=$(( total * 10 / 1048576 )); printf -v RAM_TOTAL '%d.%d' $(( t / 10 )) $(( t % 10 ))
}

cpu_temp
cpu_usage
gpu_info
ram_usage

text="" tip="" hottest=0
if [[ -n $CPU ]]; then
    text+="$ICON_CPU ${CPU}°"
    tip+="CPU  ${CPU}°C (máx.)"
    [[ -n $CPU_USE ]] && tip+="  ·  uso ${CPU_USE}%"
    (( CPU > hottest )) && hottest=$CPU
fi
if [[ -n $GPU ]]; then
    [[ -n $text ]] && { text+="  "; tip+='\n'; }
    text+="$ICON_GPU ${GPU}°"
    tip+="GPU  ${GPU}°C (máx.)"
    [[ -n $GPU_USE ]] && tip+="  ·  uso ${GPU_USE}%"
    (( GPU > hottest )) && hottest=$GPU
fi
if [[ -n $RAM_PCT ]]; then
    [[ -n $text ]] && { text+="  "; tip+='\n'; }
    text+="$ICON_RAM ${RAM_PCT}%"
    tip+="RAM  ${RAM_USED} / ${RAM_TOTAL} GiB"
fi

class=""
if   (( hottest >= CRIT )); then class="critical"
elif (( hottest >= WARN )); then class="warning"
fi

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tip" "$class"
