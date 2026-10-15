# Configuration

[Português (Brasil)](configuracao.md) · [English](configuration.md)

This document describes **how the repository is organised** and what the configurations do.

## Repository structure

```text
monolith-dotfiles/
├── .github/                 issue/PR templates and CI (ci.yml)
├── assets/
│   ├── logo/                logo.svg, banner.svg
│   ├── screenshots/         YOUR screenshots (empty)
│   └── previews/            installer SVG previews
├── configs/
│   ├── .config/             → ~/.config      (hypr waybar fish ghostty fastfetch btop swaync nvim micro
│   │                                          gtk-3.0 gtk-4.0 nwg-look wal wpg)
│   └── .local/bin/          → ~/.local/bin   (scripts called by key bindings)
├── scripts/
│   ├── install.sh           installer (entry point)
│   ├── backup.sh            snapshots and backup listing
│   ├── restore.sh           restore the originals
│   ├── check-dependencies.sh  packages, referenced files and system notices
│   ├── import-configs.sh    copy ~/.config into configs/ (with exclusions)
│   └── lib/                 common, i18n, messages, ui, packages
├── docs/                    this documentation
├── tests/test-installer.sh  fixture-based tests
├── tools/ansi2svg.py        generates the SVG previews
├── packages.txt  README*.md  CONTRIBUTING*.md  LICENSE  THIRD_PARTY_NOTICES.md  .gitignore
```

Rule: **everything inside `configs/` is copied as-is** into the home directory; nothing is generated or rewritten.
`.gitkeep` files are placeholders and are never installed.

## What each folder contains

| Folder | Contents |
|---|---|
| `hypr/` | `hyprland.lua` loads Lua modules from `modules/`: `core`, `environment`, `monitors`, `input`, `layout`, `animations`, `misc`, `autostart`, `programs`, `keybindings`, `media-keys`, `window-rules`; plus `scheme/current.lua` (colours), `hyprland-gui.lua`, `hyprlock.conf`, `xdph.conf` and `rofi/launcher.{sh,rasi}`, `rofi/wallpaper-menu.rasi` |
| `waybar/` | `config.jsonc`, `style.css`, `colors/`, `rofi/audio-menu.rasi` and `scripts/` (`player`, `sysmon`, `network-status`, `audio-menu`, `power-profile`, `waybar-launch`) |
| `swaync/` | Notification center |
| `ghostty/` | `config.ghostty` (runs `fish`) and cursor `shaders/` (their own MIT license) |
| `fish/` | `config.fish` (Hyprland autostart on TTY1, `ai`/`aic` functions, starship, atuin), completions |
| `fastfetch/` | `config.jsonc`, `random_logo.sh`, `ascii/arch.txt` (+ PNG logo images) |
| `btop/` | `btop.conf` |
| `micro/` | `settings.json`, `bindings.json`, `colorschemes/one-dark.micro` |
| `nvim/` | LazyVim starter (`init.lua`, `lua/config/*`, `lazyvim.json`, `lazy-lock.json`) |
| `gtk-3.0/`, `gtk-4.0/`, `nwg-look/` | `settings.ini`, `gtk.css`, `nwg-look` config (Adwaita theme) |
| `wal/`, `wpg/` | `wpg.conf` (`wal` backend), `keywords.conf`, `wp_init.sh` |

### Main key bindings (`hypr/modules/keybindings.lua`)

| Binding | Action |
|---|---|
| `SUPER+Return` | terminal (`ghostty`) |
| `SUPER+A` | toggles the Rofi launcher (`~/.config/hypr/rofi/launcher.sh`) |
| `SUPER+C` | notification center (`swaync-client -t -sw`) |
| `SUPER+TAB` | `zen-browser` |
| `SUPER+Delete` / `+SHIFT` | screenshot (monitor `DP-1`) / of an area; copied to the clipboard |
| `SUPER+R` | start/stop screen recording (`gpu-screen-recorder`, HEVC 60 FPS) |
| `SUPER+D` | wallpaper menu (`~/.local/bin/wallpaper-menu`) |
| `SUPER+Space` / `S` / `F` / `Q` | float and centre at 70% / toggle floating / fullscreen / close |
| `SUPER+W` (+`SHIFT`/`ALT`) | special workspace |
| Media keys | `wpctl` (volume/mute), `brightnessctl`, `playerctl` |

## Machine-specific items

Review these **before** using the setup on another computer:

- `hypr/modules/monitors.lua`: outputs `DP-1` (1920×1080@300, position `1920x0`) and `DP-2` (1920×1080@180,
  position `0x0`). Adjust names, resolutions and refresh rates.
- `hypr/modules/keybindings.lua`: the full-screen screenshot uses `grim -o DP-1` (fixed monitor); recording needs
  GPU HEVC encoding and uses `/tmp/osu-gsr.pid`.
- `hypr/modules/core.lua`: `cursor.no_hardware_cursors = 1` (usually a workaround for certain GPUs).
- `hypr/modules/environment.lua`: `LANG`/`LC_TIME = pt_BR.UTF-8` — the locale must exist on the system
  (the installer warns if it does not, but does **not** generate it).
- `hypr/modules/input.lua`: `us` layout, sensitivity `-0.2`, 3-finger gesture for workspaces.
- `fish/config.fish`: on TTY1, without `WAYLAND_DISPLAY`, it runs `exec start-hyprland` — this only works if
  your login shell is `fish` (the installer does not change your shell).
- `waybar/config.jsonc`: backlight device `intel_backlight` (see `ls /sys/class/backlight`).

## Wallpapers

`SUPER+D` opens `wallpaper-menu`, a Rofi menu (theme: `hypr/rofi/wallpaper-menu.rasi`) with previews:

| Type | Folder | Engine |
|---|---|---|
| Static | `~/Pictures/Wallpapers` | `awww` |
| Animated (`.mp4`) | `~/Videos/wallpaper-live` | `mpvpaper` |

The installer creates both folders (it never touches their content). Previews are generated with `ffmpeg` and
cached in `~/.cache/wallpaper-menu/`. Run `wallpaper-menu --restore` from the autostart (after `awww-daemon`) to
reapply the last choice; `wallpaper-menu --clear-cache` removes the previews.

## Files left out

`import-configs.sh` and `.gitignore` **do not include** these (nothing is deleted from your machine):

| Pattern | Reason |
|---|---|
| `micro/backups/` | copies of edited files — may hold secrets and personal paths |
| `fish/fish_variables` | universal variables: `PATH` and machine paths |
| `fish/conf.d/*.env.fish` | generated by third-party installers, with absolute paths |
| `wpg/schemes/`, `wpg/sequences`, `wpg/samples/` | generated from the wallpaper, with absolute paths |
| `wal/colors*`, `wal/sequences` | pywal cache |
| `*.bak`, `*~`, `*.swp`, `*.tmp`, `*.log`, `__pycache__`, `.git`, `.DS_Store` | junk and local artefacts |
| `.env*`, `*.key`, `*.pem`, `*.gpg`, `auth.json`, `credentials*`… | secrets (`.gitignore` only) |

To publish any of them, remove the pattern from `.gitignore` and from `EXCLUDES` in
`scripts/import-configs.sh` **after checking the content**. Before any `git push`, review what is in `configs/` —
personal data may still exist in files the filter does not know about.
