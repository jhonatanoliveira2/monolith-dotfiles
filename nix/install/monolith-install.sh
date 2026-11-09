#!/usr/bin/env bash
# monolith-install - installs NixOS with the MONOLITH desktop from the NixOS installer ISO.
#
#   sudo nix --extra-experimental-features "nix-command flakes" \
#       run github:jhonatanoliveira2/monolith-dotfiles/feature/nothing-theme#install [-- options]
#
# Options:  --dry-run        show every step and command, change nothing
#           --lang pt|en     language of the questions (asked otherwise)
#           -h | --help
#
# Steps: checks (root, live ISO, network) -> target -> questions -> summary -> confirmation (type the disk or
# partition name) -> partitions, ext4 -> nixos-generate-config -> MONOLITH template filled with the answers ->
# nixos-install -> user password -> reboot. Two targets:
#   * a whole disk, erased: GPT + ESP on UEFI (msdos on BIOS), optional LUKS;
#   * existing partitions (next to another system): only the partition chosen for NixOS is formatted (ext4);
#     on UEFI an existing ESP (Windows', another Linux's) is kept and mounted at /boot/efi (the kernels stay on
#     the ext4 root, so a small ESP is enough), or a chosen partition becomes a new one; GRUB lists the other
#     systems (os-prober). No LUKS in this mode (GRUB cannot read a /boot inside LUKS2).
#
# Safety: the live medium is never offered; disks / partitions that are mounted, in use (swap, LUKS, LVM, RAID)
# or under 20 GiB are refused; nothing is written before the disk or partition name is typed back. If the install stops after the
# disk was prepared (network, an evaluation error fixed upstream), running it again offers to resume.
set -euo pipefail

FLAKE_REF=${MONOLITH_FLAKE:-github:jhonatanoliveira2/monolith-dotfiles/feature/nothing-theme}
TEMPLATE_DIR=${MONOLITH_TEMPLATE:-}      # set by the Nix package (templates/nixos from the same revision)
MNT=/mnt
MIN_GIB=20
DRY=0 LANGX="" CUSTOMIZE_ONLY="" LUKS=0 SWAP_GIB=0 BOOTMODE=uefi GPUMODS=""
TARGET=disk ESPMNT=/boot OSPROBER=0 ROOTPART="" ESPPART="" ESPNEW=0   # TARGET=parts: existing partitions

# ── output / input ────────────────────────────────────────────────────────────────────────────────────────
# Look: "monolith" (greys, the block wordmark, numbered steps) or "nothing" (LED dots: a dot-matrix wordmark,
# a row of LEDs for the progress). Monochrome either way; red only for errors. No colour without a terminal
# (or with NO_COLOR).
THEME=${MONOLITH_INSTALL_THEME:-monolith}
if [[ -t 1 && -z ${NO_COLOR-} ]]; then
    B=$'\e[1m' D=$'\e[38;5;244m' R=$'\e[38;5;160m' N=$'\e[0m'
    W=$'\e[38;5;255m' L=$'\e[38;5;250m' M=$'\e[38;5;245m' K=$'\e[38;5;238m'
