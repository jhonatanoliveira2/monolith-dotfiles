#!/usr/bin/env bash
# monolith-install - installs NixOS with the MONOLITH desktop from the NixOS installer ISO.
#
#   sudo nix --extra-experimental-features "nix-command flakes" \
#       run github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support#install [-- options]
#
# Options:  --dry-run        show every step and command, change nothing
#           --lang pt|en     language of the questions (asked otherwise)
#           -h | --help
#
# Steps: checks (root, live ISO, network) -> disk choice -> questions -> summary -> confirmation (type the
# disk name) -> partition (GPT + ESP on UEFI, msdos on BIOS), optional LUKS, ext4 -> nixos-generate-config ->
# MONOLITH template filled with the answers -> nixos-install -> user password -> reboot.
#
# Safety: only whole disks that are not the live medium, not mounted, not in use (swap, LUKS, LVM) and at least
# 20 GiB are offered; nothing is written before the disk name is typed back. If the install stops after the
# disk was prepared (network, an evaluation error fixed upstream), running it again offers to resume.
set -euo pipefail

FLAKE_REF=${MONOLITH_FLAKE:-github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support}
TEMPLATE_DIR=${MONOLITH_TEMPLATE:-}      # set by the Nix package (templates/nixos from the same revision)
MNT=/mnt
MIN_GIB=20
DRY=0 LANGX="" CUSTOMIZE_ONLY="" LUKS=0 SWAP_GIB=0 BOOTMODE=uefi

