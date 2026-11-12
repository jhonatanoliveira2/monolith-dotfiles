#!/usr/bin/env bash
# monolith-install - installs NixOS with the MONOLITH desktop from the NixOS installer ISO.
#
#   sudo nix --extra-experimental-features "nix-command flakes" \
#       run github:jhonatanoliveira2/monolith-dotfiles#install [-- options]
#
# Options:  --dry-run        show every step and command, change nothing
#           --lang pt|en     language of the questions (asked otherwise)
#           --theme default|nothing   the theme (asked otherwise): the default theme or the Nothing theme
#                            (monolith.nothingTheme.enable: LEDs in the shell, greeter, Plymouth)
#           -h | --help
#
# Steps: checks (root, live ISO, network) -> target -> questions -> summary -> confirmation (type the disk or
# partition name) -> partitions, ext4 -> nixos-generate-config -> MONOLITH template filled with the answers ->
# nixos-install (a temporary swap file and builds sized to the RAM when it is short) -> user password -> reboot. Two targets:
#   * a whole disk, erased: GPT + ESP on UEFI (msdos on BIOS), optional LUKS;
#   * existing partitions (next to another system): only the partition chosen for NixOS is formatted (ext4);
#     on UEFI an existing ESP (Windows', another Linux's) is kept and mounted at /boot/efi (the kernels stay on
#     the ext4 root, so a small ESP is enough), or an EMPTY partition becomes a new one. No LUKS in this mode
#     (GRUB cannot read a /boot inside LUKS2).
#
# Another system on the machine (dual boot) - its boot is never touched:
#   * every partition is read (read only: the block device is set read-only while it is mounted) and the ones
#     that hold a system (os-release, Windows), another system's /boot, an ESP, LUKS / LVM / RAID, a swap or a
#     hibernated system are never offered for formatting; one with other data needs ERASE / APAGAR typed too;
#   * UEFI: NixOS's GRUB only goes into its own EFI/NixOS-* folder (grub-install --no-nvram: canTouchEfiVariables
#     is off), the firmware boot order is restored with NixOS added at its END, the files already on a shared
#     ESP are checksummed and copied before the install and checked after it (anything changed is restored);
#     os-prober is not used (its guessed entries for another Linux boot it with the wrong kernel / initrd: kernel
#     panic), the other boot loaders on the ESP are chainloaded instead;
#   * BIOS: the MBR is left alone (GRUB only writes /boot/grub/grub.cfg) unless replacing it is asked for;
#   * /etc/nixos/DUAL-BOOT.txt says how to add NixOS to the other system's GRUB.
#
# Safety: the live medium is never offered; disks / partitions that are mounted, in use (swap, LUKS, LVM, RAID)
# or under 20 GiB are refused; nothing is written before the disk or partition name is typed back. If the install stops after the
# disk was prepared (network, an evaluation error fixed upstream), running it again offers to resume.
set -euo pipefail

REPO=jhonatanoliveira2/monolith-dotfiles
TEMPLATE_URL=github:$REPO                 # the monolith input as written in templates/nixos/flake.nix
FLAKE_REF=${MONOLITH_FLAKE:-$TEMPLATE_URL} # where the configuration takes MONOLITH from (resolve_source)
SRC_REV=${MONOLITH_REV:-}                  # set by the Nix package: the commit this installer was built from
TEMPLATE_DIR=${MONOLITH_TEMPLATE:-}      # set by the Nix package (templates/nixos from the same revision)
MNT=/mnt
STATE=$MNT/var/lib/monolith-install      # on the new root: answers for a resume, the copy of a shared ESP
MIN_GIB=20
DRY=0 LANGX="" CUSTOMIZE_ONLY="" LUKS=0 SWAP_GIB=0 BOOTMODE=uefi GPUMODS=""
TARGET=disk ESPMNT=/boot ROOTPART="" ESPPART="" ESPNEW=0   # TARGET=parts: existing partitions
DUALBOOT=0 BIOSMBR=1 ESPDEV="" ROOTDEV="" ORIG_ORDER="" CHAIN="" ESPUUID="" ERASEWORD=0 LOADER=""
CLASSIFY_DIR="" CHAIN_DIR=""
DESKTOP=""                               # the installed system's theme: default | nothing (asked)

# ── output / input ────────────────────────────────────────────────────────────────────────────────────────
# Look: "monolith" (greys, the block wordmark, numbered steps) or "nothing" (LED dots: a dot-matrix wordmark,
# a row of LEDs for the progress). Monochrome either way; red only for errors. No colour without a terminal
# (or with NO_COLOR).
THEME=${MONOLITH_INSTALL_THEME:-monolith}
if [[ -t 1 && -z ${NO_COLOR-} ]]; then
    B=$'\e[1m' D=$'\e[38;5;244m' R=$'\e[38;5;160m' N=$'\e[0m'
    W=$'\e[38;5;255m' L=$'\e[38;5;250m' M=$'\e[38;5;245m' K=$'\e[38;5;238m'
else B="" D="" R="" N="" W="" L="" M="" K=""; fi
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
marks() { if [[ $THEME == nothing ]]; then MK_OK="●" MK_WARN="○" MK_ERR="●" MK_ASK="◦"; else MK_OK="✓" MK_WARN="!" MK_ERR="✗" MK_ASK="›"; fi; }
marks
ok() { printf '  %s%s%s %s%s\n' "$W" "$MK_OK" "$L" "$*" "$N"; }
warn() { printf '  %s%s %s%s\n' "$B$W" "$MK_WARN" "$*" "$N" >&2; }
die() { printf '  %s%s %s%s\n' "$R$B" "$MK_ERR" "$*" "$N" >&2; exit 1; }
# frame: the summary, set off from the rest (a rule on the left; dots in the Nothing look)
frame() {
    local mark='│' line
    [[ $THEME == nothing ]] && mark='·'
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

usage() { sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

while (($#)); do
    case $1 in
        --dry-run) DRY=1 ;;
        --lang) LANGX=${2-}; shift ;;
        --theme) DESKTOP=${2-}; shift; [[ $DESKTOP == default || $DESKTOP == nothing ]] || die "--theme: default | nothing" ;;
        --customize-only) CUSTOMIZE_ONLY=${2-}; shift ;;   # tests: fill a template copy from MI_* variables
        --classify-dir) CLASSIFY_DIR=${2-}; shift ;;       # tests: what classify_dir sees in a directory
        --chain-entries) CHAIN_DIR=${2-}; shift ;;         # tests: chain_entries of a directory laid out as an ESP
        -h | --help) usage ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

# ── template ──────────────────────────────────────────────────────────────────────────────────────────────
# customize <dir>: fills flake.nix / configuration.nix of templates/nixos with the answers
# The configuration takes MONOLITH from where the installer came from. `nix run github:…?ref=<branch>#install`
# with the template's bare URL locked the repository's default branch instead: another commit, possibly one
# without flake.nix ("path '«github:…/<rev>»/flake.nix' does not exist" while creating flake.lock).
# The branch whose head is the installer's commit is looked up (main → the bare URL, kept); none (a commit
# pushed since, no network) → that exact commit, so the configuration never differs from the installer.
resolve_source() {
    [[ -z ${MONOLITH_FLAKE:-} && $SRC_REV =~ ^[0-9a-f]{40}$ ]] || return 0
    local heads b branch="" found=()
    heads=$(timeout 30 git ls-remote --heads "https://github.com/$REPO" 2>/dev/null) || heads=""
    mapfile -t found < <(awk -v r="$SRC_REV" '$1 == r && $2 ~ /^refs\/heads\// { sub(/^refs\/heads\//, "", $2); print $2 }' <<<"$heads")
    for b in "${found[@]}"; do
        [[ $b =~ ^[A-Za-z0-9._/-]+$ ]] || continue
        if [[ $b == main ]]; then branch=main; break; fi
        [[ -n $branch ]] || branch=$b
    done
    if [[ $branch == main ]]; then FLAKE_REF=$TEMPLATE_URL
    elif [[ -n $branch ]]; then FLAKE_REF="$TEMPLATE_URL?ref=$branch"
    else
        FLAKE_REF="$TEMPLATE_URL/$SRC_REV"
        warn "$(t "Branch do instalador não identificada: a configuração usa o commit ${SRC_REV:0:12} (para seguir uma branch, mude a url do monolith em /etc/nixos/flake.nix)." \
            "The installer's branch was not identified: the configuration uses commit ${SRC_REV:0:12} (to follow a branch, change the monolith url in /etc/nixos/flake.nix).")"
    fi
}
# flake.nix: the monolith input → $FLAKE_REF (only the template's own line is touched)
set_source() {
    local f=$1 esc
    [[ $FLAKE_REF == "$TEMPLATE_URL" ]] && return 0
    esc=$(printf '%s' "$FLAKE_REF" | sed 's/[&|\\]/\\&/g')
    sed -i "s|url = \"$TEMPLATE_URL\";|url = \"$esc\";|" "$f"
    grep -qF "url = \"$FLAKE_REF\";" "$f" || die "template: monolith input not set ($f)"
}

