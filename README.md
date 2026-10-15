<p align="center">
  <img src="assets/logo/banner.svg" alt="MONOLITH Dotfiles" width="100%">
</p>

<p align="center">
  <a href="README.pt-br.md">Português (Brasil)</a> · <b>English</b>
</p>

<p align="center">
  <img alt="Platform: Arch Linux" src="https://img.shields.io/badge/platform-Arch_Linux-00e5ff?style=flat-square&labelColor=14161a&logo=archlinux&logoColor=white">
  <img alt="Window manager: Hyprland" src="https://img.shields.io/badge/WM-Hyprland-00e5ff?style=flat-square&labelColor=14161a">
  <img alt="Shell: Bash" src="https://img.shields.io/badge/shell-Bash-8b9099?style=flat-square&labelColor=14161a">
  <img alt="Documentation: Portuguese and English" src="https://img.shields.io/badge/docs-PT--BR_%7C_EN-8b9099?style=flat-square&labelColor=14161a">
  <img alt="License: not yet defined" src="https://img.shields.io/badge/license-not_yet_defined-555b63?style=flat-square&labelColor=14161a">
</p>

# MONOLITH Dotfiles

A minimalist **Arch Linux + Hyprland** desktop. MONOLITH brings together a Lua-based compositor setup, status bar, notifications, launcher, terminal, shell, editors, and themes—alongside a terminal installer that backs up existing files before replacing them.

## Contents

- [Highlights](#highlights)
- [Tested environment](#tested-environment)
- [Included configurations](#included-configurations)
- [Quick start](#quick-start)
- [Dependencies](#dependencies)
- [Backups and recovery](#backups-and-recovery)
- [Installer preview](#installer-preview)
- [Documentation](#documentation)
- [Repository layout](#repository-layout)

## Highlights

- **Bilingual installer:** English by default, with Brazilian Portuguese available; includes a welcome screen, language selection, seven steps, progress bars, and a final summary.
- **Backup before replacement:** backs up every file that differs, rolls back automatically if copying fails, and includes a restore command (`scripts/restore.sh`).
- **Idempotent installation:** a second run skips files that are already identical and avoids unnecessary backups.
- **No root install:** `sudo` is used only when installing packages with `pacman`. The installer does not change your login shell, services, or system locale; it only displays notices about them.
- **Focused dependencies:** packages are grouped as official, AUR, or manual, with explanations in [`packages.txt`](packages.txt) and [`docs/dependencies.md`](docs/dependencies.md).
- **Wallpaper menu:** open the Rofi menu with `SUPER+D` to browse static (`awww`) and animated (`mpvpaper`) wallpapers.
- **Configuration import:** `import-configs.sh` copies selected folders from `~/.config` into the repository while excluding private or machine-specific content.

## Tested environment

| Component | Validated setup |
|---|---|
| Operating system | Arch Linux, minimal installation |
| Hyprland | 0.55 or newer (Lua configuration) |
| CPU | AMD Ryzen 7 5700X |
| GPU | AMD Radeon RX 9060 XT |

## Included configurations

| Directory | Contents |
|---|---|
| `hypr/` | Hyprland in **Lua** (modules), hyprlock, XDPH portal, Rofi launcher, and wallpaper menu |
| `waybar/` | Status bar and scripts for the player, network, system monitor, power profile, and audio menu; includes a Rofi theme |
| `swaync/` | Notification center |
| `ghostty/` | Terminal and cursor shaders |
| `fish/` | Shell setup with Starship and Atuin |
| `fastfetch/` | System information with random logos |
| `btop/`, `micro/`, `nvim/` | Resource monitor and editors (Neovim with LazyVim) |
| `gtk-3.0/`, `gtk-4.0/`, `nwg-look/` | GTK theme settings |
| `wal/`, `wpg/` | Wallpaper-derived color schemes |

See [Configuration](docs/configuration.md) for folder-by-folder details, machine-specific items, and known gaps.

## Quick start

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles

# Executable permissions.
chmod +x scripts/*.sh

# Apply the installation.
./scripts/install.sh
```

The installer also creates these wallpaper folders:

- `~/Pictures/Wallpapers` for static wallpapers
- `~/Videos/wallpaper-live` for animated `.mp4` wallpapers

<details>
<summary><strong>Installer options</strong></summary>

| Option | Purpose |
|---|---|
| `--lang en` | Run the installer in English (the default) |
| `--yes` | Skip interactive confirmation prompts |
| `--no-deps` | Skip dependency installation |
| `--with-optional` | Include optional packages |
| `--no-aur` | Skip AUR packages |

See the [full installation guide](docs/installation.md) for the complete procedure.

</details>

## Dependencies

Required, optional, and manual dependencies are listed in [`packages.txt`](packages.txt), together with the reason for each entry. Check your system at any time:

```bash
./scripts/check-dependencies.sh
```

For the rationale behind the package list, see the [dependency analysis](docs/dependencies.md).

## Backups and recovery

Backups are stored in `~/.local/share/monolith-dotfiles/backups/<date-time>/`.

```bash
./scripts/backup.sh --list                         # List available backups
./scripts/restore.sh                               # Restore the latest backup
./scripts/restore.sh --id YYYYMMDD-HHMMSS --remove-new  # Restore one backup and remove newly added files
```

Read [Backup and recovery](docs/installation.md#backup-and-recovery) for additional details and manual recovery steps.

## Installer preview

<p align="center">
  <img src="assets/previews/installer-welcome.svg" alt="MONOLITH installer welcome screen" width="640">
</p>

## Documentation

- [Installation](docs/installation.md)
- [Configuration](docs/configuration.md)
- [Dependencies](docs/dependencies.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Contributing](CONTRIBUTING.en.md)

## Repository layout

```text
monolith-dotfiles/
├── configs/.config/…      # Your configuration files → ~/.config
├── configs/.local/bin/    # Scripts used by key bindings → ~/.local/bin
├── scripts/               # Installer, backup, restore, checks, and import tools
│   └── lib/                # UI, translations, messages, packages, and helpers
├── docs/                   # English and Brazilian Portuguese documentation
├── assets/                 # Logo, screenshots, and previews
├── tests/                  # Installer tests
├── tools/                  # SVG preview generator
├── packages.txt            # Official, AUR, and manual dependencies
└── .github/                # Issue and pull-request templates; CI
```
