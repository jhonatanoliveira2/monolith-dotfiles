# Installation and recovery

[Português (Brasil)](instalacao.md) · **English**

This guide installs the configuration already included in the repository. You do not need to import files from your home directory to get started.

## Requirements

- Arch Linux, CachyOS or another distribution based on Arch that uses `pacman` (see [Arch Linux and CachyOS](#arch-linux-and-cachyos)).
- Bash 4.4+, Git and a regular user account. The installer refuses to run as root.
- Hyprland 0.55 or newer for the included Lua configuration.
- `paru` or `yay` only if you want AUR packages built automatically. Without a helper, the installer prints the commands for manual installation (on CachyOS it offers to install one from the repositories).

## Install

Clone the repository and review the hardware-specific settings before applying them:

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles

```

Preview the plan, then run the installer if it looks right:

```bash
./scripts/install.sh
```

The installer checks prerequisites and dependencies, plans the files to deploy, snapshots files that will be replaced, and then copies the configuration. It also makes the project wallpapers available in `~/Pictures/Wallpapers` and `~/Videos/wallpaper-live`.

## Arch Linux and CachyOS

The installer reads `/etc/os-release` and reports what it found: Arch Linux (`ID=arch`), CachyOS (`ID=cachyos`) or another `pacman` distribution (`ID_LIKE=arch`). All of them go through the same steps; the differences between them are handled by checks that also run on Arch, not by separate code paths:

- **Repositories.** Every package is looked up first in the repositories configured in `pacman.conf`. On CachyOS these include its own repositories (optimised builds, plus packages that on Arch only exist in the AUR), so those are installed with `pacman` instead of being built.
- **AUR helper.** When neither `paru` nor `yay` is installed but the repositories ship one (CachyOS does), the installer offers to install it with `pacman` and then uses it. On Arch nothing changes: without a helper, the manual commands are printed.
- **Conflicts.** A package that conflicts with something already installed (an audio server or power daemon the distribution chose, for example) is left out and listed in the summary; the installed one is kept. Otherwise `pacman` would abort the whole installation. Replace it by hand if you prefer the MONOLITH choice.
- **Kernel and system tools.** Nothing depends on the kernel package (`linux`, `linux-cachyos`, ...): the shell reads `/proc` and `/sys`. Partitions with several btrfs subvolumes (the CachyOS default) are shown once in the Performance tab, with the number of extra mount points.
- **fish.** On CachyOS, `~/.config/fish/config.fish` normally just loads `cachyos-fish-config`. The installer replaces it with the MONOLITH version (the original goes into the backup snapshot). To keep the CachyOS aliases, add `source /usr/share/cachyos-fish-config/cachyos-config.fish` inside the `status is-interactive` block.
- **Hyprland edition.** An existing `~/.config/hypr/hyprland.conf` does not get in the way: when both files exist, Hyprland loads `hyprland.lua`.
- **Logo.** The shell shows the logo of the distribution it runs on (bar, quick menu, welcome screen, dashboard). The CachyOS logo comes from the `linux-cachyos` glyph of the Nerd Font (present in `ttf-jetbrains-mono-nerd` 3.5).

## Installer options

| Option | Effect |
|---|---|
| `--lang en\|pt_BR` | Selects the interface language and skips the interactive picker. Also accepts `MONOLITH_LANG`. |
| `-y`, `--yes` | Accepts defaults without prompting; optional packages are included (use `--no-optional` to skip them). |
| `-n`, `--dry-run` | Shows the planned actions without applying changes. |
| `--no-deps` | Does not install packages. |
| `--with-optional` | Installs the optional packages in `packages.txt` without asking. |
| `--no-optional` | Skips the optional packages. |
| `--no-aur` | Does not call an AUR helper; prints manual commands. |
| `--aur-helper NAME` | Selects the AUR helper (defaults to `paru`, then `yay`). |
| `--force-symlinks` | Allows writes through symlinked directories under `$HOME`. Review their targets first. |
| `--no-color`, `--no-clear` | Disables colours or screen clearing. |
| `--version`, `-h`, `--help` | Shows the version or help. |

Use `--yes` when there is no interactive terminal. Check `./scripts/install.sh --help` for the syntax supported by the installed version.

## Backup and recovery

The installer runs as a regular user; `sudo` is used only for `pacman` operations that need elevated privileges. A snapshot is created when existing files will be replaced. Identical files are skipped, and personal files absent from the repository are not removed.

```bash
./scripts/backup.sh --list
./scripts/backup.sh --dry-run
./scripts/restore.sh --dry-run
./scripts/restore.sh
```

`restore.sh` uses the latest snapshot by default and asks for confirmation. To select one, run `./scripts/restore.sh --id ID`. The `--remove-new` option also removes files that did not exist before installation; review the plan with `--dry-run` first. Restore snapshots the current state before overwriting it, so the restore can be undone as well.

Snapshots are stored in `~/.local/share/monolith-dotfiles/backups/`. Their manifest records which files were replaced and which were created. Technical logs are in `~/.local/state/monolith-dotfiles/`.

## Import your own configuration

Importing is optional. It prepares a working copy from `~/.config`; it is not required to install the included payload.

```bash
./scripts/import-configs.sh --dry-run
./scripts/import-configs.sh --with-local-bin
```

The importer handles only the folders it recognises, preserves their structure and never deletes files from the source. It excludes caches, Micro editor backups, `fish_variables`, generated `.env.fish` files and other local artefacts; see [Configuration](config.md#import-exclusions). Review everything that will be published: the filter cannot identify every possible secret.

## Uninstall

To reverse an installation, list snapshots, identify the one from before the first install and preview the restore:

```bash
./scripts/restore.sh --list
./scripts/restore.sh --id SNAPSHOT_ID --dry-run
./scripts/restore.sh --id SNAPSHOT_ID --remove-new
```

This can restore replaced files and remove files created in that snapshot. Packages installed through `pacman` or the AUR are not removed automatically.

## Known limitations

- Some settings depend on your hardware and installed software; review [Configuration](config.md) before starting the session.
- Package availability can vary between the official repositories and the AUR. The installer checks the official repositories before using an AUR helper.
- Restore recovers files, not packages, services or settings outside the payload.
