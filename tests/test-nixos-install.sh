#!/usr/bin/env bash
# test-nixos-install.sh - the NixOS installer fills templates/nixos correctly (UEFI, BIOS, swap, LUKS).
# Only the template step runs (--customize-only): no disk, no root, no Nix needed.
# Usage: bash tests/test-nixos-install.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INST=$ROOT/nix/install/monolith-install.sh
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
PASS=0 FAIL=0
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$d"; fi; }
fresh() { rm -rf "$TMP/$1"; mkdir -p "$TMP/$1"; cp "$ROOT"/templates/nixos/*.nix "$TMP/$1/"; }
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
check "GPU modules run succeeds" env MI_GPU="amdgpu i915" bash "$INST" --customize-only "$TMP/gpu"
check "early KMS modules written" has gpu '    boot.gpuModules = [ "amdgpu" "i915" ];'
check "early KMS inside the monolith block" bash -c "grep -A1 'boot.enable = true;' '$TMP/gpu/configuration.nix' | grep -q gpuModules"
check "no GPU line without modules" bash -c "! grep -q gpuModules '$TMP/uefi/configuration.nix'"

fresh broken
sed -i 's/user = "alice";/username = "alice";/' "$TMP/broken/configuration.nix"
check "a changed template is reported, not half-filled silently" bash -c "! bash '$INST' --customize-only '$TMP/broken'"

printf '\nchecks passed: %d   failed: %d\n' "$PASS" "$FAIL"
((FAIL == 0))
