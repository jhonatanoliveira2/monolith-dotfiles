# Installation

[Português (Brasil)](instalacao.md) · [English](installation.md)

## Contents
- [Requirements](#requirements) · [Step by step](#step-by-step) · [Installer options](#installer-options)
- [How the installer works](#how-the-installer-works) · [Language selection](#language-selection)
- [Backup and recovery](#backup-and-recovery) · [Repository structure](#repository-structure)
- [Uninstall](#uninstall) · [Known limitations](#known-limitations)

## Requirements

- Arch Linux (or a derivative with `pacman`), **Bash 4.4+**, `git`, `sudo` (only for `pacman`).
- **Hyprland 0.55 or newer** (Lua configuration, `hyprland.lua`) — the configs use the `hl.*` API.
- An AUR helper (`paru` or `yay`) **if** you want AUR packages installed automatically. Without one the
  installer only prints the commands.
- A regular user: the installer **refuses** to run as root.

## Step by step

```bash
git clone https://github.com/YOUR_USER/monolith-dotfiles.git
cd monolith-dotfiles
```

**1. Copy your configuration into the repository.** It ships without it, on purpose.

```bash
./scripts/import-configs.sh --with-local-bin     # recommended
```

The script copies only the expected folders (`hypr waybar fish ghostty fastfetch btop swaync nvim micro
gtk-3.0 gtk-4.0 nwg-look wal wpg`), keeps the hierarchy and file contents untouched, and **does not import**
private or generated files (list in [configuration.md](configuration.md#files-left-out)). If you prefer,
copy by hand into `configs/.config/` — the result is the same. Then check `git status` and read what is
about to be published.


**2. Install.**

```bash
./scripts/install.sh
```

Afterwards, adjust anything specific to your hardware (monitors etc. —
[configuration.md](configuration.md#machine-specific-items)) and restart your session.

## Installer options

| Option | Effect |
|---|---|
| `--lang en\|pt_BR` | Sets the language and skips the menu (also: `MONOLITH_LANG` variable) |
| `-y`, `--yes` | Asks nothing; uses defaults (optional packages are **not** installed) |
| `-n`, `--dry-run` | Shows what would be done without changing anything |
| `--no-deps` | Does not install packages |
| `--with-optional` | Also installs the optional packages from `packages.txt` |
| `--no-aur` | Never uses an AUR helper (prints the commands) |
| `--aur-helper NAME` | Uses this helper (default: `paru`, then `yay`) |
| `--force-symlinks` | Allows writing through directories that are symlinks |
| `--no-color`, `--no-clear` | No colours / do not clear the screen |
| `--version`, `-h` | Version / help |

Without an interactive terminal (e.g. in a pipe) the installer **requires** `--yes`.

## How the installer works

| # | Step | What it does |
|---|---|---|
| 1 | Check the system | Refuses root; checks Bash, Arch, writable target, symlinks and that `configs/` has files |
| 2 | Review dependencies | Report on packages and on referenced files that are missing (`check-dependencies.sh`) |
| 3 | Install packages | `pacman -S --needed` (official) and the AUR helper; asks for confirmation |
| 4 | Plan | Classifies each file: **new**, **replace** or **already up to date** |
| 5 | Backup | `backup.sh` copies the files that will be replaced and writes a manifest |
| 6 | Copy | Each file is written atomically (temporary file + rename) |
| 7 | Verify | Compares every copied file with the repository (`cmp`), restores the executable bit on scripts and creates `~/Pictures/Wallpapers` and `~/Videos/wallpaper-live` if missing |

Guarantees:

- **Nothing in `$HOME` is touched before the backup succeeds.** Package installation comes first and, if it
  fails, no configuration has been changed.
- **Automatic rollback:** if any copy fails (or you press Ctrl+C), files already written are undone —
  replaced ones come back from the backup, new ones are removed.
- **Idempotent:** identical files are skipped; with no changes, no backup is created.
- **Additive:** your files that do not exist in the repository are **never** deleted.
- **No `pacman -Sy`:** the installer never does a partial upgrade; if a package is not found, run
  `sudo pacman -Syu` and try again.
- **No global changes:** it does not change your login shell, enable services, generate locales or edit
  `/etc`. When any of that is needed it shows up as a notice.
- The technical log (in English) is at `~/.local/state/monolith-dotfiles/install-*.log`.

Exit codes: `0` ok · `1` error / no terminal · `2` empty `configs/` · `3` cancelled · `4` prerequisite (root,
symlink, conflict) · `5` `pacman` failure · `6` backup failure · `7` copy failure (rolled back).

## Language selection

Order of decision: `--lang` → `MONOLITH_LANG` variable → **menu** (on an interactive terminal; it suggests
the system language — `pt_BR` when `LANG`/`LC_ALL` starts with `pt`, otherwise English) → in
non-interactive mode, the system language → **English** (default). In the menu, Enter accepts the suggestion.
Only user-facing messages are translated; scripts, comments, variables and logs stay in English.
Messages live in `scripts/lib/messages.sh` (one line per key, both languages side by side).

## Backup and recovery

Every run that has to replace or create files writes a *snapshot*:

```text
~/.local/share/monolith-dotfiles/backups/20261010-153012/
├── manifest.tsv        # replace<TAB>path  (copied into files/)  |  new<TAB>path  (did not exist)
└── files/.config/…     # original copies; symlinks stay symlinks
```

The directory is private (`700`). Commands:

```bash
./scripts/backup.sh --list                           # list snapshots
./scripts/backup.sh                                  # manual snapshot of everything the repo manages
./scripts/restore.sh                                 # restore the latest one (asks for confirmation)
./scripts/restore.sh --id 20261010-153012            # restore a specific one
./scripts/restore.sh --remove-new                    # also remove the files the installer created
./scripts/restore.sh --dry-run                       # just show
```

`restore.sh` saves the current state **before** overwriting, so a restore can be undone too.
**Manual recovery:** copy from `.../files/<path>` to the same path under `~` (for example
`cp -a ~/.local/share/monolith-dotfiles/backups/ID/files/.config/hypr ~/.config/`).

## Repository structure

See the full tree and the role of each folder in [configuration.md](configuration.md#repository-structure).

## Uninstall

```bash
./scripts/restore.sh --id ID_OF_THE_FIRST_BACKUP --remove-new
```

This brings back the files that were replaced and removes those the installer created in that run.
Packages installed through `pacman`/AUR are **not** removed (use `pacman -Rns` yourself).

## Known limitations

- Packages marked AUR may already be in the official repositories (the installer checks `pacman -Si` first).
- The installer does not validate the Hyprland **version** or whether the installed `rofi` has a Wayland backend.
- A restore restores **files**, not packages or services.
- On terminals without UTF-8 or colours the interface falls back to plain ASCII; the banner art only
  appears under UTF-8.