else B="" D="" R="" N="" W="" L="" M="" K=""; fi
Y=$B G=$W                                 # (warnings in bold, done in white: no colours but red)
t() { if [[ $LANGX == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
STEP=0 STEPS=10                          # steps of a typical run, for the progress
step() {
    STEP=$((STEP + 1))
    local n=$((STEP > STEPS ? STEPS : STEP)) i bar=""
    if [[ $THEME == nothing ]]; then
        for ((i = 1; i <= STEPS; i++)); do
            if ((i <= n)); then bar+="$W●"; else bar+="$K●"; fi
            ((i < STEPS)) && bar+=" "
        done
        printf '\n  %s%s  %s%s%s\n' "$bar" "$N" "$B$W" "$(printf '%s' "$*" | tr '[:lower:]' '[:upper:]')" "$N"
    else
        printf '\n  %s━━%s %s%02d%s  %s%s%s\n' "$K" "$N" "$M" "$STEP" "$N" "$B$W" "$*" "$N"
    fi
}
if [[ $THEME == nothing ]]; then MK_OK="●" MK_WARN="○" MK_ERR="●" MK_ASK="◦"; else MK_OK="✓" MK_WARN="!" MK_ERR="✗" MK_ASK="›"; fi
ok() { printf '  %s%s%s %s%s\n' "$W" "$MK_OK" "$L" "$*" "$N"; }
warn() { printf '  %s%s %s%s\n' "$B$W" "$MK_WARN" "$*" "$N" >&2; }
die() { printf '  %s%s %s%s\n' "$R$B" "$MK_ERR" "$*" "$N" >&2; exit 1; }
# frame: the summary, set off from the rest (a rule on the left; dots in the Nothing look)
frame() {
    local mark=$([[ $THEME == nothing ]] && printf '·' || printf '│') line
    while IFS= read -r line; do printf '  %s%s%s %s\n' "$K" "$mark" "$N" "${line#  }"; done
}
banner() {
    local LC_ALL=C.UTF-8          # (string lengths in characters: the dots are multibyte)
    printf '\n'
    if [[ $THEME == nothing ]]; then
        # MONOLITH as a 5-row dot matrix; two cells per LED when the terminal is wide enough
        local -A F=(
            [M]="●···● ●●·●● ●·●·● ●···● ●···●" [O]="·●●●· ●···● ●···● ●···● ·●●●·"
            [N]="●···● ●●··● ●·●·● ●··●● ●···●" [L]="●···· ●···· ●···· ●···· ●●●●●"
            [I]="●●● ·●· ·●· ·●· ●●●" [T]="●●●●● ··●·· ··●·· ··●·· ··●··" [H]="●···● ●···● ●●●●● ●···● ●···●")
        local wide=0 r c ch row out word=MONOLITH
        (($(tput cols 2>/dev/null || echo 80) >= 96)) && wide=1
        for r in 0 1 2 3 4; do
            out="  "
            for ((c = 0; c < ${#word}; c++)); do
                read -r -a row <<<"${F[${word:c:1}]}"
                local cell=${row[r]} k
                for ((k = 0; k < ${#cell}; k++)); do
                    ch=${cell:k:1}
                    if [[ $ch == "●" ]]; then out+="$W●"; else out+="$K·"; fi
                    ((wide)) && out+=" "
                done
                out+=" "
            done
            printf '%s%s\n' "$out" "$N"
        done
        printf '\n  %sN I X O S   ·   %s%s\n' "$M" "$(t "I N S T A L A D O R" "I N S T A L L E R")" "$N"
    else
        printf '  %s█▄ ▄█ ▄▀▀▀▄ █▄  █ ▄▀▀▀▄ █     ▀█▀ ▀▀█▀▀ █   █%s\n' "$W" "$N"
        printf '  %s█ ▀ █ █   █ █ ▀▄█ █   █ █      █    █   █▀▀▀█%s\n' "$L" "$N"
        printf '  %s▀   ▀  ▀▀▀  ▀   ▀  ▀▀▀  ▀▀▀▀▀ ▀▀▀   ▀   ▀   ▀%s\n' "$M" "$N"
        printf '\n  %sNixOS  ·  %s%s\n' "$M" "$(t "instalador" "installer")" "$N"
        printf '  %s──────────────────────────────────────────────%s\n' "$K" "$N"
    fi
}
run() {
    if ((DRY)); then printf '%s  [dry-run]%s' "$D" "$N"; printf ' %q' "$@"; printf '\n'; else "$@"; fi
}
ask() { # ask <var> <prompt> <default> [regex]
    local v
    while :; do
        read -r -p "  $MK_ASK $2 [$3]: " v </dev/tty || v=""
        v=${v:-$3}
        if [[ -z ${4-} || $v =~ $4 ]]; then printf -v "$1" '%s' "$v"; return; fi
        warn "$(t "Valor inválido" "Invalid value"): $v"
    done
}
yes_no() { # yes_no <prompt> <y|n>
    local a hint="y/N"
    [[ $2 == y ]] && hint="Y/n"
    read -r -p "  $MK_ASK $1 [$hint]: " a </dev/tty || a=""
    a=${a:-$2}
    [[ ${a,,} == y* || ${a,,} == s* ]]
}

usage() { sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

while (($#)); do
    case $1 in
        --dry-run) DRY=1 ;;
        --lang) LANGX=${2-}; shift ;;
        --customize-only) CUSTOMIZE_ONLY=${2-}; shift ;;   # tests: fill a template copy from MI_* variables
        -h | --help) usage ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

# ── template ──────────────────────────────────────────────────────────────────────────────────────────────
# customize <dir>: fills flake.nix / configuration.nix of templates/nixos with the answers
customize() {
    local dir=$1 c=$1/configuration.nix f=$1/flake.nix
    [[ -f $c && -f $f ]] || die "template not found in $dir"
    sed -i \
        -e "s|user = \"alice\";|user = \"$USERNAME\";|" \
        -e "s|description = \"Alice\";|description = \"$FULLNAME\";|" \
        -e "s|passwd alice|passwd $USERNAME|" \
        -e "s|networking.hostName = \"monolith-pc\";|networking.hostName = \"$HOST\";|" \
        -e "s|time.timeZone = \"America/Sao_Paulo\";|time.timeZone = \"$TZONE\";|" \
        -e "s|i18n.defaultLocale = \"pt_BR.UTF-8\";|i18n.defaultLocale = \"$LOCALE\";|" \
        -e "s|services.xserver.xkb.layout = \"br\";|services.xserver.xkb.layout = \"$XKB\";|" \
        -e "s|console.keyMap = \"br-abnt2\";|console.keyMap = \"$KEYMAP\";|" \
        -e "s|language = \"pt\";|language = \"$LANGX\";|" \
        -e "s|stateVersion = \"25.11\";|stateVersion = \"$STATEVER\";|g" \
        "$c"
    if [[ $BOOTMODE == bios ]]; then
        sed -i -e "s|device = \"nodev\";|device = \"$DISK\";|" -e 's|efiSupport = true;|efiSupport = false;|' \
            -e '/boot.loader.efi.canTouchEfiVariables = true;/d' "$c"
    fi
    if [[ $ESPMNT != /boot ]]; then   # existing partitions: shared ESP at /boot/efi, kernels on the root's /boot
        sed -i "/boot.loader.efi.canTouchEfiVariables = true;/a\\
  boot.loader.efi.efiSysMountPoint = \"$ESPMNT\"; # the ESP is shared with another system: kernels stay on /" "$c"
        grep -qF "efiSysMountPoint = \"$ESPMNT\";" "$c" || die "template: ESP mount point not set"
    fi
    if ((OSPROBER)); then   # other systems on the disk(s) in the GRUB menu
        sed -i "/    efiSupport = /a\\
    useOSProber = true; # the other systems on the disk(s) in the boot menu" "$c"
        grep -qF "useOSProber = true;" "$c" || die "template: os-prober not set"
    fi
    if [[ -n $GPUMODS ]]; then   # early KMS: the splash starts on the real display (monolith.boot.gpuModules)
        local list="" m
        for m in $GPUMODS; do list+="\"$m\" "; done
        sed -i "/boot.enable = true;/a\\
    boot.gpuModules = [ ${list}]; # GPU driver in the initrd: splash from the first second" "$c"
        grep -qF "boot.gpuModules = [ $list]" "$c" || die "template: gpuModules not set"
    fi
    local extra=""
    ((SWAP_GIB > 0)) && extra+="  swapDevices = [ { device = \"/var/lib/swapfile\"; size = $((SWAP_GIB * 1024)); } ];\\n"
    [[ -n $extra ]] && sed -i "/system.stateVersion = /a\\
${extra%\\n}" "$c"
    sed -i "s|monolith-pc|$HOST|g" "$f"
    # every answer must be in place (the template may have changed upstream)
    local want
    for want in "user = \"$USERNAME\";" "networking.hostName = \"$HOST\";" "time.timeZone = \"$TZONE\";" \
        "i18n.defaultLocale = \"$LOCALE\";" "xkb.layout = \"$XKB\";" "console.keyMap = \"$KEYMAP\";" \
        "language = \"$LANGX\";" "system.stateVersion = \"$STATEVER\";"; do
        grep -qF "$want" "$c" || die "template: could not set $want"
    done
    grep -qF "nixosConfigurations.$HOST " "$f" || die "template: could not rename the configuration to $HOST"
    if [[ $BOOTMODE == bios ]]; then grep -qF "device = \"$DISK\";" "$c" || die "template: GRUB device not set"; fi
    ((SWAP_GIB == 0)) || grep -qF 'swapDevices' "$c" || die "template: swap not set"
}

if [[ -n $CUSTOMIZE_ONLY ]]; then
    : "${MI_LANG:=pt}" "${MI_BOOT:=uefi}" "${MI_DISK:=/dev/vda}" "${MI_SWAP:=0}" "${MI_LUKS:=0}"
    LANGX=$MI_LANG BOOTMODE=$MI_BOOT DISK=$MI_DISK SWAP_GIB=$MI_SWAP LUKS=$MI_LUKS
    ESPMNT=${MI_ESPMNT:-/boot} OSPROBER=${MI_OSPROBER:-0}
    USERNAME=${MI_USER:-maria} FULLNAME=${MI_NAME:-Maria Silva} HOST=${MI_HOST:-estacao} TZONE=${MI_TZ:-Europe/Lisbon}
    LOCALE=${MI_LOCALE:-pt_PT.UTF-8} XKB=${MI_XKB:-pt} KEYMAP=${MI_KEYMAP:-pt-latin1} STATEVER=${MI_STATE:-26.05} GPUMODS=${MI_GPU-}
    customize "$CUSTOMIZE_ONLY"
    exit 0
fi

# ── language ──────────────────────────────────────────────────────────────────────────────────────────────
banner
if [[ -z $LANGX ]]; then
    printf '\n'
    read -r -p "  $MK_ASK Idioma / Language [pt/en] (pt): " LANGX </dev/tty || LANGX=""
fi
[[ $LANGX == en ]] || LANGX=pt
((DRY)) && warn "$(t "Modo de teste: nenhum disco ou arquivo será alterado." "Dry run: no disk or file will be changed.")"

# ── checks ────────────────────────────────────────────────────────────────────────────────────────────────
step "$(t "Verificações" "Checks")"
((DRY || EUID == 0)) || die "$(t "Execute como root (sudo)." "Run as root (sudo).")"
[[ -e /etc/NIXOS ]] || die "$(t "Isto não é um sistema NixOS: use a ISO de instalação." "This is not NixOS: use the installer ISO.")"
for c in nixos-install nixos-generate-config nixos-enter parted partprobe wipefs blkid blockdev lsblk findmnt udevadm mkfs.ext4 mkfs.fat; do
    command -v "$c" >/dev/null || die "$(t "Comando ausente" "Missing command"): $c"
done
LIVE_SRC=$(findmnt -no SOURCE /iso 2>/dev/null || findmnt -no SOURCE /nix/.ro-store 2>/dev/null || true)
if [[ -z $LIVE_SRC ]] && ! ((DRY)); then
    die "$(t "Não parece a ISO de instalação (sem /iso): por segurança o instalador só roda nela." \
        "This does not look like the installer ISO (no /iso): for safety the installer only runs there.")"
fi
LIVE_DISKS=" "
if [[ -b $LIVE_SRC ]]; then
    LIVE_DISKS+="$(basename "$LIVE_SRC") $(lsblk -no PKNAME "$LIVE_SRC" 2>/dev/null | tr '\n' ' ')"
fi
ok "$(t "ISO do NixOS" "NixOS ISO") ${LIVE_SRC:+($LIVE_SRC)}"
if [[ -d /sys/firmware/efi ]]; then BOOTMODE=uefi; else BOOTMODE=bios; fi
ok "$(t "Firmware" "Firmware"): ${BOOTMODE^^}"
if ping -c 1 -W 4 cache.nixos.org >/dev/null 2>&1; then
    ok "$(t "Internet" "Internet")"
else
    warn "$(t "Sem acesso a cache.nixos.org. Conecte o cabo ou use nmtui / wpa_cli antes de continuar." \
        "No access to cache.nixos.org. Plug the cable or use nmtui / wpa_cli first.")"
    yes_no "$(t "Continuar mesmo assim?" "Continue anyway?")" n || exit 1
fi
# GPU drivers bound on the ISO, kept for the initrd (early KMS) when they are open drivers the kernel ships
for drv in /sys/class/drm/card[0-9]*/device/driver; do
    [[ -e $drv ]] || continue
    d=$(basename "$(readlink -f "$drv")")
    case $d in i915 | xe | amdgpu | radeon | nouveau | virtio_gpu | virtio-pci | qxl | bochs-drm | vmwgfx)
        [[ $d == virtio-pci ]] && d=virtio_gpu
        [[ $d == bochs-drm ]] && d=bochs
        [[ " $GPUMODS " == *" $d "* ]] || GPUMODS+="${GPUMODS:+ }$d" ;;
    esac
done
[[ -n $GPUMODS ]] && ok "$(t "Vídeo" "Graphics"): $GPUMODS ($(t "carregado no initrd" "loaded in the initrd"))"
STATEVER=$(nixos-version 2>/dev/null | cut -c1-5)
[[ $STATEVER =~ ^[0-9]{2}\.[0-9]{2}$ ]] || STATEVER=25.11
export NIX_CONFIG="experimental-features = nix-command flakes"

# ── resume ────────────────────────────────────────────────────────────────────────────────────────────────
RESUME=0
if findmnt -n "$MNT" >/dev/null 2>&1 && [[ -f $MNT/etc/nixos/flake.nix && -f $MNT/etc/nixos/hardware-configuration.nix ]]; then
    warn "$(t "Já existe uma instalação preparada em $MNT." "An install is already prepared in $MNT.")"
    if yes_no "$(t "Retomar (pular o disco, só instalar)?" "Resume (skip the disk, just install)?")" y; then
        RESUME=1
        HOST=$(sed -n 's/.*networking.hostName = "\([^"]*\)".*/\1/p' "$MNT/etc/nixos/configuration.nix" | head -n1)
        USERNAME=$(sed -n 's/^ *user = "\([^"]*\)".*/\1/p' "$MNT/etc/nixos/configuration.nix" | head -n1)
        [[ -n $HOST && -n $USERNAME ]] || die "$(t "Não consegui ler usuário / hostname de" "Could not read user / hostname from") $MNT/etc/nixos/configuration.nix"
    else
        die "$(t "Desmonte antes de recomeçar:" "Unmount before starting over:") umount -R $MNT; cryptsetup close cryptroot"
    fi
fi

if ((!RESUME)); then
    # ── target ────────────────────────────────────────────────────────────────────────────────────────────
    step "$(t "Onde instalar" "Where to install")"
    printf '  %s1)%s %s\n' "$B" "$N" "$(t "Um disco inteiro (APAGA tudo nele)" "A whole disk (ERASES everything on it)")"
    printf '  %s2)%s %s\n' "$B" "$N" "$(t "Partições existentes (ao lado de outro sistema: só a partição escolhida é formatada)" "Existing partitions (next to another system: only the chosen partition is formatted)")"
    ask TPICK "$(t "Opção" "Choice")" "1" '^[12]$'
    [[ $TPICK == 2 ]] && TARGET=parts

    # ── disks (not the live medium) ───────────────────────────────────────────────────────────────────────
    if [[ $TARGET == disk ]]; then step "$(t "Disco de destino (será APAGADO por inteiro)" "Target disk (will be ERASED entirely)")"; fi
    mapfile -t ALL < <(lsblk -dnpo NAME,TYPE,RO | awk '$2 == "disk" && $3 == "0" { print $1 }')
    DISKS=()
    for d in "${ALL[@]}"; do
        b=$(basename "$d")
        [[ $b =~ ^(loop|zram|ram|sr|fd) ]] && continue
        [[ $LIVE_DISKS == *" $b "* ]] && continue
        DISKS+=("$d")
    done
    ((${#DISKS[@]})) || die "$(t "Nenhum disco disponível (o pendrive da ISO não é oferecido)." "No disk available (the ISO stick is never offered).")"
  if [[ $TARGET == disk ]]; then
    i=0
    for d in "${DISKS[@]}"; do
        i=$((i + 1))
        size=$(lsblk -dno SIZE "$d" | tr -d ' ')
        model=$(lsblk -dno MODEL "$d" | sed 's/ *$//')
        tran=$(lsblk -dno TRAN "$d" | tr -d ' ')
        content=$(lsblk -nlo FSTYPE,LABEL "$d" | awk 'NF { printf "%s%s ", $1, ($2 ? ":" $2 : "") }')
        printf '  %s%d)%s %-14s %8s  %s %s\n' "$B" "$i" "$N" "$d" "$size" "${model:-?}" "${tran:+($tran)}"
        printf '      %s%s%s\n' "$D" "${content:-$(t "vazio" "empty")}" "$N"
    done
    ask PICK "$(t "Número do disco" "Disk number")" "" '^[0-9]+$'
    ((PICK >= 1 && PICK <= ${#DISKS[@]})) || die "$(t "Opção inválida" "Invalid choice")"
    DISK=${DISKS[PICK - 1]}

    # in use? (mounted partitions, active swap, open LUKS / LVM on top of it)
    # (outputs captured first: with pipefail, `lsblk | grep -q` can report "no match" when grep exits early)
    mounts=$(lsblk -nro MOUNTPOINTS "$DISK" 2>/dev/null || lsblk -nro MOUNTPOINT "$DISK" 2>/dev/null || true)
    types=$(lsblk -nro TYPE "$DISK" 2>/dev/null || true)
    swaps=$(swapon --noheadings --show=NAME 2>/dev/null || true)
    if [[ -n ${mounts//[[:space:]]/} ]]; then
        die "$(t "Há partições montadas em $DISK. Desmonte-as (umount) e rode de novo." "$DISK has mounted partitions. Unmount them and run again.")"
    fi
    if [[ $types =~ (^|$'\n')(crypt|lvm|raid) ]]; then
        die "$(t "$DISK está em uso (LUKS / LVM / RAID abertos). Feche-os e rode de novo." "$DISK is in use (open LUKS / LVM / RAID). Close them and run again.")"
    fi
    if [[ $'\n'$swaps == *$'\n'"$DISK"* ]]; then
        die "$(t "Há swap ativa em $DISK (swapoff)." "Active swap on $DISK (swapoff).")"
    fi
    bytes=$(lsblk -bdno SIZE "$DISK")
    ((bytes >= MIN_GIB * 1024 * 1024 * 1024)) || die "$(t "Disco pequeno demais (mínimo ${MIN_GIB} GiB)." "Disk too small (at least ${MIN_GIB} GiB).")"
  else
    # ── existing partitions ───────────────────────────────────────────────────────────────────────────────
    ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
    swaps=$(swapon --noheadings --show=NAME 2>/dev/null || true)
    # free_part <dev>: not mounted, nothing open on it (LUKS / LVM / RAID), not an active swap
    free_part() {
        local m kids
        m=$(lsblk -nro MOUNTPOINTS "$1" 2>/dev/null || lsblk -nro MOUNTPOINT "$1" 2>/dev/null || true)
        kids=$(lsblk -nlo NAME "$1" 2>/dev/null | wc -l)
        [[ -z ${m//[[:space:]]/} && $kids -le 1 && $'\n'$swaps != *$'\n'"$1"$'\n'* && $'\n'$swaps$'\n' != *$'\n'"$1"$'\n'* ]]
    }
    show_part() { # show_part <n> <dev>
        local size fs label ptn
        size=$(lsblk -dno SIZE "$2" | tr -d ' ') fs=$(lsblk -dno FSTYPE "$2" | tr -d ' ')
        label=$(lsblk -dno LABEL "$2" | sed 's/ *$//') ptn=$(lsblk -dno PARTTYPENAME "$2" 2>/dev/null | sed 's/ *$//')
        printf '  %s%d)%s %-16s %8s  %s%s %s\n' "$B" "$1" "$N" "$2" "$size" "${fs:-$(t "sem sistema de arquivos" "no file system")}" \
            "${label:+ \"$label\"}" "${ptn:+($ptn)}"
    }
    mapfile -t PALL < <(lsblk -lnpo NAME,TYPE "${DISKS[@]}" | awk '$2 == "part" { print $1 }')
    ESPS=() ROOTS=()
    for p in "${PALL[@]}"; do
        free_part "$p" || continue
        ptype=$(lsblk -dno PARTTYPE "$p" 2>/dev/null | tr -d ' ' | tr 'A-F' 'a-f')
        if [[ $ptype == "$ESP_GUID" ]]; then ESPS+=("$p"); continue; fi
        (($(lsblk -bdno SIZE "$p") >= MIN_GIB * 1024 * 1024 * 1024)) && ROOTS+=("$p")
    done
    step "$(t "Partição do sistema (será FORMATADA em ext4)" "System partition (will be FORMATTED as ext4)")"
    ((${#ROOTS[@]})) || die "$(t "Nenhuma partição livre com pelo menos ${MIN_GIB} GiB. Crie uma (gparted, cfdisk) e rode de novo." \
        "No free partition of at least ${MIN_GIB} GiB. Create one (gparted, cfdisk) and run again.")"
    i=0; for p in "${ROOTS[@]}"; do i=$((i + 1)); show_part "$i" "$p"; done
    ask PICK "$(t "Número da partição" "Partition number")" "" '^[0-9]+$'
    ((PICK >= 1 && PICK <= ${#ROOTS[@]})) || die "$(t "Opção inválida" "Invalid choice")"
    ROOTPART=${ROOTS[PICK - 1]}
    rootfs_now=$(lsblk -dno FSTYPE "$ROOTPART" | tr -d ' ') rootlabel=$(lsblk -dno LABEL "$ROOTPART" | sed 's/ *$//')
    if [[ -n $rootfs_now ]]; then
        warn "$(t "$ROOTPART contém dados ($rootfs_now${rootlabel:+, \"$rootlabel\"}): TUDO nela será apagado." \
            "$ROOTPART holds data ($rootfs_now${rootlabel:+, \"$rootlabel\"}): EVERYTHING on it will be erased.")"
    fi
    DISK=/dev/$(lsblk -no PKNAME "$ROOTPART" | head -n1)
    OSPROBER=1
    if [[ $BOOTMODE == uefi ]]; then
        step "$(t "Partição EFI (ESP)" "EFI partition (ESP)")"
        if ((${#ESPS[@]})); then
            printf '  %s\n' "$(t "Partições EFI encontradas (mantidas, NÃO formatadas; o NixOS é acrescentado a ela):" "EFI partitions found (kept, NOT formatted; NixOS is added to it):")"
            i=0; for p in "${ESPS[@]}"; do i=$((i + 1)); show_part "$i" "$p"; done
            ask PICK "$(t "Número da ESP" "ESP number")" "1" '^[0-9]+$'
            ((PICK >= 1 && PICK <= ${#ESPS[@]})) || die "$(t "Opção inválida" "Invalid choice")"
            ESPPART=${ESPS[PICK - 1]}
            [[ $(lsblk -dno FSTYPE "$ESPPART" | tr -d ' ') == vfat ]] || die "$(t "$ESPPART não é FAT: não dá para reaproveitar como ESP." "$ESPPART is not FAT: it cannot be reused as the ESP.")"
        else
            warn "$(t "Nenhuma partição EFI encontrada: escolha uma partição (256 MiB ou mais) para virar a ESP; ela será FORMATADA (FAT32)." \
                "No EFI partition found: choose a partition (256 MiB or more) to become the ESP; it will be FORMATTED (FAT32).")"
            CANDS=()
            for p in "${PALL[@]}"; do
                [[ $p == "$ROOTPART" ]] && continue
                free_part "$p" && (($(lsblk -bdno SIZE "$p") >= 256 * 1024 * 1024)) && CANDS+=("$p")
            done
            ((${#CANDS[@]})) || die "$(t "Nenhuma partição livre para a ESP. Crie uma de 512 MiB (gparted, cfdisk) e rode de novo." \
                "No free partition for the ESP. Create one of 512 MiB (gparted, cfdisk) and run again.")"
            i=0; for p in "${CANDS[@]}"; do i=$((i + 1)); show_part "$i" "$p"; done
            ask PICK "$(t "Número da partição para a ESP" "Partition number for the ESP")" "" '^[0-9]+$'
            ((PICK >= 1 && PICK <= ${#CANDS[@]})) || die "$(t "Opção inválida" "Invalid choice")"
            ESPPART=${CANDS[PICK - 1]} ESPNEW=1
        fi
        ESPMNT=/boot/efi
    elif [[ $(lsblk -dno PTTYPE "$DISK" | tr -d ' ') == gpt ]] && ! lsblk -lnpo PARTTYPE "$DISK" | grep -qi 21686148-6449-6e6f-744e-656564454649; then
        die "$(t "BIOS com disco GPT sem partição \"BIOS boot\": o GRUB não tem onde ficar. Crie uma de 1 MiB (tipo BIOS boot) ou use o modo de disco inteiro." \
            "BIOS with a GPT disk without a \"BIOS boot\" partition: GRUB has nowhere to go. Create one of 1 MiB (BIOS boot type) or use the whole-disk mode.")"
    fi
  fi
    # ── questions ─────────────────────────────────────────────────────────────────────────────────────────
    step "$(t "Sistema" "System")"
    if [[ $LANGX == en ]]; then dTZ=UTC dLOC=en_US.UTF-8 dXKB=us dKM=us; else dTZ=America/Sao_Paulo dLOC=pt_BR.UTF-8 dXKB=br dKM=br-abnt2; fi
    ask USERNAME "$(t "Usuário (login)" "User (login)")" "" '^[a-z_][a-z0-9_-]{0,31}$'
    ask FULLNAME "$(t "Nome completo" "Full name")" "$USERNAME" '^[^"\\$`|&]*$'
    ask HOST "$(t "Nome da máquina (hostname)" "Machine name (hostname)")" "monolith" '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'
    while :; do
        ask TZONE "$(t "Fuso horário" "Time zone")" "$dTZ" '^[A-Za-z0-9_+/-]+$'
        [[ ! -d /etc/zoneinfo || -e /etc/zoneinfo/$TZONE ]] && break
        warn "$(t "Fuso desconhecido (ex.: America/Sao_Paulo, Europe/Lisbon, UTC)" "Unknown time zone (e.g. Europe/Berlin, UTC)")"
    done
    ask LOCALE "$(t "Idioma do sistema (locale)" "System locale")" "$dLOC" '^[A-Za-z_]+\.UTF-8$'
    ask XKB "$(t "Layout do teclado (gráfico)" "Keyboard layout (graphical)")" "$dXKB" '^[a-z0-9_,]+$'
    ask KEYMAP "$(t "Layout do teclado (console)" "Keyboard layout (console)")" "$dKM" '^[a-zA-Z0-9_-]+$'
    LUKS=0
    if [[ $TARGET == disk ]]; then
        yes_no "$(t "Criptografar o disco (LUKS, senha pedida no boot)?" "Encrypt the disk (LUKS, password asked at boot)?")" n && LUKS=1
    fi
    ram_gib=$(awk '/^MemTotal/ { printf "%d", ($2 + 1048575) / 1048576 }' /proc/meminfo)
    ask SWAP_GIB "$(t "Swap em GiB (arquivo; 0 = nenhuma)" "Swap in GiB (file; 0 = none)")" "$((ram_gib < 8 ? ram_gib : 8))" '^[0-9]{1,3}$'

    # ── summary + confirmation ────────────────────────────────────────────────────────────────────────────
    step "$(t "Resumo" "Summary")"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL "$DISK" | sed 's/^/  /'
    if [[ $TARGET == parts ]]; then
        layout="$ROOTPART -> ext4 (/)"
        [[ -n $ESPPART ]] && layout+=", ESP $ESPPART -> /boot/efi ($( ((ESPNEW)) && t "FORMATADA" "FORMATTED" || t "mantida" "kept"))"
        [[ $BOOTMODE == bios ]] && layout+=", GRUB -> $DISK"
        layout+=", $(t "outros sistemas no menu de boot" "other systems in the boot menu")"
    elif [[ $BOOTMODE == uefi ]]; then layout="GPT: 1 GiB EFI (FAT32) + ext4"
    elif ((LUKS)); then layout="MBR: 1 GiB /boot (ext4) + ext4, GRUB"
    else layout="MBR: ext4 + GRUB"; fi
    frame <<EOF

  $(t "Disco" "Disk"):          $DISK  ->  $layout$( ((LUKS)) && printf ' (LUKS2)')
  $(t "Usuário" "User"):        $USERNAME ($FULLNAME)
  Hostname:       $HOST
  $(t "Fuso / locale" "Time zone / locale"): $TZONE / $LOCALE
  $(t "Teclado" "Keyboard"):        $XKB / $KEYMAP
  Swap:           $SWAP_GIB GiB
  NixOS:          $STATEVER, MONOLITH ($FLAKE_REF)

EOF
    if [[ $TARGET == parts ]]; then
        printf '  %s%s%s\n' "$R$B" "$(t "OS DADOS DE $ROOTPART SERÃO APAGADOS" "ALL DATA ON $ROOTPART WILL BE ERASED")$( ((ESPNEW)) && printf ' (+ %s)' "$ESPPART"). $(t "As outras partições ficam como estão." "The other partitions stay as they are.")" "$N"
        CONFIRM=$ROOTPART
    else
        printf '  %s%s%s\n' "$R$B" "$(t "TODOS OS DADOS DE $DISK SERÃO APAGADOS." "ALL DATA ON $DISK WILL BE ERASED.")" "$N"
        CONFIRM=$DISK
    fi
    read -r -p "  $MK_ASK $(t "Para confirmar, digite o nome" "To confirm, type the name") ($(basename "$CONFIRM")): " typed </dev/tty || typed=""
    [[ $typed == "$(basename "$CONFIRM")" || $typed == "$CONFIRM" ]] || die "$(t "Cancelado: nada foi alterado." "Cancelled: nothing was changed.")"

    # fs_is <device> <type>: what is really on the device now (blkid -p reads it, no cache)
    fs_is() {
        ((DRY)) && return 0
        udevadm settle
        [[ $(blkid -p -s TYPE -o value "$1" 2>/dev/null) == "$2" ]]
    }
  if [[ $TARGET == parts ]]; then
    # ── existing partitions: format only the chosen ones, mount ───────────────────────────────────────────
    step "$(t "Preparando as partições" "Preparing the partitions")"
    run udevadm settle
    run wipefs -af "$ROOTPART"
    run mkfs.ext4 -F -q -L nixos "$ROOTPART"
    fs_is "$ROOTPART" ext4 || die "$(t "ext4 não encontrado em $ROOTPART depois do mkfs." "No ext4 on $ROOTPART after mkfs.")"
    run mount -t ext4 "$ROOTPART" "$MNT"
    ROOTFS=$ROOTPART BOOTP=$ESPPART
    if [[ -n $ESPPART ]]; then
        if ((ESPNEW)); then
            run wipefs -af "$ESPPART"
            run mkfs.fat -F 32 -n BOOT "$ESPPART"
            # mark it as an ESP so the firmware looks there
            espdisk=/dev/$(lsblk -no PKNAME "$ESPPART" | head -n1) espnum=$(lsblk -dno PARTN "$ESPPART" | tr -d ' ')
            if [[ $(lsblk -dno PTTYPE "$espdisk" | tr -d ' ') == gpt ]]; then run parted -s "$espdisk" set "$espnum" esp on
            else run parted -s "$espdisk" set "$espnum" boot on; fi
        fi
        fs_is "$ESPPART" vfat || die "$(t "FAT32 não encontrado em $ESPPART." "No FAT32 on $ESPPART.")"
        run mkdir -p "$MNT$ESPMNT"
        run mount -t vfat -o umask=077 "$ESPPART" "$MNT$ESPMNT"
    fi
    ok "$(t "Partições prontas" "Partitions ready"): $ROOTPART$( [[ -n $ESPPART ]] && printf ' + %s (%s)' "$ESPPART" "$ESPMNT")"
  else
    # ── partition, format, mount ──────────────────────────────────────────────────────────────────────────
    step "$(t "Preparando o disco" "Preparing the disk")"
    # 1. clear the old layout (partitions first, then the tables) and let udev finish with the disk
    run udevadm settle
    mapfile -t OLD < <(lsblk -lnpo NAME,TYPE "$DISK" | awk '$2 == "part" { print $1 }')
    for p in "${OLD[@]}"; do run wipefs -af "$p"; done
    run wipefs -af "$DISK"
    run udevadm settle

    # 2. new table; START = first sector (512-byte units, as in /sys) of each partition, checked below
    if [[ $BOOTMODE == uefi ]]; then
        run parted -s "$DISK" -- mklabel gpt mkpart ESP fat32 1MiB 1GiB set 1 esp on mkpart root ext4 1GiB 100%
        START=(2048 2097152)
    elif ((LUKS)); then   # /boot must stay outside the encrypted volume for GRUB
        run parted -s "$DISK" -- mklabel msdos mkpart primary ext4 1MiB 1GiB set 1 boot on mkpart primary ext4 1GiB 100%
        START=(2048 2097152)
    else
        run parted -s "$DISK" -- mklabel msdos mkpart primary ext4 1MiB 100% set 1 boot on
        START=(2048)
    fi

    # 3. the kernel must use the NEW table before anything is formatted: right after parted it may still
    #    show the old partitions while udev re-reads the disk, and mkfs would then write at the old offsets
    partdev() { if [[ $DISK =~ [0-9]$ ]]; then printf '%sp%s' "$DISK" "$1"; else printf '%s%s' "$DISK" "$1"; fi; }
    PARTS=()
    for ((n = 1; n <= ${#START[@]}; n++)); do PARTS+=("$(partdev "$n")"); done
    if ((!DRY)); then
        synced=0
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            partprobe "$DISK" 2>/dev/null || blockdev --rereadpt "$DISK" 2>/dev/null || true
            udevadm settle
            synced=1
            for ((n = 1; n <= ${#START[@]}; n++)); do
                dev=${PARTS[n - 1]} sys=/sys/class/block/$(basename "${PARTS[n - 1]}")/start
                [[ -b $dev && -r $sys && $(<"$sys") == "${START[n - 1]}" ]] || synced=0
            done
            ((synced)) && break
            sleep 1
        done
        ((synced)) || die "$(t "O kernel continua usando a tabela de partições antiga de $DISK. Reinicie a ISO e rode o instalador de novo (o disco já foi limpo)." \
            "The kernel still uses the old partition table of $DISK. Reboot the ISO and run the installer again (the disk is already wiped).")"
        ok "$(t "Partições" "Partitions"): ${PARTS[*]}"
    fi
    if [[ $BOOTMODE == bios && $LUKS == 0 ]]; then BOOTP="" ROOTP=${PARTS[0]}; else BOOTP=${PARTS[0]} ROOTP=${PARTS[1]}; fi
    for p in "${PARTS[@]}"; do run wipefs -af "$p"; done
    ROOTFS=$ROOTP
    if ((LUKS)); then
        printf '  %s\n' "$(t "Escolha a senha do disco (pedida a cada boot):" "Choose the disk password (asked at every boot):")"
        until run cryptsetup -q luksFormat --type luks2 --verify-passphrase "$ROOTP"; do warn "$(t "Tente de novo." "Try again.")"; done
        fs_is "$ROOTP" crypto_LUKS || die "LUKS: $(t "formatação não encontrada em" "no LUKS header on") $ROOTP"
        until run cryptsetup open "$ROOTP" cryptroot; do warn "$(t "Senha incorreta, tente de novo." "Wrong password, try again.")"; done
        ROOTFS=/dev/mapper/cryptroot
    fi
    run mkfs.ext4 -F -q -L nixos "$ROOTFS"
    fs_is "$ROOTFS" ext4 || die "$(t "ext4 não encontrado em $ROOTFS depois do mkfs." "No ext4 on $ROOTFS after mkfs.")"
    run mount -t ext4 "$ROOTFS" "$MNT"
    if [[ $BOOTMODE == uefi ]]; then
        run mkfs.fat -F 32 -n BOOT "$BOOTP"
        fs_is "$BOOTP" vfat || die "$(t "FAT32 não encontrado em $BOOTP depois do mkfs." "No FAT32 on $BOOTP after mkfs.")"
        run mkdir -p "$MNT/boot"
        run mount -t vfat -o umask=077 "$BOOTP" "$MNT/boot"
    elif [[ -n $BOOTP ]]; then
        run mkfs.ext4 -F -q -L boot "$BOOTP"
        fs_is "$BOOTP" ext4 || die "$(t "ext4 não encontrado em $BOOTP depois do mkfs." "No ext4 on $BOOTP after mkfs.")"
        run mkdir -p "$MNT/boot"
        run mount -t ext4 "$BOOTP" "$MNT/boot"
    fi
    ok "$(t "Disco pronto" "Disk ready"): $ROOTFS$( [[ -n $BOOTP ]] && printf ' + %s' "$BOOTP")"
  fi

    # ── configuration ─────────────────────────────────────────────────────────────────────────────────────
    step "$(t "Configuração" "Configuration")"
    run nixos-generate-config --root "$MNT"
    run rm -f "$MNT/etc/nixos/configuration.nix"
    if ((DRY)); then
        tmp=$(mktemp -d)
        if [[ -n $TEMPLATE_DIR ]]; then cp "$TEMPLATE_DIR"/flake.nix "$TEMPLATE_DIR"/configuration.nix "$tmp/"; chmod u+w "$tmp"/*
        else (cd "$tmp" && nix flake init -t "$FLAKE_REF" >/dev/null); fi
        customize "$tmp"
        ok "$(t "Modelo preenchido (prévia):" "Template filled (preview):") $tmp/configuration.nix"
    else
        if [[ -n $TEMPLATE_DIR ]]; then
            cp "$TEMPLATE_DIR"/flake.nix "$TEMPLATE_DIR"/configuration.nix "$MNT/etc/nixos/"
            chmod u+w "$MNT"/etc/nixos/flake.nix "$MNT"/etc/nixos/configuration.nix
        else
            (cd "$MNT/etc/nixos" && nix flake init -t "$FLAKE_REF")
        fi
        customize "$MNT/etc/nixos"
        ok "$MNT/etc/nixos/{flake.nix,configuration.nix,hardware-configuration.nix}"
    fi
    if yes_no "$(t "Revisar configuration.nix no editor antes de instalar?" "Review configuration.nix in an editor before installing?")" n; then
        ((DRY)) && ed_file=$tmp/configuration.nix || ed_file=$MNT/etc/nixos/configuration.nix
        "${EDITOR:-nano}" "$ed_file" </dev/tty >/dev/tty
    fi
fi

# ── install ───────────────────────────────────────────────────────────────────────────────────────────────
step "$(t "Instalando (download e compilação: pode levar bastante tempo)" "Installing (downloads and builds: this can take a while)")"
# The lock file must exist BEFORE nixos-install: a path flake without flake.lock gets one written into it during
# the install, its contents change after being hashed and Nix stops with "NAR hash mismatch in input 'path:...'".
# On a resume, the monolith input is moved to the newest commit of the branch (fixes pushed since the attempt).
cfgdir=$MNT/etc/nixos
if ((RESUME)) && [[ -f $cfgdir/flake.lock ]]; then
    step "$(t "Atualizando o MONOLITH para a versão mais recente da branch" "Updating MONOLITH to the newest commit of the branch")"
    run nix flake update monolith --flake "$cfgdir" || run nix flake lock --update-input monolith "$cfgdir" ||
        die "$(t "Não foi possível atualizar a entrada monolith (rede?)." "Could not update the monolith input (network?).")"
else
    run nix flake lock "$cfgdir" || die "$(t "Não foi possível criar o flake.lock (rede?)." "Could not create flake.lock (network?).")"
fi
if ! run nixos-install --no-root-passwd --no-channel-copy --flake "$cfgdir#$HOST"; then
    warn "$(t "A instalação falhou. O disco continua preparado: corrija o problema (ou aguarde a correção na branch) e rode o instalador de novo para retomar." \
        "The install failed. The disk stays prepared: fix the problem (or wait for the fix on the branch) and run the installer again to resume.")"
    exit 1
fi
ok "$(t "Sistema instalado" "System installed")"

step "$(t "Senha de $USERNAME (o root fica sem senha: use sudo)" "Password for $USERNAME (root has no password: use sudo)")"
until run nixos-enter --root "$MNT" -c "passwd $USERNAME"; do warn "$(t "Tente de novo." "Try again.")"; done

step "$(t "Pronto" "Done")"
printf '  %s\n' "$(t "Remova o pendrive ao reiniciar. Atualizações depois: sudo nixos-rebuild switch --flake /etc/nixos" \
    "Remove the USB stick when rebooting. Later updates: sudo nixos-rebuild switch --flake /etc/nixos")"
if yes_no "$(t "Reiniciar agora?" "Reboot now?")" y; then
    run umount -R "$MNT" || true
    if ((LUKS)) || [[ -e /dev/mapper/cryptroot ]]; then run cryptsetup close cryptroot || true; fi
    run reboot
fi
