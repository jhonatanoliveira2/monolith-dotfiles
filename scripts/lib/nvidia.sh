#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are shared with the scripts that source this file
# nvidia.sh - NVIDIA GPUs on Arch Linux / CachyOS: what is in the machine and which packages it needs.
# Requires packages.sh (pkg_installed, pkg_in_repos). Used by install.sh (step "packages").
#
#   nvidia_detect      NV_GPUS (PCI addresses), NV_NAMES, NV_MODERN (1 = every card is Turing / GTX 16xx or newer,
#                      so it runs the open kernel modules), NV_HYBRID (1 = another GPU too: a hybrid laptop),
#                      NV_LOADED (1 = nvidia-drm is loaded), NV_MODESET (Y / N / "" when not loaded)
#   nvidia_plan        NV_PKGS: the packages still missing (official repositories); NV_LEGACY=1 when a card needs a
#                      legacy driver (AUR, only suggested)
#
# Driver: the open kernel modules (NVIDIA's recommendation from Turing on; the only ones from driver 590): the
# prebuilt package of each installed kernel when the repositories have it (nvidia-open for linux, nvidia-open-lts,
# linux-cachyos-nvidia-open on CachyOS...), else nvidia-open-dkms with that kernel's headers. Older cards
# (Maxwell, Pascal, Volta) need nvidia-580xx-dkms from the AUR, which is only suggested. A machine that already
# has an NVIDIA kernel module (any of these, or one installed by CachyOS's chwd) keeps it.
# MONOLITH_SYSFS and MONOLITH_MODULES_DIR replace /sys and /usr/lib/modules (tests).

NV_GPUS=() NV_NAMES=() NV_PKGS=()
NV_MODERN=1 NV_HYBRID=0 NV_LOADED=0 NV_MODESET="" NV_LEGACY=0

nvidia_detect() {
    local sys=${MONOLITH_SYSFS:-/sys} d vendor class device other=0
    NV_GPUS=() NV_NAMES=() NV_MODERN=1 NV_HYBRID=0 NV_LOADED=0 NV_MODESET=""
    for d in "$sys"/bus/pci/devices/*; do
        { read -r class <"$d/class"; read -r vendor <"$d/vendor"; } 2>/dev/null || continue
        [[ $class == 0x03* ]] || continue          # display controllers (VGA, 3D, other)
        if [[ $vendor != 0x10de ]]; then other=1; continue; fi
        NV_GPUS+=("${d##*/}")
        { read -r device <"$d/device"; } 2>/dev/null || device=0x0
        # Turing (TU1xx: 0x1e00 on) and everything after it have the GSP the open modules need
        (( device >= 0x1e00 )) || NV_MODERN=0
        NV_NAMES+=("$(nvidia_name "${d##*/}" "$device")")
    done
    (( ${#NV_GPUS[@]} )) || return 1
    (( other )) && NV_HYBRID=1
    if [[ -r $sys/module/nvidia_drm/parameters/modeset ]]; then
        NV_LOADED=1
        read -r NV_MODESET <"$sys/module/nvidia_drm/parameters/modeset" || NV_MODESET=""
    fi
    return 0
}

# nvidia_name <pci address> <device id>: the marketing name from lspci when it is there, else the PCI id
nvidia_name() {
    local name=""
    command -v lspci >/dev/null 2>&1 && name=$(lspci -s "$1" 2>/dev/null | sed -nE 's/.*NVIDIA Corporation [^[]*\[([^]]+)\].*/\1/p')
    [[ -n $name ]] || name=$(lspci -s "$1" 2>/dev/null | sed -nE 's/^[^:]+:[^:]+: (.*)$/\1/p')
    printf '%s' "${name:-NVIDIA 10de:${2#0x}}"
}

# installed kernels (their package names), from /usr/lib/modules/<version>/pkgbase
nvidia_kernels() {
    local f k
    for f in "${MONOLITH_MODULES_DIR:-/usr/lib/modules}"/*/pkgbase; do
        [[ -r $f ]] || continue
        k=""; { read -r k || :; } <"$f"
        [[ -n $k ]] && printf '%s\n' "$k"
    done | LC_ALL=C sort -u
}

# an NVIDIA kernel module is already installed (any flavour): the driver is left as it is
nvidia_has_module() {
    local p
    for p in nvidia nvidia-lts nvidia-dkms nvidia-open nvidia-open-lts nvidia-open-dkms nvidia-580xx-dkms nvidia-470xx-dkms; do
        pkg_installed "$p" && return 0
    done
    local k
    while IFS= read -r k; do pkg_installed "$k-nvidia-open" || pkg_installed "$k-nvidia" && return 0; done < <(nvidia_kernels)
    modinfo nvidia >/dev/null 2>&1
}

_nv_add() { local p; for p; do [[ " ${NV_PKGS[*]} " == *" $p "* ]] || pkg_installed "$p" || NV_PKGS+=("$p"); done; }

nvidia_plan() {
    NV_PKGS=() NV_LEGACY=0
    local driver=0
    if ! nvidia_has_module; then
        driver=1
        if (( ! NV_MODERN )); then
            NV_LEGACY=1
        else
            local k dkms=0
            while IFS= read -r k; do
                case $k in
                    linux) _nv_add nvidia-open ;;
                    linux-lts) _nv_add nvidia-open-lts ;;
                    *) if pkg_in_repos "$k-nvidia-open"; then _nv_add "$k-nvidia-open"; else _nv_add "$k-headers"; dkms=1; fi ;;
                esac
            done < <(nvidia_kernels)
            # no kernel found (a container, an unusual layout): DKMS builds for whatever kernel is there
            [[ -n $(nvidia_kernels) ]] || dkms=1
            (( dkms )) && _nv_add nvidia-open-dkms
        fi
    fi
    (( NV_LEGACY )) && return 0
    # the libraries with a driver installed here (a driver already there brings its own, maybe a legacy branch
    # that conflicts with nvidia-utils), video decoding (VA-API) and, on a hybrid laptop, prime-run
    (( driver )) && _nv_add nvidia-utils
    _nv_add libva-nvidia-driver
    (( NV_HYBRID )) && _nv_add nvidia-prime
    return 0
}