customize() {
    local dir=$1 c=$1/configuration.nix f=$1/flake.nix
    [[ -f $c && -f $f ]] || die "template not found in $dir"
    set_source "$f"
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
        sed -i -e 's|efiSupport = true;|efiSupport = false;|' -e '/boot.loader.efi.canTouchEfiVariables = true;/d' "$c"
        if ((BIOSMBR)); then
            sed -i "s|device = \"nodev\";|device = \"$DISK\";|" "$c"
        else   # another system's boot loader is in the MBR: it stays; NixOS is added to its menu (DUAL-BOOT.txt)
            sed -i 's|device = "nodev";|device = "nodev"; # the MBR belongs to the other system: only /boot/grub/grub.cfg is written (see DUAL-BOOT.txt)|' "$c"
        fi
    fi
    if [[ $BOOTMODE == uefi ]] && ((DUALBOOT)); then
        # grub-install --no-nvram: the firmware boot order (the other system first) is never changed by NixOS
        sed -i 's|boot.loader.efi.canTouchEfiVariables = true;|boot.loader.efi.canTouchEfiVariables = false; # another system boots from this machine: the firmware boot order is never changed (see DUAL-BOOT.txt)|' "$c"
        grep -qF "canTouchEfiVariables = false;" "$c" || die "template: canTouchEfiVariables not turned off"
    fi
    if [[ $ESPMNT != /boot ]]; then   # existing partitions: shared ESP at /boot/efi, kernels on the root's /boot
        sed -i "/boot.loader.efi.canTouchEfiVariables = /a\\
  boot.loader.efi.efiSysMountPoint = \"$ESPMNT\"; # the ESP is shared with another system: kernels stay on /" "$c"
        grep -qF "efiSysMountPoint = \"$ESPMNT\";" "$c" || die "template: ESP mount point not set"
    fi
    if [[ -n $CHAIN && -n $ESPUUID ]]; then   # the other systems in NixOS's menu, through their own boot loader
        local entries label path
        entries=$(mktemp)
        {
            printf '    # other systems on the shared ESP, started by their own boot loader (chainload). os-prober is not used:\n'
            printf '    # its guessed entries for another Linux can start it with the wrong kernel / initrd (kernel panic)\n'
            printf "    extraEntries = ''\n"
            while IFS='|' read -r label path; do
                [[ $label =~ ^[A-Za-z0-9._\ -]+$ && $path =~ ^/[A-Za-z0-9._/\ -]+$ ]] || continue
                printf '      menuentry "%s" {\n        insmod part_gpt\n        insmod part_msdos\n        insmod fat\n        insmod chain\n' "$label"
                printf '        search --no-floppy --fs-uuid --set=root %s\n        chainloader %s\n      }\n' "$ESPUUID" "$path"
            done <<<"$CHAIN"
            printf "    '';\n"
        } >"$entries"
        sed -i "/    efiSupport = true;/r $entries" "$c"
        rm -f "$entries"
        grep -qF "chainloader " "$c" || die "template: chainload entries not set"
    fi
    grep -qF "useOSProber = true" "$c" && die "template: os-prober must stay off"
    if [[ -n $GPUMODS ]]; then   # early KMS: the splash starts on the real display (monolith.boot.gpuModules)
        local list="" m
        for m in $GPUMODS; do list+="\"$m\" "; done
        sed -i "/boot.enable = true;/a\\
    boot.gpuModules = [ ${list}]; # GPU driver in the initrd: splash from the first second" "$c"
        grep -qF "boot.gpuModules = [ $list]" "$c" || die "template: gpuModules not set"
    fi
    if [[ $DESKTOP == nothing ]]; then   # the Nothing theme: shell, greeter, Plymouth, cursor, icons (docs/nothing-theme.md)
        sed -i 's|^    # nothingTheme.enable = true;|    nothingTheme.enable = true; # chosen in the installer (false = the default theme)|' "$c"
        grep -qE '^    nothingTheme.enable = true;' "$c" || die "template: nothingTheme.enable not set"
    else
        grep -qE '^ *nothingTheme.enable = true;' "$c" && die "template: the Nothing theme must stay off"
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
    if [[ $BOOTMODE == bios ]] && ((BIOSMBR)); then grep -qF "device = \"$DISK\";" "$c" || die "template: GRUB device not set"; fi
    ((SWAP_GIB == 0)) || grep -qF 'swapDevices' "$c" || die "template: swap not set"
}

# ── reading partitions (never writes) ─────────────────────────────────────────────────────────────────────
# classify_dir <dir>: what a mounted file system holds; sets PKIND (and PDESC for a system):
#   os    an installed system (os-release, Windows)            never formatted
#   esp   an EFI system partition (EFI/ at the top)            never formatted; can be shared
#   boot  another system's /boot (kernels, grub/, loader/)     never formatted
#   data  any other file                                       formatted only after ERASE / APAGAR is typed
#   blank a file system without files (lost+found at most)     may be formatted
classify_dir() {
    local d=$1 f name
    PKIND="" PDESC=""
    for f in etc/os-release usr/lib/os-release; do
        if [[ -f $d/$f ]]; then
            name=$(sed -n 's/^PRETTY_NAME=//p' "$d/$f" 2>/dev/null | head -n1 | tr -cd '[:alnum:] ._()+/-' | cut -c1-48)
            PKIND=os PDESC=${name:-Linux}
            return 0
        fi
    done
    if [[ -n $(find "$d" -mindepth 2 -maxdepth 2 -ipath "$d/windows/system32" -print -quit 2>/dev/null) ]]; then
        PKIND=os PDESC=Windows; return 0
    fi
    if [[ -n $(find "$d" -mindepth 1 -maxdepth 1 -iname efi -type d -print -quit 2>/dev/null) ]]; then PKIND=esp; return 0; fi
    if [[ -n $(find "$d" -mindepth 1 -maxdepth 1 \( -name 'vmlinuz*' -o -name 'initramfs*' -o -name 'initrd*' -o -name grub \
        -o -name grub2 -o -name loader -o -name kernels -o -name 'intel-ucode*' -o -name 'amd-ucode*' \) -print -quit 2>/dev/null) ]]; then
        PKIND=boot; return 0
    fi
    if [[ -n $(find "$d" -mindepth 1 -maxdepth 1 ! -name lost+found -print -quit 2>/dev/null) ]]; then PKIND=data; return 0; fi
    PKIND=blank
}

