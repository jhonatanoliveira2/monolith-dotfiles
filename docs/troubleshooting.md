# Troubleshooting

[Português (Brasil)](problemas-conhecidos.md) · **English**

Start with the most recent run log. Technical logs are stored in `~/.local/state/monolith-dotfiles/` and may contain local paths; remove personal information before sharing any excerpts.

```bash
ls -t ~/.local/state/monolith-dotfiles/*.log | head -1
```

## Installer

| Symptom | What to check |
|---|---|
| `No configuration files found` | Confirm that `configs/.config/` contains configuration files, not only empty placeholders. |
| Refuses to run as root | Run as your regular user; the installer calls `sudo` only when a package operation needs it. |
| Symlinked directory warning | Check where the link points. Use `--force-symlinks` only if you intend to write through it. |
| `No interactive terminal detected` | For pipes or automation, use `--yes` to accept defaults. |
| `pacman` failure or package not found | Check connectivity and conflicts; on Arch, update with `sudo pacman -Syu` and try again. See `packages.txt`. |
| AUR package notice | Install `paru`/`yay` or use the printed command. `--no-aur` prevents the helper from being called. |
| Backup creation fails | Check free space and permissions under `~/.local/share/monolith-dotfiles/`. Installation should not continue without a required snapshot. |
| Copy fails | Read the log. The installer attempts to roll back changes made during that operation; inspect the state before trying again. |
| Broken banner or characters | Use a UTF-8 terminal; try `--no-color` if the issue is related to colour rendering. |

## After installation

**Hyprland does not start or ignores the configuration.** Check the Hyprland version and confirm it supports the Lua `hyprland.lua` configuration. Review the compositor log and validate the modules under `~/.config/hypr/`.

**The session starts without a bar or menus.** The desktop uses Quickshell. Confirm that the `quickshell` package is installed and `~/.config/quickshell/shell.qml` was deployed. Run `./scripts/check-dependencies.sh` to find missing dependencies and files.

**Network, Bluetooth, audio or brightness controls do not respond.** Confirm that the relevant packages are installed and required services are active. The controls are configured under `configs/.config/quickshell/`.

**Wallpapers are missing.** Check that images are in `~/Pictures/Wallpapers` or videos in `~/Videos/wallpaper-live`, and that `awww`, `mpvpaper`, `ffmpeg`, `jq` and `rofi` are available. Clear old previews with `wallpaper-menu --clear-cache`.

**Language or time does not match your preference.** The configuration sets `pt_BR.UTF-8`. Generate that locale on the system if needed; the installer only warns and does not change the system-wide locale configuration.

**Neovim reports parser or plugin errors.** Check that the optional `git`, `gcc` and `tree-sitter-cli` packages are installed; in Neovim, sync plugins with `:Lazy sync`.

**Icons render as squares.** Install the fonts listed in `packages.txt` and restart the affected application.

## Restore files

```bash
./scripts/backup.sh --list
./scripts/restore.sh --dry-run
./scripts/restore.sh
```

The default restore uses the latest snapshot. To select another one, pass `--id ID`. Use `--remove-new` only if you also want to remove files that did not exist beforehand; preview first. See [Installation and recovery](installation.md#backup-and-recovery) for the full procedure.

## Get help

Open a [GitHub issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) with the Hyprland version, command used, expected behaviour and a log excerpt reviewed to remove personal information.
