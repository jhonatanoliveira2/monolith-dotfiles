#!/usr/bin/env bash
# key=value lines for the Settings > System page.
#   $1 = local clone of monolith-dotfiles (for the version)   $2 = pt | en
export LC_ALL=C
repo=${1:-$HOME/monolith-dotfiles}
if [ "$2" = en ]; then w_used=used; w_disks="disk(s)"; w_of=of; else w_used="em uso"; w_disks="disco(s)"; w_of=de; fi
. /etc/os-release 2>/dev/null
echo "host=$(cat /proc/sys/kernel/hostname)"
echo "user=${USER:-$(id -un)}"
echo "os=${PRETTY_NAME:-Linux}"
echo "kernel=$(uname -r) ($(uname -m))"
read -r up _ </proc/uptime; up=${up%.*}
d=$((up / 86400)) h=$((up % 86400 / 3600)) m=$((up % 3600 / 60))
if [ $d -gt 0 ]; then echo "up=${d}d ${h}h ${m}min"; else echo "up=${h}h ${m}min"; fi
cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//; s/ \{2,\}/ /g')
echo "cpu=${cpu:-$(uname -p)} · $(nproc) threads"
# GPUs: lspci (pciutils) when present, otherwise the DRM driver names
if command -v lspci >/dev/null; then
    gpu=$(lspci -mm 2>/dev/null | awk -F'"' '$2 ~ /VGA|3D|Display/ { v=$4; d=$6; gsub(/,? Inc\.| Corporation|,? Ltd\.?/, "", v); sub(/^Advanced Micro Devices \[AMD\/ATI\]$/, "AMD", v); print v " " d }' | paste -sd ';' | sed 's/;/ · /g')
fi
[ -z "$gpu" ] && gpu=$(for d in /sys/class/drm/card[0-9]; do basename "$(readlink -f "$d/device/driver")"; done 2>/dev/null | paste -sd ' ')
echo "gpu=${gpu:--}"
awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} /^SwapTotal/{s=$2} END{printf "mem=%.1f GiB (%.1f GiB %s) · swap %.1f GiB\n", t/1048576, (t-a)/1048576, u, s/1048576}' u="$w_used" /proc/meminfo
# physical disks (no zram / loop): total size and count
disks=$(lsblk -dbno SIZE,TYPE,NAME 2>/dev/null | awk '$2=="disk" && $3 !~ /^(zram|loop)/ {n++; s+=$1} END{if(n) printf "%d %s · %.0f GB", n, w, s/1e9}' w="$w_disks")
root=$(df -B1 --output=size,used / 2>/dev/null | awk -v o="$w_of" 'NR==2{printf "/ %.0f %s %.0f GB", $2/1e9, o, $1/1e9}')
echo "disk=${disks:--} · ${root}"
echo "desktop=Hyprland $(hyprctl version -j 2>/dev/null | sed -n 's/.*"tag": *"\([^"]*\)".*/\1/p' | head -1) · Quickshell $(qs --version 2>/dev/null | awk '{print $2}')"
ver=""
[ -f "$repo/scripts/lib/common.sh" ] && ver=$(sed -n 's/^MONOLITH_VERSION="\(.*\)"/\1/p' "$repo/scripts/lib/common.sh")
[ -d "$repo/.git" ] && ver="$ver ($(git -C "$repo" describe --always --dirty 2>/dev/null), $(git -C "$repo" log -1 --format=%cs 2>/dev/null))"
echo "monolith=${ver:-?}"