# chain_entries <esp dir>: "label|/EFI/<dir>/<loader>" for each other system's boot loader on an ESP
chain_entries() {
    local esp=$1 efi d name f l label
    efi=$(find "$esp" -mindepth 1 -maxdepth 1 -iname efi -type d -print -quit 2>/dev/null || true)
    [[ -n $efi ]] || return 0
    for d in "$efi"/*/; do
        [[ -d $d ]] || continue
        name=$(basename "$d")
        [[ $name =~ ^[A-Za-z0-9._\ -]+$ ]] || continue
        case ${name,,} in boot | nixos*) continue ;; esac
        for l in bootmgfw.efi shimx64.efi grubx64.efi systemd-bootx64.efi refind_x64.efi; do
            # (Windows keeps its loader one level down: EFI/Microsoft/Boot/bootmgfw.efi)
            f=$(find "$d" -mindepth 1 -maxdepth 2 -iname "$l" -type f -print -quit 2>/dev/null || true)
            [[ -n $f ]] || continue
            f=${f#"$esp"}
            [[ $f =~ ^/[A-Za-z0-9._/\ -]+$ ]] || continue
            if [[ ${name,,} == microsoft ]]; then label=Windows; else label=$name; fi
            printf '%s|%s\n' "$label" "$f"
            break
        done
    done
}

ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
is_esp_type() { local t; t=$(lsblk -dno PARTTYPE "$1" 2>/dev/null | tr -d ' ' | tr 'A-F' 'a-f' || true); [[ $t == "$ESP_GUID" || $t == 0xef ]]; }
declare -A PK=() PD=() PFREE=()
# probe_part <dev>: fills PK[dev] (a kind of classify_dir, or empty / swap / hibernated / locked / reserved / inuse /
# unknown), PD[dev] and PFREE[dev] (free KiB). The partition is mounted read-only with the block device itself set
# read-only meanwhile, and journals are not replayed: nothing on it can change.
probe_part() {
    local dev=$1 fs ptype mp extra ro_before mounts
    [[ -n ${PK[$dev]-} ]] && return 0
    PD[$dev]=""
    ptype=$(lsblk -dno PARTTYPE "$dev" 2>/dev/null | tr -d ' ' | tr 'A-F' 'a-f' || true)
    case $ptype in
        e3c9e316-0b5c-4db8-817d-f92df00215ae) PK[$dev]=reserved PD[$dev]="Microsoft reserved"; return 0 ;;
        de94bba4-06d1-4d40-a16a-bfd50179d6ac) PK[$dev]=reserved PD[$dev]="Windows recovery"; return 0 ;;
        21686148-6449-6e6f-744e-656564454649) PK[$dev]=reserved PD[$dev]="BIOS boot"; return 0 ;;
    esac
    mounts=$(lsblk -nro MOUNTPOINTS "$dev" 2>/dev/null || lsblk -nro MOUNTPOINT "$dev" 2>/dev/null || true)
    if [[ -n ${mounts//[[:space:]]/} ]]; then PK[$dev]=inuse; return 0; fi
    if [[ ! -r $dev ]]; then PK[$dev]=unknown; return 0; fi
    fs=$(blkid -p -s TYPE -o value "$dev" 2>/dev/null || true)
    case $fs in
        "") PK[$dev]=empty; return 0 ;;
        swap) PK[$dev]=swap; return 0 ;;
        swsuspend) PK[$dev]=hibernated; return 0 ;;
        crypto_LUKS | LVM2_member | *_raid_member | zfs_member | BitLocker | bcache | VMFS*) PK[$dev]=locked PD[$dev]=$fs; return 0 ;;
    esac
    PD[$dev]=$fs
    if ((EUID != 0)); then PK[$dev]=data; return 0; fi
    mp=$(mktemp -d /tmp/monolith-probe.XXXXXX)
    case $fs in ext2 | ext3 | ext4) extra=noload ;; xfs) extra=norecovery ;; btrfs) extra=rescue=nologreplay ;; *) extra="" ;; esac
    ro_before=$(blockdev --getro "$dev" 2>/dev/null || echo 0)
    blockdev --setro "$dev" 2>/dev/null || true
    if mount -o "ro${extra:+,$extra}" "$dev" "$mp" 2>/dev/null || mount -o ro "$dev" "$mp" 2>/dev/null; then
        classify_dir "$mp"
        PK[$dev]=$PKIND
        [[ -n $PDESC ]] && PD[$dev]=$PDESC
        PFREE[$dev]=$(df -Pk "$mp" 2>/dev/null | awk 'NR == 2 { print $4 }')
        umount "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null || true
    else
        PK[$dev]=data PD[$dev]="$fs, $(t "ilegível" "unreadable")"
    fi
    [[ $ro_before == 1 ]] || blockdev --setrw "$dev" 2>/dev/null || true
    rmdir "$mp" 2>/dev/null || true
    # an ESP-typed FAT partition is an ESP even when it holds no EFI/ folder yet
    if [[ ${PK[$dev]} == data || ${PK[$dev]} == blank ]] && [[ $fs == vfat ]] && is_esp_type "$dev"; then PK[$dev]=esp; fi
    return 0
}
kind_label() { # kind_label <dev>: what probe_part found, for the lists
    local d=${PD[$1]-}
    case ${PK[$1]-} in
        os) printf '%s' "$(t "SISTEMA INSTALADO" "INSTALLED SYSTEM"): $d" ;;
        esp) printf '%s' "$(t "partição EFI" "EFI partition") ($d)" ;;
        boot) printf '%s' "$(t "/boot de outro sistema" "another system's /boot") ($d)" ;;
        data) printf '%s' "$(t "contém dados" "holds data") ($d)" ;;
        blank) printf '%s' "$d $(t "vazio" "empty")" ;;
        empty) printf '%s' "$(t "sem sistema de arquivos" "no file system")" ;;
        swap) printf '%s' "$(t "swap de outro sistema" "another system's swap")" ;;
        hibernated) printf '%s' "$(t "swap de um sistema HIBERNADO" "swap of a HIBERNATED system")" ;;
        locked) printf '%s' "$d ($(t "criptografado / volume" "encrypted / volume"))" ;;
        reserved) printf '%s' "$d" ;;
        inuse) printf '%s' "$(t "em uso (montada)" "in use (mounted)")" ;;
        *) printf '%s' "$(t "não foi possível ler" "could not be read")" ;;
    esac
}

if [[ -n $CUSTOMIZE_ONLY ]]; then
    : "${MI_LANG:=pt}" "${MI_BOOT:=uefi}" "${MI_DISK:=/dev/vda}" "${MI_SWAP:=0}" "${MI_LUKS:=0}"
    LANGX=$MI_LANG BOOTMODE=$MI_BOOT DISK=$MI_DISK SWAP_GIB=$MI_SWAP LUKS=$MI_LUKS
    ESPMNT=${MI_ESPMNT:-/boot} DUALBOOT=${MI_DUALBOOT:-0} BIOSMBR=${MI_MBR:-1} CHAIN=${MI_CHAIN-} ESPUUID=${MI_ESPUUID-}
    USERNAME=${MI_USER:-maria} FULLNAME=${MI_NAME:-Maria Silva} HOST=${MI_HOST:-estacao} TZONE=${MI_TZ:-Europe/Lisbon}
    LOCALE=${MI_LOCALE:-pt_PT.UTF-8} XKB=${MI_XKB:-pt} KEYMAP=${MI_KEYMAP:-pt-latin1} STATEVER=${MI_STATE:-26.05} GPUMODS=${MI_GPU-}
    DESKTOP=${MI_THEME:-default}
    customize "$CUSTOMIZE_ONLY"
    exit 0
fi
if [[ -n $CLASSIFY_DIR ]]; then classify_dir "$CLASSIFY_DIR"; printf '%s|%s\n' "$PKIND" "$PDESC"; exit 0; fi
if [[ -n $CHAIN_DIR ]]; then chain_entries "$CHAIN_DIR"; exit 0; fi

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
resolve_source
ok "MONOLITH: $FLAKE_REF"
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

# ── state kept on the new root (resume) ───────────────────────────────────────────────────────────────────
save_state() {
    ((DRY)) && return 0
    mkdir -p "$STATE" && chmod 700 "$STATE"
    printf '%s\n' "TARGET=$TARGET" "BOOTMODE=$BOOTMODE" "DUALBOOT=$DUALBOOT" "BIOSMBR=$BIOSMBR" "ESPMNT=$ESPMNT" \
        "ESPDEV=$ESPDEV" "ROOTDEV=$ROOTDEV" "ORIG_ORDER=$ORIG_ORDER" "DISK=$DISK" >"$STATE/state"
}
load_state() {   # only known keys, only plain values (the file is never sourced)
    local k v
    [[ -f $STATE/state ]] || return 0
    while IFS='=' read -r k v; do
        [[ $v =~ ^[A-Za-z0-9/,._-]*$ ]] || continue
        case $k in TARGET | BOOTMODE | DUALBOOT | BIOSMBR | ESPMNT | ESPDEV | ROOTDEV | ORIG_ORDER | DISK) printf -v "$k" '%s' "$v" ;; esac
    done <"$STATE/state"
}

# ── another system's boot (dual boot) ─────────────────────────────────────────────────────────────────────
# esp_snapshot: checksums and a copy of every file already on the ESP, taken once, before anything is installed
# (a resume keeps the first one: it is the state of before the first attempt)
esp_snapshot() {
    local esp=$MNT$ESPMNT
    ((DRY)) && { run tar -C "$esp" -cf "$STATE/esp-before.tar" .; return 0; }
    [[ -f $STATE/esp-before.sha256 ]] && return 0
    mkdir -p "$STATE" && chmod 700 "$STATE"
    (cd "$esp" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum) >"$STATE/esp-before.sha256.tmp" ||
        die "$(t "Não consegui ler a ESP ($ESPDEV); nada foi instalado." "Could not read the ESP ($ESPDEV); nothing was installed.")"
    tar -C "$esp" -cf "$STATE/esp-before.tar" . ||
        die "$(t "Não consegui copiar a ESP ($ESPDEV); nada foi instalado." "Could not copy the ESP ($ESPDEV); nothing was installed.")"
    mv "$STATE/esp-before.sha256.tmp" "$STATE/esp-before.sha256"
    ok "$(t "ESP copiada e conferida antes da instalação" "ESP copied and checksummed before the install"): $(wc -l <"$STATE/esp-before.sha256") $(t "arquivos" "files") ($STATE/esp-before.tar)"
}
# nixos_owned <path relative to the ESP>: a path NixOS may write (its own EFI/NixOS-* folder)
nixos_owned() { local l=${1,,}; [[ $l == ./efi/nixos* ]]; }
# esp_diff: compares the ESP with the snapshot by path and checksum (no tool output is parsed: it is translated)
#   ESP_BAD    files of before that changed or went missing (outside NixOS's folder)
#   ESP_EXTRA  files that were not there before (outside NixOS's folder)
esp_diff() {
    local line f
    local -A before=() now=()
    ESP_BAD=() ESP_EXTRA=()
    while IFS= read -r line; do before["${line#*  }"]=${line%%  *}; done <"$STATE/esp-before.sha256"
    while IFS= read -r line; do now["${line#*  }"]=${line%%  *}; done < <(cd "$MNT$ESPMNT" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum || true)
    for f in "${!before[@]}"; do
        nixos_owned "$f" && continue
        [[ ${now[$f]-} == "${before[$f]}" ]] || ESP_BAD+=("$f")
    done
    for f in "${!now[@]}"; do
        [[ -n ${before[$f]-} ]] || nixos_owned "$f" || ESP_EXTRA+=("$f")
    done
    return 0
}
# esp_verify: a file of the other system that changed or went missing is put back from the copy, a file NixOS put
# outside its own folder is removed, and the result is checked again
esp_verify() {
    local esp=$MNT$ESPMNT
    [[ -f $STATE/esp-before.sha256 ]] || return 0
    esp_diff
    if ((${#ESP_BAD[@]})); then
        warn "$(t "Arquivos do outro sistema foram alterados na ESP; restaurando a cópia de antes:" "Files of the other system changed on the ESP; restoring the copy from before:") ${ESP_BAD[*]}"
        tar -C "$esp" -xf "$STATE/esp-before.tar" -- "${ESP_BAD[@]}" || true
    fi
    if ((${#ESP_EXTRA[@]})); then
        warn "$(t "Arquivos fora da pasta do NixOS foram criados na ESP; removendo:" "Files outside NixOS's folder were created on the ESP; removing:") ${ESP_EXTRA[*]}"
        (cd "$esp" && rm -f -- "${ESP_EXTRA[@]}") || true
    fi
    esp_diff
    if ((${#ESP_BAD[@]} || ${#ESP_EXTRA[@]})); then
        warn "$(t "A ESP ainda difere da cópia de antes (${ESP_BAD[*]} ${ESP_EXTRA[*]}). A cópia completa está em" \
            "The ESP still differs from the copy of before (${ESP_BAD[*]} ${ESP_EXTRA[*]}). The full copy is in") ${STATE#"$MNT"}/esp-before.tar"
    else
        ok "$(t "ESP conferida: nenhum arquivo do outro sistema foi alterado" "ESP checked: no file of the other system was changed")"
    fi
}
efi_entry() { # efi_entry <label>: number of the firmware entry with that label
    efibootmgr 2>/dev/null | awk -v L="$1" '/^Boot[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/ {
        n = substr($1, 5, 4); s = $0; sub(/^Boot[0-9A-Fa-f]+\*? /, "", s); if (index(s, L) == 1) { print n; exit } }' || true
}
# nvram_add: a firmware entry for NixOS at the END of the boot order recorded before the install
nvram_add() {
    local esp=$MNT$ESPMNT f label num disk part order now
    f=$(find "$esp" -mindepth 3 -maxdepth 3 -ipath "$esp/efi/nixos*/grubx64.efi" -type f -print -quit 2>/dev/null || true)
    [[ -n $f ]] || { warn "$(t "GRUB do NixOS não encontrado na ESP." "NixOS's GRUB not found on the ESP.")"; return 0; }
    LOADER=${f#"$esp"}
    command -v efibootmgr >/dev/null || { warn "$(t "efibootmgr ausente: entrada de firmware não criada." "efibootmgr missing: no firmware entry created.")"; return 0; }
    label="NixOS MONOLITH ($HOST)"
    num=$(efi_entry "$label")
    if [[ -z $num ]]; then
        disk=/dev/$(lsblk -no PKNAME "$ESPDEV" | head -n1) part=$(lsblk -dno PARTN "$ESPDEV" | tr -d ' ')
        efibootmgr -q --create --disk "$disk" --part "$part" --label "$label" --loader "${LOADER//\//\\}" ||
            { warn "$(t "Não consegui criar a entrada de firmware do NixOS." "Could not create NixOS's firmware entry.")"; return 0; }
        num=$(efi_entry "$label")
    fi
    if [[ -n $num ]]; then
        order=$(printf '%s' "$ORIG_ORDER" | tr ',' '\n' | grep -vix "$num" | paste -sd, - || true)
        efibootmgr -q --bootorder "${order:+$order,}$num" || warn "$(t "Não consegui ajustar a ordem de boot." "Could not set the boot order.")"
    fi
    now=$(efibootmgr 2>/dev/null | sed -n 's/^BootOrder: //p' || true)
    if [[ -n $ORIG_ORDER && ${now%%,*} != "${ORIG_ORDER%%,*}" ]]; then
        warn "$(t "A primeira entrada de boot mudou. Para voltar: efibootmgr -o $ORIG_ORDER" "The first boot entry changed. To go back: efibootmgr -o $ORIG_ORDER")"
    else
        ok "$(t "Ordem de boot mantida; NixOS no fim" "Boot order kept; NixOS at the end"): ${now:-?}"
    fi
}
# dualboot_notes: /etc/nixos/DUAL-BOOT.txt, how to start NixOS from the other system's GRUB
dualboot_notes() {
    local out=$MNT/etc/nixos/DUAL-BOOT.txt uuid entry
    if [[ $BOOTMODE == uefi ]]; then
        [[ -n $LOADER ]] || return 0
        uuid=$(blkid -s UUID -o value "$ESPDEV" 2>/dev/null || true)
        entry=$(printf 'menuentry "NixOS (MONOLITH)" {\n    insmod part_gpt\n    insmod part_msdos\n    insmod fat\n    insmod chain\n    search --no-floppy --fs-uuid --set=root %s\n    chainloader %s\n}' "$uuid" "$LOADER")
    elif ((!BIOSMBR)); then
        uuid=$(blkid -s UUID -o value "$ROOTDEV" 2>/dev/null || true)
        entry=$(printf 'menuentry "NixOS (MONOLITH)" {\n    insmod part_gpt\n    insmod part_msdos\n    insmod ext2\n    search --no-floppy --fs-uuid --set=root %s\n    configfile /boot/grub/grub.cfg\n}' "$uuid")
    else return 0; fi
    {
        if [[ $LANGX == en ]]; then
            printf 'NixOS next to another system (dual boot)\n\n'
            printf 'The installer left the other system'"'"'s boot as it was: its boot loader, its files and the firmware\n'
            printf 'boot order (UEFI: NixOS is at its end; BIOS: the MBR was not touched).\n\n'
            [[ $BOOTMODE == uefi ]] && printf 'Start NixOS now: the firmware boot menu (F12 / F11 / F8 / Esc at power on) -> "NixOS MONOLITH".\n\n'
            printf 'To have NixOS in the other system'"'"'s GRUB menu, start that system and add this entry to\n'
            printf '/etc/grub.d/40_custom (as root), then run: grub-mkconfig -o /boot/grub/grub.cfg\n'
            printf '(do not rely on os-prober for NixOS: its guessed entries miss the NixOS generations)\n\n'
        else
            printf 'NixOS ao lado de outro sistema (dual boot)\n\n'
            printf 'O instalador deixou o boot do outro sistema como estava: o carregador dele, os arquivos dele e a\n'
            printf 'ordem de boot do firmware (UEFI: o NixOS está no fim dela; BIOS: o MBR não foi tocado).\n\n'
            [[ $BOOTMODE == uefi ]] && printf 'Para iniciar o NixOS agora: menu de boot do firmware (F12 / F11 / F8 / Esc ao ligar) -> "NixOS MONOLITH".\n\n'
            printf 'Para ter o NixOS no menu do GRUB do outro sistema, inicie esse sistema, acrescente esta entrada a\n'
            printf '/etc/grub.d/40_custom (como root) e rode: grub-mkconfig -o /boot/grub/grub.cfg\n'
            printf '(não dependa do os-prober para o NixOS: as entradas que ele adivinha não seguem as gerações do NixOS)\n\n'
        fi
        printf '%s\n' "$entry"
    } >"$out"
    ok "$(t "Instruções de dual boot" "Dual boot steps"): /etc/nixos/DUAL-BOOT.txt"
}

# ── memory during the install ─────────────────────────────────────────────────────────────────────────────
# The swap asked for above only exists in the installed system. During nixos-install the live ISO has no swap
# and keeps its own files in RAM, so evaluating the flake and building can run out of memory on a small
# machine (8 GB with part of it taken by an integrated GPU). A temporary swap file on the new root, which is
# already mounted, covers that without any new partition. It is switched off and deleted after the install
# (and on any exit).
TMPSWAP=$MNT/.monolith-install-swap TMPSWAP_ON=0
# tmp_swap_gib <ram KiB> <swap KiB> <free KiB on the root>: GiB of temporary swap (0 = none). Aims for
# RAM + swap >= 16 GiB, at most 8 GiB, and leaves 15 GiB of the root for the system.
tmp_swap_gib() {
    local G=1048576 need room
    need=$(((16 * G - $1 - $2 + G - 1) / G))
    ((need > 8)) && need=8
    room=$(($3 / G - 15))
    ((need > room)) && need=$room
    ((need >= 2)) && printf '%d' "$need" || printf 0
}
# build_cores <ram KiB> <threads>: compiler processes per build (nix --cores). The default (0 = every thread)
# runs make -j16 on an 8-core laptop; one C++ compiler on Hyprland takes 1-1.5 GiB, so a package missing from
# the binary cache ran out of memory even with swap. About 2 GiB of RAM per process, at least 1, at most every
# thread; prints nothing when every thread fits.
build_cores() {
    local c=$(($1 / 2097152))
    ((c < 1)) && c=1
    ((c < $2)) && printf '%d' "$c"
    return 0
}
tmp_swap_on() {
    local ram swp free gib
    ram=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
    swp=$(awk '/^SwapTotal:/ { print $2 }' /proc/meminfo)
    free=$(df -Pk "$MNT" 2>/dev/null | awk 'NR == 2 { print $4 }')
    gib=$(tmp_swap_gib "${ram:-0}" "${swp:-0}" "${free:-0}")
    if ((gib == 0)); then
        (((ram + swp) / 1048576 < 12)) && warn "$(t "Pouca memória e pouco espaço livre em $MNT para uma swap temporária: a instalação pode falhar por falta de RAM." \
            "Little memory and too little free space on $MNT for a temporary swap: the install may run out of RAM.")"
        return 0
    fi
    [[ -e $TMPSWAP ]] && { swapoff "$TMPSWAP" 2>/dev/null || true; rm -f "$TMPSWAP"; }
    if run fallocate -l "${gib}G" "$TMPSWAP" || run dd if=/dev/zero of="$TMPSWAP" bs=1M count=$((gib * 1024)) status=none; then
        if run chmod 600 "$TMPSWAP" && run mkswap -q "$TMPSWAP" && run swapon "$TMPSWAP"; then
            TMPSWAP_ON=1
            ok "$(t "Swap temporária para a instalação" "Temporary swap for the install"): ${gib} GiB ($TMPSWAP)"
            return 0
        fi
    fi
    rm -f "$TMPSWAP" 2>/dev/null || true
    warn "$(t "Não foi possível criar a swap temporária; seguindo sem ela." "Could not create the temporary swap; going on without it.")"
}
tmp_swap_off() {
    ((TMPSWAP_ON)) || return 0
    TMPSWAP_ON=0
    run swapoff "$TMPSWAP" || true
    run rm -f "$TMPSWAP" || true
}

# ── resume ────────────────────────────────────────────────────────────────────────────────────────────────
RESUME=0
if findmnt -n "$MNT" >/dev/null 2>&1 && [[ -f $MNT/etc/nixos/flake.nix && -f $MNT/etc/nixos/hardware-configuration.nix ]]; then
    warn "$(t "Já existe uma instalação preparada em $MNT." "An install is already prepared in $MNT.")"
    if yes_no "$(t "Retomar (pular o disco, só instalar)?" "Resume (skip the disk, just install)?")" y; then
        RESUME=1
        HOST=$(sed -n 's/.*networking.hostName = "\([^"]*\)".*/\1/p' "$MNT/etc/nixos/configuration.nix" | head -n1)
        USERNAME=$(sed -n 's/^ *user = "\([^"]*\)".*/\1/p' "$MNT/etc/nixos/configuration.nix" | head -n1)
        [[ -n $HOST && -n $USERNAME ]] || die "$(t "Não consegui ler usuário / hostname de" "Could not read user / hostname from") $MNT/etc/nixos/configuration.nix"
        load_state
        # prepared by an installer that wrote the bare URL (the default branch): the same source as this run
        if grep -qF "url = \"$TEMPLATE_URL\";" "$MNT/etc/nixos/flake.nix" && [[ $FLAKE_REF != "$TEMPLATE_URL" ]]; then
            set_source "$MNT/etc/nixos/flake.nix"
            rm -f "$MNT/etc/nixos/flake.lock"
            ok "flake.nix: monolith = $FLAKE_REF"
        fi
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
    # every partition is read once (read only) to show and protect what is on it
    printf '  %s%s%s\n' "$D" "$(t "Lendo as partições (somente leitura)..." "Reading the partitions (read only)...")" "$N"
    mapfile -t PALL < <(lsblk -lnpo NAME,TYPE "${DISKS[@]}" | awk '$2 == "part" { print $1 }')
    for p in "${PALL[@]}"; do probe_part "$p"; done
    # systems_on <disk>: the systems / ESPs found on a disk ("" when none)
    systems_on() {
        local p out=""
        for p in $(lsblk -lnpo NAME,TYPE "$1" | awk '$2 == "part" { print $1 }'); do
            case ${PK[$p]-} in
                os) out+="${out:+, }${PD[$p]} ($(basename "$p"))" ;;
                esp) out+="${out:+, }ESP ($(basename "$p"))" ;;
                boot) out+="${out:+, }/boot ($(basename "$p"))" ;;
            esac
        done
        printf '%s' "$out"
    }
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
        sys=$(systems_on "$d")
        [[ -n $sys ]] && printf '      %s%s: %s%s\n' "$R$B" "$(t "CONTÉM" "HOLDS")" "$sys" "$N"
    done
    ask PICK "$(t "Número do disco" "Disk number")" "" '^[0-9]+$'
    ((PICK >= 1 && PICK <= ${#DISKS[@]})) || die "$(t "Opção inválida" "Invalid choice")"
    DISK=${DISKS[PICK - 1]}
    DISKSYS=$(systems_on "$DISK")
    for p in $(lsblk -lnpo NAME,TYPE "$DISK" | awk '$2 == "part" { print $1 }'); do
        case ${PK[$p]-} in os | esp | boot | data | locked | swap | hibernated | unknown) ERASEWORD=1 ;; esac
    done
    # another system on another disk (UEFI): its place in the firmware boot order is kept
    OTHERSYS=""
    if [[ $BOOTMODE == uefi ]]; then
        for d in "${DISKS[@]}"; do
            [[ $d == "$DISK" ]] && continue
            sys=$(systems_on "$d")
            [[ -n $sys ]] && OTHERSYS+="${OTHERSYS:+; }$(basename "$d"): $sys"
        done
        [[ -n $OTHERSYS ]] && DUALBOOT=1
    fi

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
    swaps=$(swapon --noheadings --show=NAME 2>/dev/null || true)
    # free_part <dev>: not mounted, nothing open on it (LUKS / LVM / RAID), not an active swap
    free_part() {
        local m kids
        m=$(lsblk -nro MOUNTPOINTS "$1" 2>/dev/null || lsblk -nro MOUNTPOINT "$1" 2>/dev/null || true)
        kids=$(lsblk -nlo NAME "$1" 2>/dev/null | wc -l)
        [[ -z ${m//[[:space:]]/} && $kids -le 1 && $'\n'$swaps != *$'\n'"$1"$'\n'* && $'\n'$swaps$'\n' != *$'\n'"$1"$'\n'* ]]
    }
    show_part() { # show_part <n|-> <dev>: size, what is on it, label, partition type
        local size label ptn
        size=$(lsblk -dno SIZE "$2" | tr -d ' ')
        label=$(lsblk -dno LABEL "$2" | sed 's/ *$//') ptn=$(lsblk -dno PARTTYPENAME "$2" 2>/dev/null | sed 's/ *$//')
        printf '  %s%s)%s %-16s %8s  %s%s %s\n' "$B" "$1" "$N" "$2" "$size" "$(kind_label "$2")" \
            "${label:+ \"$label\"}" "${ptn:+($ptn)}"
    }
    # a hibernated system (Linux) would lose its saved session, and its disks may change under it
    for p in "${PALL[@]}"; do
        [[ ${PK[$p]} == hibernated ]] && die "$(t "$p é a swap de um sistema HIBERNADO. Inicie esse sistema e desligue-o normalmente (sem hibernar); nada foi alterado." \
            "$p is the swap of a HIBERNATED system. Start that system and shut it down normally (no hibernation); nothing was changed.")"
    done
    ESPS=() ROOTS=() KEPT=()
    for p in "${PALL[@]}"; do
        if ! free_part "$p"; then KEPT+=("$p"); continue; fi
        case ${PK[$p]} in
            esp) ESPS+=("$p"); KEPT+=("$p") ;;
            empty | blank | data)
                if ! is_esp_type "$p" && (($(lsblk -bdno SIZE "$p") >= MIN_GIB * 1024 * 1024 * 1024)); then ROOTS+=("$p"); fi ;;
            *) KEPT+=("$p") ;;
        esac
    done
    step "$(t "Partição do sistema (será FORMATADA em ext4)" "System partition (will be FORMATTED as ext4)")"
    if ((${#KEPT[@]})); then
        printf '  %s\n' "$(t "Protegidas (nunca formatadas nem oferecidas):" "Protected (never formatted nor offered):")"
        for p in "${KEPT[@]}"; do show_part "-" "$p"; done
        printf '\n'
    fi
    ((${#ROOTS[@]})) || die "$(t "Nenhuma partição livre com pelo menos ${MIN_GIB} GiB. Crie uma (gparted, cfdisk) e rode de novo." \
        "No free partition of at least ${MIN_GIB} GiB. Create one (gparted, cfdisk) and run again.")"
    printf '  %s\n' "$(t "Disponíveis:" "Available:")"
    i=0; for p in "${ROOTS[@]}"; do i=$((i + 1)); show_part "$i" "$p"; done
    ask PICK "$(t "Número da partição" "Partition number")" "" '^[0-9]+$'
    ((PICK >= 1 && PICK <= ${#ROOTS[@]})) || die "$(t "Opção inválida" "Invalid choice")"
    ROOTPART=${ROOTS[PICK - 1]}
    if [[ ${PK[$ROOTPART]} == data ]]; then
        ERASEWORD=1
        warn "$(t "$ROOTPART contém arquivos (${PD[$ROOTPART]}): TUDO nela será apagado." \
            "$ROOTPART holds files (${PD[$ROOTPART]}): EVERYTHING on it will be erased.")"
    fi
    DISK=/dev/$(lsblk -no PKNAME "$ROOTPART" | head -n1)
    DUALBOOT=1
    if [[ $BOOTMODE == uefi ]]; then
        step "$(t "Partição EFI (ESP)" "EFI partition (ESP)")"
        if ((${#ESPS[@]})); then
            printf '  %s\n' "$(t "Partições EFI encontradas (mantidas, NÃO formatadas; o NixOS só ganha a própria pasta EFI/NixOS-*):" \
                "EFI partitions found (kept, NOT formatted; NixOS only adds its own EFI/NixOS-* folder):")"
            i=0; for p in "${ESPS[@]}"; do i=$((i + 1)); show_part "$i" "$p"; done
            ask PICK "$(t "Número da ESP" "ESP number")" "1" '^[0-9]+$'
            ((PICK >= 1 && PICK <= ${#ESPS[@]})) || die "$(t "Opção inválida" "Invalid choice")"
            ESPPART=${ESPS[PICK - 1]}
            [[ $(blkid -p -s TYPE -o value "$ESPPART" 2>/dev/null) == vfat ]] || ((DRY)) ||
                die "$(t "$ESPPART não é FAT: não dá para reaproveitar como ESP." "$ESPPART is not FAT: it cannot be reused as the ESP.")"
            free_kib=${PFREE[$ESPPART]:-0}
            if ((EUID == 0 && free_kib < 32768)); then
                die "$(t "$ESPPART tem só $((free_kib / 1024)) MiB livres (o NixOS precisa de 32 MiB). Libere espaço nela pelo outro sistema; nada foi alterado." \
                    "$ESPPART has only $((free_kib / 1024)) MiB free (NixOS needs 32 MiB). Free some space on it from the other system; nothing was changed.")"
            fi
        else
            # only partitions WITHOUT anything on them: an ESP that was not recognised is never offered here
            CANDS=()
            for p in "${PALL[@]}"; do
                [[ $p == "$ROOTPART" ]] && continue
                free_part "$p" || continue
                case ${PK[$p]} in empty | blank) ;; *) continue ;; esac
                (($(lsblk -bdno SIZE "$p") >= 256 * 1024 * 1024)) && CANDS+=("$p")
            done
            ((${#CANDS[@]})) || die "$(t "Nenhuma partição EFI encontrada e nenhuma partição VAZIA para criar uma. Crie uma partição vazia de 512 MiB (gparted, cfdisk) e rode de novo; nada foi alterado." \
                "No EFI partition found and no EMPTY partition to make one. Create an empty partition of 512 MiB (gparted, cfdisk) and run again; nothing was changed.")"
            warn "$(t "Nenhuma partição EFI encontrada: escolha uma partição VAZIA (256 MiB ou mais) para virar a ESP do NixOS; ela será FORMATADA (FAT32)." \
                "No EFI partition found: choose an EMPTY partition (256 MiB or more) to become NixOS's ESP; it will be FORMATTED (FAT32).")"
            i=0; for p in "${CANDS[@]}"; do i=$((i + 1)); show_part "$i" "$p"; done
            ask PICK "$(t "Número da partição para a ESP" "Partition number for the ESP")" "" '^[0-9]+$'
            ((PICK >= 1 && PICK <= ${#CANDS[@]})) || die "$(t "Opção inválida" "Invalid choice")"
            ESPPART=${CANDS[PICK - 1]} ESPNEW=1
        fi
        ESPMNT=/boot/efi
    else
        # BIOS: the boot loader of the machine lives in the MBR; replacing it is opt-in
        warn "$(t "BIOS: o carregador que inicia os sistemas fica no MBR de $DISK. Por padrão ele NÃO é alterado: o NixOS só grava o próprio /boot/grub/grub.cfg, e você o acrescenta ao GRUB do outro sistema (o passo a passo fica em /etc/nixos/DUAL-BOOT.txt)." \
            "BIOS: the loader that starts the systems is in the MBR of $DISK. By default it is NOT changed: NixOS only writes its own /boot/grub/grub.cfg, and you add it to the other system's GRUB (the steps are in /etc/nixos/DUAL-BOOT.txt).")"
        BIOSMBR=0
        if yes_no "$(t "Substituir o carregador do MBR pelo GRUB do NixOS? (o outro sistema pode deixar de iniciar; recomendado: não)" \
            "Replace the MBR loader with NixOS's GRUB? (the other system may stop booting; recommended: no)")" n; then
            BIOSMBR=1
        fi
        if ((BIOSMBR)) && [[ $(lsblk -dno PTTYPE "$DISK" | tr -d ' ') == gpt ]] && ! lsblk -lnpo PARTTYPE "$DISK" | grep -qi 21686148-6449-6e6f-744e-656564454649; then
            die "$(t "BIOS com disco GPT sem partição \"BIOS boot\": o GRUB não tem onde ficar. Crie uma de 1 MiB (tipo BIOS boot) ou use o modo de disco inteiro." \
                "BIOS with a GPT disk without a \"BIOS boot\" partition: GRUB has nowhere to go. Create one of 1 MiB (BIOS boot type) or use the whole-disk mode.")"
        fi
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
    if [[ -z $DESKTOP ]]; then
        printf '\n  %s\n' "$(t "Tema:" "Theme:")"
        printf '  %s1)%s %s\n' "$B" "$N" "$(t "Tema padrão (cinzas, barra no topo)" "Default theme (greys, bar on top)")"
        printf '  %s2)%s %s\n' "$B" "$N" "$(t "Tema Nothing (LEDs / matriz de pontos: shell, wallpapers, cursor, ícones, greeter e Plymouth)" "Nothing theme (LEDs / dot matrix: shell, wallpapers, cursor, icons, greeter and Plymouth)")"
        ask TPICK "$(t "Opção" "Choice")" "1" '^[12]$'
        if [[ $TPICK == 2 ]]; then DESKTOP=nothing; else DESKTOP=default; fi
    fi
    # the rest of the install in the chosen theme's look (unless MONOLITH_INSTALL_THEME picked one)
    if [[ -z ${MONOLITH_INSTALL_THEME-} ]]; then
        if [[ $DESKTOP == nothing ]]; then THEME=nothing; else THEME=monolith; fi
        marks
    fi

    # ── summary + confirmation ────────────────────────────────────────────────────────────────────────────
    step "$(t "Resumo" "Summary")"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MODEL "$DISK" | sed 's/^/  /'
    if [[ $TARGET == parts ]]; then
        layout="$ROOTPART -> ext4 (/)"
        [[ -n $ESPPART ]] && layout+=", ESP $ESPPART -> /boot/efi ($( ((ESPNEW)) && t "FORMATADA" "FORMATTED" || t "mantida" "kept"))"
        [[ $BOOTMODE == bios ]] && layout+=", GRUB -> $DISK"
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
  $(t "Tema" "Theme"):          $( [[ $DESKTOP == nothing ]] && t "Nothing (LEDs)" "Nothing (LEDs)" || t "padrão" "default")
  NixOS:          $STATEVER, MONOLITH ($FLAKE_REF)

EOF
    if ((DUALBOOT)); then
        if [[ $BOOTMODE == uefi ]]; then
            bootline=$(t "Boot: o GRUB do NixOS fica só na própria pasta EFI/NixOS-* da ESP; a ordem de boot do firmware não muda (o NixOS entra no FIM dela) e nada do outro sistema é alterado." \
                "Boot: NixOS's GRUB only goes into its own EFI/NixOS-* folder of the ESP; the firmware boot order does not change (NixOS is added at its END) and nothing of the other system is changed.")
        elif ((BIOSMBR)); then
            bootline=$(t "Boot: o MBR de $DISK será SUBSTITUÍDO pelo GRUB do NixOS." "Boot: the MBR of $DISK will be REPLACED by NixOS's GRUB.")
        else
            bootline=$(t "Boot: o MBR não é alterado; o NixOS é acrescentado ao GRUB do outro sistema depois (/etc/nixos/DUAL-BOOT.txt)." \
                "Boot: the MBR is not changed; NixOS is added to the other system's GRUB afterwards (/etc/nixos/DUAL-BOOT.txt).")
        fi
        printf '  %s\n' "$bootline"
        [[ -n ${OTHERSYS-} ]] && printf '  %s %s\n' "$(t "Outros sistemas (não serão tocados):" "Other systems (left untouched):")" "$OTHERSYS"
    fi
    if [[ $TARGET == disk && -n ${DISKSYS-} ]]; then
        printf '  %s%s %s%s\n' "$R$B" "$(t "ESTE DISCO TEM:" "THIS DISK HOLDS:")" "$DISKSYS" "$N"
    fi
    if [[ $TARGET == parts ]]; then
        printf '  %s%s%s\n' "$R$B" "$(t "OS DADOS DE $ROOTPART SERÃO APAGADOS" "ALL DATA ON $ROOTPART WILL BE ERASED")$( ((ESPNEW)) && printf ' (+ %s)' "$ESPPART"). $(t "As outras partições ficam como estão." "The other partitions stay as they are.")" "$N"
        CONFIRM=$ROOTPART
    else
        printf '  %s%s%s\n' "$R$B" "$(t "TODOS OS DADOS DE $DISK SERÃO APAGADOS." "ALL DATA ON $DISK WILL BE ERASED.")" "$N"
        CONFIRM=$DISK
    fi
    read -r -p "  $MK_ASK $(t "Para confirmar, digite o nome" "To confirm, type the name") ($(basename "$CONFIRM")): " typed </dev/tty || typed=""
    [[ $typed == "$(basename "$CONFIRM")" || $typed == "$CONFIRM" ]] || die "$(t "Cancelado: nada foi alterado." "Cancelled: nothing was changed.")"
    if ((ERASEWORD)); then   # files or a system are on what will be erased: a second, different word
        word=$(t APAGAR ERASE)
        read -r -p "  $MK_ASK $(t "Há arquivos ou um sistema no que será apagado. Digite $word para continuar" "There are files or a system on what will be erased. Type $word to go on"): " typed </dev/tty || typed=""
        [[ $typed == "$word" ]] || die "$(t "Cancelado: nada foi alterado." "Cancelled: nothing was changed.")"
    fi

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
    ROOTDEV=$ROOTPART ESPDEV=$ESPPART
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
    ROOTDEV=$ROOTP
    [[ $BOOTMODE == uefi ]] && ESPDEV=$BOOTP
    ok "$(t "Disco pronto" "Disk ready"): $ROOTFS$( [[ -n $BOOTP ]] && printf ' + %s' "$BOOTP")"
  fi

    # ── another system: what must stay as it is, recorded before anything is installed ─────────────────────
    if ((DUALBOOT)) && [[ $BOOTMODE == uefi ]]; then
        if command -v efibootmgr >/dev/null; then
            ORIG_ORDER=$(efibootmgr 2>/dev/null | sed -n 's/^BootOrder: //p' | tr -cd '0-9A-Fa-f,' || true)
            ok "$(t "Ordem de boot atual registrada" "Current boot order recorded"): ${ORIG_ORDER:-$(t "vazia" "empty")}"
        else
            warn "$(t "efibootmgr ausente: a ordem de boot não pôde ser registrada." "efibootmgr missing: the boot order could not be recorded.")"
        fi
        ((ESPNEW)) || esp_snapshot
    fi
    save_state

    # ── configuration ─────────────────────────────────────────────────────────────────────────────────────
    step "$(t "Configuração" "Configuration")"
    run nixos-generate-config --root "$MNT"
    run rm -f "$MNT/etc/nixos/configuration.nix"
    # the other systems' boot loaders on the shared ESP, for NixOS's menu (chainload, never os-prober)
    if ((DUALBOOT && !ESPNEW && !DRY)) && [[ $BOOTMODE == uefi && -n $ESPPART ]]; then
        ESPUUID=$(blkid -s UUID -o value "$ESPPART" 2>/dev/null || true)
        CHAIN=$(chain_entries "$MNT$ESPMNT")
        [[ -n $CHAIN ]] && ok "$(t "No menu do NixOS (pelo carregador de cada um)" "In NixOS's menu (through each one's loader)"): $(cut -d'|' -f1 <<<"$CHAIN" | paste -sd, -)"
    fi
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
# another system on the machine: a configuration edited by hand must not take its boot back
if ((DUALBOOT && !DRY)); then
    cfg=$MNT/etc/nixos/configuration.nix
    if grep -Eq '^[^#]*useOSProber *= *true' "$cfg" ||
        { [[ $BOOTMODE == uefi ]] && grep -Eq '^[^#]*canTouchEfiVariables *= *true' "$cfg"; } ||
        { [[ $BOOTMODE == bios ]] && ((!BIOSMBR)) && grep -Eq '^[^#]*device *= *"/dev/' "$cfg"; }; then
        warn "$(t "configuration.nix foi alterado para mexer no boot do outro sistema (useOSProber / canTouchEfiVariables / device)." \
            "configuration.nix was changed to touch the other system's boot (useOSProber / canTouchEfiVariables / device).")"
        yes_no "$(t "Instalar assim mesmo? (recomendado: não)" "Install anyway? (recommended: no)")" n ||
            die "$(t "Corrija $cfg e rode o instalador de novo para retomar." "Fix $cfg and run the installer again to resume.")"
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
        die "$(t "Não foi possível atualizar a entrada monolith (rede? origem: $FLAKE_REF)." "Could not update the monolith input (network? source: $FLAKE_REF).")"
else
    run nix flake lock "$cfgdir" || die "$(t "Não foi possível criar o flake.lock (rede? origem: $FLAKE_REF)." "Could not create flake.lock (network? source: $FLAKE_REF).")"
fi
tmp_swap_on
trap 'tmp_swap_off >/dev/null 2>&1; rm -rf "${TMPBUILD:-/nonexistent}" 2>/dev/null' EXIT
# under 8 GiB of RAM, one build at a time (downloads still run in parallel)
# under 8 GiB of RAM, one build at a time (downloads still run in parallel); compiler processes per build
# limited by the RAM (build_cores)
ram_kib=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
jobs=()
((ram_kib < 8 * 1048576)) && jobs=(--max-jobs 1)
cores=$(build_cores "$ram_kib" "$(nproc 2>/dev/null || echo 1)")
[[ -n $cores ]] && { jobs+=(--cores "$cores"); ok "$(t "Compilação limitada a $cores processos por pacote (RAM)" "Builds limited to $cores processes per package (RAM)")"; }
# build trees on the new root, not in the live ISO's /tmp (a tmpfs: RAM)
TMPBUILD=$MNT/.monolith-install-build
run mkdir -p -m 700 "$TMPBUILD"
install_ok=1
TMPDIR=$TMPBUILD run nixos-install --no-root-passwd --no-channel-copy "${jobs[@]}" --flake "$cfgdir#$HOST" || install_ok=0
tmp_swap_off
run rm -rf "$TMPBUILD"
if ((!install_ok)); then
    warn "$(t "A instalação falhou. O disco continua preparado: corrija o problema (ou aguarde a correção na branch) e rode o instalador de novo para retomar." \
        "The install failed. The disk stays prepared: fix the problem (or wait for the fix on the branch) and run the installer again to resume.")"
    exit 1
fi
ok "$(t "Sistema instalado" "System installed")"
if ((DUALBOOT)); then
    if ((DRY)); then
        printf '%s  [dry-run]%s %s\n' "$D" "$N" "$(t "conferir a ESP, NixOS no fim da ordem de boot, /etc/nixos/DUAL-BOOT.txt" "check the ESP, NixOS at the end of the boot order, /etc/nixos/DUAL-BOOT.txt")"
    else
        step "$(t "Boot do outro sistema: conferência" "The other system's boot: checks")"
        if [[ $BOOTMODE == uefi ]]; then esp_verify; nvram_add; fi
        dualboot_notes
    fi
fi

step "$(t "Senha de $USERNAME (o root fica sem senha: use sudo)" "Password for $USERNAME (root has no password: use sudo)")"
until run nixos-enter --root "$MNT" -c "passwd $USERNAME"; do warn "$(t "Tente de novo." "Try again.")"; done

step "$(t "Pronto" "Done")"
if ((DUALBOOT)); then
    if [[ $BOOTMODE == uefi ]]; then
        printf '  %s\n' "$(t "O outro sistema continua sendo o boot padrão. Para iniciar o NixOS: menu de boot do firmware (F12 / F11 / F8 / Esc) -> \"NixOS MONOLITH\", ou acrescente-o ao GRUB do outro sistema: /etc/nixos/DUAL-BOOT.txt" \
            "The other system stays the default boot. To start NixOS: the firmware boot menu (F12 / F11 / F8 / Esc) -> \"NixOS MONOLITH\", or add it to the other system's GRUB: /etc/nixos/DUAL-BOOT.txt")"
    elif ((!BIOSMBR)); then
        printf '  %s\n' "$(t "O MBR não foi alterado: acrescente o NixOS ao GRUB do outro sistema antes de reiniciar para ele (veja $MNT/etc/nixos/DUAL-BOOT.txt)." \
            "The MBR was not changed: add NixOS to the other system's GRUB to start it (see $MNT/etc/nixos/DUAL-BOOT.txt).")"
    fi
fi
printf '  %s\n' "$(t "Remova o pendrive ao reiniciar. Atualizações depois: sudo nixos-rebuild switch --flake /etc/nixos" \
    "Remove the USB stick when rebooting. Later updates: sudo nixos-rebuild switch --flake /etc/nixos")"
if yes_no "$(t "Reiniciar agora?" "Reboot now?")" y; then
    run umount -R "$MNT" || true
    if ((LUKS)) || [[ -e /dev/mapper/cryptroot ]]; then run cryptsetup close cryptroot || true; fi
    run reboot
fi