# ── output / input ────────────────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then B=$'\e[1m' D=$'\e[2m' R=$'\e[31m' Y=$'\e[33m' G=$'\e[32m' N=$'\e[0m'; else B="" D="" R="" Y="" G="" N=""; fi
t() { if [[ $LANGX == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok() { printf '%s  ✓ %s%s\n' "$G" "$*" "$N"; }
warn() { printf '%s  ! %s%s\n' "$Y" "$*" "$N" >&2; }
die() { printf '%s  ✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
run() {
    if ((DRY)); then printf '%s  [dry-run]%s' "$D" "$N"; printf ' %q' "$@"; printf '\n'; else "$@"; fi
}
ask() { # ask <var> <prompt> <default> [regex]
    local v
    while :; do
        read -r -p "  $2 [$3]: " v </dev/tty || v=""
        v=${v:-$3}
        if [[ -z ${4-} || $v =~ $4 ]]; then printf -v "$1" '%s' "$v"; return; fi
        warn "$(t "Valor inválido" "Invalid value"): $v"
    done
}
yes_no() { # yes_no <prompt> <y|n>
    local a hint="y/N"
    [[ $2 == y ]] && hint="Y/n"
    read -r -p "  $1 [$hint]: " a </dev/tty || a=""
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
    local extra=""
    ((SWAP_GIB > 0)) && extra+="  swapDevices = [ { device = \"/var/lib/swapfile\"; size = $((SWAP_GIB * 1024)); } ];\\n"
    ((LUKS)) && extra+="  boot.initrd.systemd.enable = true; # LUKS password asked inside the boot splash\\n"
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
    ((LUKS == 0)) || grep -qF 'boot.initrd.systemd.enable' "$c" || die "template: systemd initrd not set"
}

if [[ -n $CUSTOMIZE_ONLY ]]; then
    : "${MI_LANG:=pt}" "${MI_BOOT:=uefi}" "${MI_DISK:=/dev/vda}" "${MI_SWAP:=0}" "${MI_LUKS:=0}"
    LANGX=$MI_LANG BOOTMODE=$MI_BOOT DISK=$MI_DISK SWAP_GIB=$MI_SWAP LUKS=$MI_LUKS
    USERNAME=${MI_USER:-maria} FULLNAME=${MI_NAME:-Maria Silva} HOST=${MI_HOST:-estacao} TZONE=${MI_TZ:-Europe/Lisbon}
    LOCALE=${MI_LOCALE:-pt_PT.UTF-8} XKB=${MI_XKB:-pt} KEYMAP=${MI_KEYMAP:-pt-latin1} STATEVER=${MI_STATE:-26.05}
    customize "$CUSTOMIZE_ONLY"
    exit 0
fi

# ── language ──────────────────────────────────────────────────────────────────────────────────────────────
if [[ -z $LANGX ]]; then
    printf '\n%sMONOLITH · NixOS%s\n' "$B" "$N"
    read -r -p "  Idioma / Language [pt/en] (pt): " LANGX </dev/tty || LANGX=""
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
    # ── disk ──────────────────────────────────────────────────────────────────────────────────────────────
    step "$(t "Disco de destino (será APAGADO por inteiro)" "Target disk (will be ERASED entirely)")"
    mapfile -t ALL < <(lsblk -dnpo NAME,TYPE,RO | awk '$2 == "disk" && $3 == "0" { print $1 }')
    DISKS=()
    for d in "${ALL[@]}"; do
        b=$(basename "$d")
        [[ $b =~ ^(loop|zram|ram|sr|fd) ]] && continue
        [[ $LIVE_DISKS == *" $b "* ]] && continue
        DISKS+=("$d")
    done
    ((${#DISKS[@]})) || die "$(t "Nenhum disco disponível (o pendrive da ISO não é oferecido)." "No disk available (the ISO stick is never offered).")"
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
    yes_no "$(t "Criptografar o disco (LUKS, senha pedida no boot)?" "Encrypt the disk (LUKS, password asked at boot)?")" n && LUKS=1
    ram_gib=$(awk '/^MemTotal/ { printf "%d", ($2 + 1048575) / 1048576 }' /proc/meminfo)
    ask SWAP_GIB "$(t "Swap em GiB (arquivo; 0 = nenhuma)" "Swap in GiB (file; 0 = none)")" "$((ram_gib < 8 ? ram_gib : 8))" '^[0-9]{1,3}$'

    # ── summary + confirmation ────────────────────────────────────────────────────────────────────────────
    step "$(t "Resumo" "Summary")"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL "$DISK" | sed 's/^/  /'
    if [[ $BOOTMODE == uefi ]]; then layout="GPT: 1 GiB EFI (FAT32) + ext4"
    elif ((LUKS)); then layout="MBR: 1 GiB /boot (ext4) + ext4, GRUB"
    else layout="MBR: ext4 + GRUB"; fi
    cat <<EOF

  $(t "Disco" "Disk"):          $DISK  ->  $layout$( ((LUKS)) && printf ' (LUKS2)')
  $(t "Usuário" "User"):        $USERNAME ($FULLNAME)
  Hostname:       $HOST
  $(t "Fuso / locale" "Time zone / locale"): $TZONE / $LOCALE
  $(t "Teclado" "Keyboard"):        $XKB / $KEYMAP
  Swap:           $SWAP_GIB GiB
  NixOS:          $STATEVER, MONOLITH ($FLAKE_REF)

EOF
    printf '  %s%s%s\n' "$R$B" "$(t "TODOS OS DADOS DE $DISK SERÃO APAGADOS." "ALL DATA ON $DISK WILL BE ERASED.")" "$N"
    read -r -p "  $(t "Para confirmar, digite o nome do disco" "To confirm, type the disk name") ($(basename "$DISK")): " typed </dev/tty || typed=""
    [[ $typed == "$(basename "$DISK")" || $typed == "$DISK" ]] || die "$(t "Cancelado: nada foi alterado." "Cancelled: nothing was changed.")"

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

    # fs_is <device> <type>: what is really on the device now (blkid -p reads it, no cache)
    fs_is() {
        ((DRY)) && return 0
        udevadm settle
        [[ $(blkid -p -s TYPE -o value "$1" 2>/dev/null) == "$2" ]]
    }
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
refresh=()
((RESUME)) && refresh=(--refresh)   # picks up fixes pushed to the branch since the first attempt
if ! run nixos-install --no-root-passwd "${refresh[@]}" --flake "$MNT/etc/nixos#$HOST"; then
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
