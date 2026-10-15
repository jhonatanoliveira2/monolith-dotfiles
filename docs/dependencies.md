# Dependencies

[Português (Brasil)](dependencias.md) · [English](dependencies.md)

The machine-readable list is [`../packages.txt`](../packages.txt) (`[source:scope]` sections). This document
explains **how** it was built and **why**.

## Criteria

- **Required**: something in the *active* configuration calls it — autostart, key binding, Waybar module, script
  or environment variable.
- **Optional**: the app has an included configuration but **nothing launches it** (you open it by hand), or the
  feature only matters on some machines (laptop, X11).
- **Commented-out or inert items were not promoted** (e.g. the `fastfetch` call in `config.fish` is commented
  out; `programs.ide = "code"` is not used by any binding).
- Packages from the `base` group (bash, coreutils, procps-ng, util-linux, systemd, …) are assumed.

## Required official packages

| Package | Used by |
|---|---|
| `hyprland` | `hyprland.lua`, `start-hyprland` (fish) |
| `hyprlock` | `SUPER+Z` binding, `hyprlock.conf` |
| `xdg-desktop-portal-hyprland` | `hypr/xdph.conf` |
| `lxqt-policykit` | autostart `/usr/bin/lxqt-policykit-agent` |
| `qt6ct` | `QT_QPA_PLATFORMTHEME=qt6ct` |
| `waybar`, `swaync`, `rofi` | autostart, `SUPER+A`/`SUPER+C` bindings, audio menu |
| `ghostty`, `fish`, `starship`, `atuin` | terminal; shell; `starship`/`atuin init fish` on every interactive shell |
| `nautilus` | `programs.lua` (`SUPER+X`) |
| `ttf-jetbrains-mono-nerd` | Waybar, Rofi and swaync themes (*JetBrainsMono Nerd Font*) |
| `grim`, `slurp`, `wl-clipboard`, `libnotify`, `jq` | screenshot and recording bindings (`grim`, `slurp`, `wl-copy`, `notify-send`, `jq`); `jq` is also used by `wallpaper-menu` |
| `ffmpeg` | `wallpaper-menu`: previews of images and videos |
| `pipewire`, `pipewire-pulse`, `wireplumber`, `libpulse` | `wpctl` (media keys), `pactl` (Waybar: mute and sink menu) |
| `playerctl` | media keys, Waybar player, hyprlock label |
| `brightnessctl` | brightness keys |
| `networkmanager`, `network-manager-applet` | network module (click opens `nm-connection-editor`) |
| `blueman` | Bluetooth module (click opens `blueman-manager`) |
| `curl` | `network-status.sh` (real connectivity check) |

## Optional official packages

| Package | Note |
|---|---|
| `fastfetch`, `btop`, `micro` | configuration included; nothing launches them |
| `neovim`, `git`, `gcc`, `tree-sitter-cli`, `ripgrep`, `fd` | LazyVim: `git` clones plugins; `gcc` and `tree-sitter-cli` build parsers; `ripgrep`/`fd` are recommended |
| `nwg-look` | GTK theme manager, used by hand |
| `python-pywal` | `wpg` backend (`backend = wal`); only if you run `wpg` |
| `power-profiles-daemon` | power-profile module (laptop); without it the module stays hidden. With TLP/auto-cpufreq, do not install |
| `xorg-xwayland` | X11 apps (there is a window rule for `xwayland`) |

## AUR

| Package | Scope | Note |
|---|---|---|
| `awww` | required | autostart of `awww-daemon`; static wallpapers in `wallpaper-menu`. May already be in the official repositories |
| `mpvpaper` | required | animated wallpapers in `wallpaper-menu` (may already be in the official repositories) |
| `zen-browser-bin` | optional | `SUPER+TAB` |
| `gpu-screen-recorder` | optional | `SUPER+R` (may be in the official repositories) |
| `hyprshutdown` | optional | `SUPER+X` falls back to `hyprctl dispatch exit` |
| `wpgtk` | optional | the `wpg` command (`wp_init.sh`, `wpg/`) |

The installer checks `pacman -Si` first: whatever is already in the official repositories is installed with `pacman`.

## Services and locale (not changed by the installer)

`NetworkManager.service`, `bluetooth.service` and, on a laptop, `power-profiles-daemon.service` must be
running for the matching modules. The `pt_BR.UTF-8` locale must be generated (`/etc/locale.gen`).
`check-dependencies.sh` only warns.

## Checking

```bash
./scripts/check-dependencies.sh                         # full report
./scripts/check-dependencies.sh --list-missing=required # only what is missing (machine output)
./scripts/check-dependencies.sh --strict                # exits 1 if a required package is missing
```
