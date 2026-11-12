#!/usr/bin/env bash
# test-nixos-install.sh - the NixOS installer fills templates/nixos correctly (UEFI, BIOS, swap, LUKS,
# existing partitions).
# Only the template step runs (--customize-only): no disk, no root, no Nix needed.
# Usage: bash tests/test-nixos-install.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INST=$ROOT/nix/install/monolith-install.sh
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PASS=0 FAIL=0
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$d"; fi; }
fresh() { rm -rf "${TMP:?}/$1"; mkdir -p "$TMP/$1"; cp "$ROOT"/templates/nixos/*.nix "$TMP/$1/"; }
has() { grep -qF -- "$2" "$TMP/$1/configuration.nix"; }
hasf() { grep -qF -- "$2" "$TMP/$1/flake.nix"; }

echo "== installer: template filling"
check "installer syntax" bash -n "$INST"

fresh uefi
check "UEFI run succeeds" env MI_BOOT=uefi bash "$INST" --customize-only "$TMP/uefi"
check "user set" has uefi 'user = "maria";'
check "full name set" has uefi 'description = "Maria Silva";'
check "hostname set" has uefi 'networking.hostName = "estacao";'
check "time zone set" has uefi 'time.timeZone = "Europe/Lisbon";'
check "locale set" has uefi 'i18n.defaultLocale = "pt_PT.UTF-8";'
check "keyboard set" has uefi 'services.xserver.xkb.layout = "pt";'
check "console keymap set" has uefi 'console.keyMap = "pt-latin1";'
check "stateVersion set (system)" has uefi 'system.stateVersion = "26.05";'
check "stateVersion set (home)" has uefi 'home.stateVersion = "26.05";'
check "password hint names the user" has uefi "passwd maria"
check "UEFI keeps efiSupport" has uefi 'efiSupport = true;'
check "UEFI keeps canTouchEfiVariables" has uefi 'canTouchEfiVariables = true;'
check "no swap by default" bash -c "! grep -q swapDevices '$TMP/uefi/configuration.nix'"
check "flake output renamed" hasf uefi 'nixosConfigurations.estacao ='
check "no template hostname left" bash -c "! grep -q monolith-pc '$TMP/uefi/flake.nix' '$TMP/uefi/configuration.nix'"

fresh bios
check "BIOS + swap + LUKS + en run succeeds" env MI_BOOT=bios MI_DISK=/dev/sda MI_SWAP=8 MI_LUKS=1 MI_LANG=en bash "$INST" --customize-only "$TMP/bios"
check "BIOS: GRUB on the disk" has bios 'device = "/dev/sda";'
check "BIOS: efiSupport off" has bios 'efiSupport = false;'
check "BIOS: no canTouchEfiVariables" bash -c "! grep -qF 'boot.loader.efi.canTouchEfiVariables = true;' '$TMP/bios/configuration.nix'"
check "swap file of 8 GiB" has bios '  swapDevices = [ { device = "/var/lib/swapfile"; size = 8192; } ];'
check "LUKS: no initrd option (systemd stage 1 is the only one, the option was removed)" bash -c "! grep -q 'boot.initrd.systemd' '$TMP/bios/configuration.nix'"
check "language en" has bios 'language = "en";'
check "extra lines right after stateVersion" bash -c "grep -A2 'system.stateVersion' '$TMP/bios/configuration.nix' | grep -q swapDevices"

fresh gpu
fresh parts
check "existing-partitions run succeeds" env MI_ESPMNT=/boot/efi MI_DUALBOOT=1 bash "$INST" --customize-only "$TMP/parts"
check "shared ESP mounted at /boot/efi" has parts 'boot.loader.efi.efiSysMountPoint = "/boot/efi";'
check "UEFI kept with a shared ESP" has parts 'efiSupport = true;'
check "dual boot: firmware boot order never changed" has parts 'boot.loader.efi.canTouchEfiVariables = false;'
check "dual boot: canTouchEfiVariables true is gone" bash -c "! grep -q 'canTouchEfiVariables = true' '$TMP/parts/configuration.nix'"
check "dual boot: no os-prober" bash -c "! grep -q useOSProber '$TMP/parts/configuration.nix'"
fresh parts-chain
check "chainload entries run succeeds" env MI_ESPMNT=/boot/efi MI_DUALBOOT=1 MI_ESPUUID=ABCD-1234 \
    MI_CHAIN=$'GRUB|/EFI/GRUB/grubx64.efi\nWindows|/EFI/Microsoft/bootmgfw.efi\nbad\"name|/EFI/x/y.efi' bash "$INST" --customize-only "$TMP/parts-chain"
check "chainload: the other GRUB" has parts-chain 'chainloader /EFI/GRUB/grubx64.efi'
check "chainload: Windows" has parts-chain 'menuentry "Windows" {'
check "chainload: ESP found by UUID" has parts-chain 'search --no-floppy --fs-uuid --set=root ABCD-1234'
check "chainload: unsafe labels skipped" bash -c "! grep -q 'bad' '$TMP/parts-chain/configuration.nix'"
check "chainload: inside the grub block" bash -c "grep -A3 'efiSupport = true;' '$TMP/parts-chain/configuration.nix' | grep -q \"extraEntries = ''\""
fresh parts-bios
check "existing partitions on BIOS" env MI_BOOT=bios MI_DISK=/dev/sdb MI_DUALBOOT=1 MI_MBR=0 bash "$INST" --customize-only "$TMP/parts-bios"
check "BIOS dual boot: the MBR is left alone (nodev)" has parts-bios 'device = "nodev";'
check "BIOS dual boot: never the disk" bash -c "! grep -q 'device = \"/dev/sdb\"' '$TMP/parts-bios/configuration.nix'"
check "BIOS dual boot: no os-prober" bash -c "! grep -q useOSProber '$TMP/parts-bios/configuration.nix'"
fresh parts-bios-mbr
check "BIOS, MBR replacement asked for" env MI_BOOT=bios MI_DISK=/dev/sdb MI_DUALBOOT=1 MI_MBR=1 bash "$INST" --customize-only "$TMP/parts-bios-mbr"
check "BIOS: GRUB on the root's disk when asked" has parts-bios-mbr 'device = "/dev/sdb";'
fresh osprober
sed -i 's|    efiSupport = true;|    efiSupport = true;\n    useOSProber = true;|' "$TMP/osprober/configuration.nix"
check "a template with os-prober on is refused" bash -c "! env MI_DUALBOOT=1 bash '$INST' --customize-only '$TMP/osprober'"

echo "== installer: what a partition holds (read only)"
P=$TMP/probe
mk() { rm -rf "$P"; mkdir -p "$P"; for f in "$@"; do mkdir -p "$P/$(dirname "$f")"; touch "$P/$f"; done; }
kind() { bash "$INST" --classify-dir "$P"; }
mk etc/os-release; printf 'NAME="Arch Linux"\nPRETTY_NAME="Arch Linux"\n' >"$P/etc/os-release"
check "a Linux root is a system" bash -c "[[ \$(bash '$INST' --classify-dir '$P') == 'os|Arch Linux' ]]"
mk usr/lib/os-release
check "os-release under usr/lib too" bash -c "[[ \$(bash '$INST' --classify-dir '$P') == os\|* ]]"
mk Windows/System32/ntoskrnl.exe
check "a Windows partition is a system" bash -c "[[ \$(bash '$INST' --classify-dir '$P') == 'os|Windows' ]]"
mk EFI/GRUB/grubx64.efi vmlinuz-linux initramfs-linux.img
check "an ESP that holds kernels (Arch) is an ESP" bash -c "[[ \$(bash '$INST' --classify-dir '$P') == esp\|* ]]"
mk vmlinuz-linux initramfs-linux.img grub/grub.cfg
check "another system's /boot is protected" bash -c "[[ \$(bash '$INST' --classify-dir '$P') == boot\|* ]]"
mk loader/entries/arch.conf
check "a systemd-boot /boot is protected" bash -c "[[ \$(bash '$INST' --classify-dir '$P') == boot\|* ]]"
mk jhow/.bashrc
check "a /home is data" bash -c "[[ \$(bash '$INST' --classify-dir '$P') == data\|* ]]"
mk; mkdir -p "$P/lost+found"
check "an empty file system is blank" bash -c "[[ \$(bash '$INST' --classify-dir '$P') == blank\|* ]]"

echo "== installer: other boot loaders on a shared ESP"
mk EFI/GRUB/grubx64.efi EFI/Microsoft/Boot/bootmgfw.efi EFI/BOOT/BOOTX64.EFI EFI/NixOS-boot-efi/grubx64.efi EFI/arch-shim/shimx64.efi EFI/arch-shim/grubx64.efi
chains=$(bash "$INST" --chain-entries "$P")
check "the other GRUB is chainloaded" grep -qx 'GRUB|/EFI/GRUB/grubx64.efi' <<<"$chains"
check "shim before GRUB in the same folder" grep -qx 'arch-shim|/EFI/arch-shim/shimx64.efi' <<<"$chains"
check "the fallback EFI/BOOT is not listed" bash -c "! grep -qi '/EFI/BOOT/' <<<'$chains'"
check "NixOS's own folder is not listed" bash -c "! grep -qi nixos <<<'$chains'"
check "Windows Boot Manager is found one level down" grep -qx 'Windows|/EFI/Microsoft/Boot/bootmgfw.efi' <<<"$chains"

check "whole disk: ESP stays at /boot" bash -c "! grep -q efiSysMountPoint '$TMP/uefi/configuration.nix'"
check "whole disk: no os-prober" bash -c "! grep -q useOSProber '$TMP/uefi/configuration.nix'"

check "GPU modules run succeeds" env MI_GPU="amdgpu i915" bash "$INST" --customize-only "$TMP/gpu"
check "early KMS modules written" has gpu '    boot.gpuModules = [ "amdgpu" "i915" ];'
check "early KMS inside the monolith block" bash -c "grep -A1 'boot.enable = true;' '$TMP/gpu/configuration.nix' | grep -q gpuModules"
check "no GPU line without modules" bash -c "! grep -q gpuModules '$TMP/uefi/configuration.nix'"

fresh nothing
check "Nothing theme run succeeds" env MI_THEME=nothing bash "$INST" --customize-only "$TMP/nothing"
check "Nothing theme: nothingTheme.enable on, inside the monolith block" \
    bash -c "sed -n '/^  monolith = {/,/^  };/p' '$TMP/nothing/configuration.nix' | grep -q '^    nothingTheme.enable = true;'"
check "default theme: the Nothing theme stays off" bash -c "! grep -qE '^ *nothingTheme.enable = true;' '$TMP/uefi/configuration.nix'"
check "--theme accepts only default | nothing" bash -c "! bash '$INST' --theme glow --customize-only '$TMP/x' 2>/dev/null"
check "the question and the summary line are there" bash -c "grep -q 'Tema padrão (cinzas' '$INST' && grep -q 'Nothing (LEDs)' '$INST'"

echo "== installer: a shared ESP is copied before the install and put back after it"
E=$TMP/esp/mnt/boot/efi
mkdir -p "$E/EFI/GRUB" "$E/EFI/NixOS-boot-efi" "$E/EFI/BOOT"
echo arch-grub >"$E/EFI/GRUB/grubx64.efi"; echo kernel >"$E/vmlinuz-linux"; echo initrd >"$E/initramfs-linux.img"
echo old-nixos >"$E/EFI/NixOS-boot-efi/grubx64.efi"; echo fallback >"$E/EFI/BOOT/BOOTX64.EFI"
{   # the installer's own functions, run on that directory
    echo 'set -euo pipefail; B="" D="" R="" N="" W="" L="" MK_OK=ok MK_WARN=! MK_ERR=x LANGX=en DRY=0 ESPDEV=/dev/x ESPMNT=/boot/efi'
    printf 'MNT=%q STATE=%q\n' "$TMP/esp/mnt" "$TMP/esp/mnt/var/lib/monolith-install"
    sed -n '/^t() {/p;/^ok() {/p;/^warn() {/p;/^die() {/p' "$INST"
    sed -n '/^run() {/,/^}/p;/^esp_snapshot() {/,/^}/p;/^nixos_owned() {/p;/^esp_diff() {/,/^}/p;/^esp_verify() {/,/^}/p' "$INST"
    echo 'esp_snapshot'
    echo 'echo HIJACK >"$MNT$ESPMNT/EFI/BOOT/BOOTX64.EFI"; rm "$MNT$ESPMNT/initramfs-linux.img"'
    echo 'echo new-nixos >"$MNT$ESPMNT/EFI/NixOS-boot-efi/grubx64.efi"; echo x >"$MNT$ESPMNT/EFI/stray.efi"'
    echo 'esp_verify'
} >"$TMP/esp/run.sh"
check "snapshot and check run" env LC_ALL=pt_BR.UTF-8 bash "$TMP/esp/run.sh"
check "a changed file of the other system is put back" grep -qx fallback "$E/EFI/BOOT/BOOTX64.EFI"
check "a deleted file of the other system is put back (Arch initramfs)" grep -qx initrd "$E/initramfs-linux.img"
check "untouched files stay" grep -qx arch-grub "$E/EFI/GRUB/grubx64.efi"
check "NixOS's own folder may change" grep -qx new-nixos "$E/EFI/NixOS-boot-efi/grubx64.efi"
check "a new file outside NixOS's folder is removed" test ! -e "$E/EFI/stray.efi"

echo "== installer: the configuration follows the installer's source (branch / commit)"
check "default: the template's URL is kept" hasf uefi 'url = "github:jhonatanoliveira2/monolith-dotfiles";'
fresh src
check "MONOLITH_FLAKE run succeeds" env MI_BOOT=uefi MONOLITH_FLAKE='github:jhonatanoliveira2/monolith-dotfiles?ref=unify/main' bash "$INST" --customize-only "$TMP/src"
check "MONOLITH_FLAKE: monolith input set" hasf src 'url = "github:jhonatanoliveira2/monolith-dotfiles?ref=unify/main";'
check "MONOLITH_FLAKE: nixpkgs untouched" hasf src 'url = "github:NixOS/nixpkgs/nixos-unstable";'
REV=0123456789abcdef0123456789abcdef01234567
mkdir -p "$TMP/bin"   # git ls-remote stub: the heads in $HEADS
printf '#!/bin/sh\nprintf "%%b" "$HEADS"\n' >"$TMP/bin/git"; chmod +x "$TMP/bin/git"
resolve() {   # resolve_source on its own; prints FLAKE_REF
    {
        echo 'set -euo pipefail; B="" N="" W="" L="" MK_WARN=! LANGX=en'
        sed -n '/^REPO=/p;/^TEMPLATE_URL=/p;/^FLAKE_REF=/p;/^SRC_REV=/p;/^t() {/p;/^warn() {/p' "$INST"
        sed -n '/^resolve_source() {/,/^}/p' "$INST"
        echo 'resolve_source 2>/dev/null; printf "%s" "$FLAKE_REF"'
    } >"$TMP/resolve.sh"
    PATH="$TMP/bin:$PATH" HEADS=$1 MONOLITH_REV=$REV bash "$TMP/resolve.sh"
}
B=github:jhonatanoliveira2/monolith-dotfiles
check "installer from a branch: that branch" test "$(resolve "aaaa\trefs/heads/main\n$REV\trefs/heads/unify/main\n")" = "$B?ref=unify/main"
check "installer from main: the bare URL" test "$(resolve "$REV\trefs/heads/feature\n$REV\trefs/heads/main\n")" = "$B"
check "branch not found: that exact commit" test "$(resolve "aaaa\trefs/heads/main\n")" = "$B/$REV"
check "no network: that exact commit" test "$(resolve "")" = "$B/$REV"
check "MONOLITH_FLAKE wins" test "$(MONOLITH_FLAKE=path:/x resolve "$REV\trefs/heads/main\n")" = "path:/x"
check "no revision (dirty build): the bare URL" test "$(REV="" resolve "")" = "$B"

echo "== installer: temporary swap during the install (little RAM)"
swapgib() { bash -c "$(sed -n '/^tmp_swap_gib() {/,/^}/p' "$INST"); tmp_swap_gib $1 $2 $3"; }
K=1048576
check "5.5 GiB of RAM, big disk: 8 GiB (the maximum)" test "$(swapgib $((K * 11 / 2)) 0 $((K * 200)))" = 8
check "12 GiB of RAM: 4 GiB" test "$(swapgib $((K * 12)) 0 $((K * 200)))" = 4
check "16 GiB of RAM: none" test "$(swapgib $((K * 16)) 0 $((K * 200)))" = 0
check "swap already active counts" test "$(swapgib $((K * 6)) $((K * 10)) $((K * 200)))" = 0
check "20 GiB root: leaves 15 GiB free" test "$(swapgib $((K * 6)) 0 $((K * 20)))" = 5
check "16 GiB root: too small, none" test "$(swapgib $((K * 6)) 0 $((K * 16)))" = 0
cores() { bash -c "$(sed -n '/^build_cores() {/,/^}/p' "$INST"); build_cores $1 $2"; }
check "5.5 GiB of RAM, 16 threads: 2 compiler processes" test "$(cores $((K * 11 / 2)) 16)" = 2
check "1.5 GiB of RAM: at least 1" test "$(cores $((K * 3 / 2)) 8)" = 1
check "16 GiB of RAM, 16 threads: 8" test "$(cores $((K * 16)) 16)" = 8
check "64 GiB of RAM: every thread (no --cores)" test -z "$(cores $((K * 64)) 16)"
check "builds outside the live ISO's tmpfs" grep -q 'TMPDIR=\$TMPBUILD run nixos-install' "$INST"
check "swap file switched off before reboot" bash -c "grep -n 'tmp_swap_off\$' '$INST' | head -1 | cut -d: -f1 | xargs -I{} test {} -lt \$(grep -n 'umount -R \"\$MNT\"' '$INST' | tail -1 | cut -d: -f1)"

fresh broken
sed -i 's/user = "alice";/username = "alice";/' "$TMP/broken/configuration.nix"
check "a changed template is reported, not half-filled silently" bash -c "! bash '$INST' --customize-only '$TMP/broken'"

printf '\nchecks passed: %d   failed: %d\n' "$PASS" "$FAIL"
((FAIL == 0))
