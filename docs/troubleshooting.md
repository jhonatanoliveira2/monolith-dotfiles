# Troubleshooting

[Português (Brasil)](solucao-de-problemas.md) · [English](troubleshooting.md)

First, look at the **technical log** (in English) of the last run:

```bash
ls -t ~/.local/state/monolith-dotfiles/*.log | head -1 | xargs less
```

When opening an *issue*, attach the log **after removing personal data**.

## Installer

| Symptom | Likely cause | What to do |
|---|---|---|
| `No configuration files found in …` (code 2) | `configs/.config/` only has placeholders | Copy your folders: `./scripts/import-configs.sh` |
| `Do not run this installer as root` (4) | Run with `sudo`/as root | Run as a regular user; `sudo` is called only for `pacman` |
| `Refusing to write through a symlinked directory` (4) | `~/.config/<folder>` is a symlink (e.g. managed by stow) | Remove the link, or use `--force-symlinks` knowing the link target will be modified |
| `A directory exists where a file is expected` (4) | A folder has the name of a repository file | Rename/move the folder and run again |
| `No interactive terminal detected` (1) | No TTY (pipe, CI) | Use `--yes` |
| `pacman failed` (5) | Outdated database, network or conflict | `sudo pacman -Syu` and try again — no configuration was changed |
| AUR packages notice | No `paru`/`yay`, or the build failed | Install a helper, or run the printed command; use `--no-aur` to silence it |
| Package not found | Renamed or not in the repositories yet | See `packages.txt`; install manually and use `--no-deps` |
| `Backup failed` (6) | Disk full or no permission in `~/.local/share` | Free space/fix permissions — nothing was changed |
| `Failed to copy` (7) | Error writing a file | The installer already **rolled back** everything; see the log and run again |
| Odd banner or borders | Terminal without UTF-8/256 colours | Use `--no-color`; set a UTF-8 locale (`LANG=en_US.UTF-8`) |

## After installing

**Hyprland does not start / config ignored.** The configs use Lua (`hl.*`). Confirm your Hyprland supports
`hyprland.lua` (`Hyprland --version`; check the release notes). Look for the Hyprland log (in `$XDG_RUNTIME_DIR/hypr/` or
`~/.cache/hyprland/`, depending on the version). To go back to the previous state: `./scripts/restore.sh`.

**Black screen on TTY1 or the session does not come up.** `fish/config.fish` runs `exec start-hyprland` on
TTY1. If your login shell is not `fish`, nothing happens; if it is, a config error kills the session. Switch to
another TTY (`Ctrl+Alt+F2`), restore (`./scripts/restore.sh`) and investigate.

**Wrong monitors / resolution.** Edit `~/.config/hypr/modules/monitors.lua` 

**Text in the wrong language or broken characters.** The `pt_BR.UTF-8` locale does not exist: uncomment it in
`/etc/locale.gen` and run `sudo locale-gen`.

**Lock screen errors / missing labels.** `hypr/hyprlock-colors.conf` or `hypr/scripts/password-cursor.sh` is
missing. Copy them into `configs/` and run the installer again;
`./scripts/check-dependencies.sh --section advice` lists what is missing.

**`SUPER+D` does not open the wallpaper menu.** Check `~/.local/bin/wallpaper-menu` (executable) and
`~/.config/hypr/rofi/wallpaper-menu.rasi`; install `rofi`, `jq`, `awww`, `mpvpaper` and `ffmpeg`. Folders are
`~/Pictures/Wallpapers` (static) and `~/Videos/wallpaper-live` (`.mp4`). Wrong previews: `wallpaper-menu --clear-cache`.

**Bar, network, audio or Bluetooth unresponsive.** Check services and packages:
`systemctl status NetworkManager bluetooth`, `pactl info`, `playerctl -l`.
**Power profile missing:** laptop only, and `power-profiles-daemon` must be running.

**Screenshots/recording fail.** `grim`, `slurp`, `wl-clipboard`, `jq` and `gpu-screen-recorder` must be installed;
recording needs a GPU with HEVC encoding.

**Neovim downloads plugins on every start / parser errors.** Install `git`, `gcc` and `tree-sitter-cli`
(optional in `packages.txt`) and run `:Lazy sync`.

**Square icons in the bar/terminal.** Install `ttf-jetbrains-mono-nerd` and restart the bar.

## Recovery

```bash
./scripts/backup.sh --list          # available snapshots
./scripts/restore.sh                # back to the latest one
./scripts/restore.sh --dry-run      # only show what would be restored
```

Step by step and manual recovery: [installation.md](installation.md#backup-and-recovery).

## Still stuck?

Open an *issue* using the report template: Hyprland version, command used, a log excerpt (without personal
data) and what you expected.
