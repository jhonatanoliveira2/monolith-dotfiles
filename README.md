<p align="center">
  <img src="assets/logo/banner.svg" alt="MONOLITH — Arch Linux desktop configuration" width="960">
</p>

<p align="center">
  <a href="README.pt-br.md">Português (Brasil)</a> · <strong>English</strong>
</p>

<p align="center">
  <img alt="Arch Linux" src="https://img.shields.io/badge/OS-Arch_Linux-1793d1?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Hyprland" src="https://img.shields.io/badge/Compositor-Hyprland-00d9f5?style=for-the-badge">
  <img alt="Bash" src="https://img.shields.io/badge/Installer-Bash-4eaa25?style=for-the-badge&logo=gnubash&logoColor=white">
  <img alt="MIT license" src="https://img.shields.io/badge/License-MIT-8b9099?style=for-the-badge">
</p>

<h1 align="center">MONOLITH Dotfiles</h1>

## Preview

<p align="center">
  <a href="https://vimeo.com/1238180685">
    <img src="https://i.postimg.cc/Ppy5hLbc/2026-10-21-20-00-31.png" alt="Video preview" width="100%">
  </a>
</p>

## Screenshots

<p align="center">
  <img src="https://i.postimg.cc/D4fmbQyv/2026-10-21-18-13-04.png" alt="Desktop" width="100%">
</p>

<p align="center">
  <img src="https://i.postimg.cc/2Lj3Bd83/2026-10-21-18-14-12.png" alt="Quickshell" width="100%">
</p>

<p align="center">
  <img src="https://i.postimg.cc/4nXYMGvc/2026-10-21-18-15-51.png" alt="Launcher and menus" width="100%">
</p>


<p align="center">
  A cohesive Arch Linux desktop built around Hyprland, Quickshell and a careful, reversible installer.
</p>

<p align="center">
  <a href="#screenshots">Explore the desktop</a> ·
  <a href="#quick-start">Install</a> ·
  <a href="#documentation">Read the guides</a>
</p>

## At a glance

MONOLITH brings the compositor, desktop shell, terminal, shell environment, launchers and visual settings together in one repository. Its installer checks dependencies, backs up files before replacing them and can roll back a failed copy. The supplied configuration is deliberately hardware-specific in a few places, so review it before applying it to another machine.

| Desktop layer | Included setup |
|---|---|
| Window manager | Hyprland, configured in Lua with modular settings |
| Desktop shell | Quickshell bar, menus, notifications and system controls |
| Terminal and shell | Ghostty, Fish, Starship and Atuin |
| Launching and files | Rofi, Nautilus and a wallpaper selector |
| Personal tools | Neovim, Micro and btop settings |
| Appearance | GTK settings, wallpaper-derived palettes and cursor shaders |

## Why MONOLITH

- **Safer changes:** existing files are backed up before replacement; interrupted copies are rolled back.
- **Repeatable runs:** identical files are skipped, and user files absent from the repository are left alone.
- **Transparent setup:** dependency checks distinguish required and optional packages, and explain missing referenced files.
- **Useful recovery:** list snapshots, restore the latest one or select a specific backup.
- **No silent system changes:** the installer does not switch your login shell, enable services or edit `/etc`.

## Quick start

**Requirements:** Arch Linux, Bash 4.4+, Git and a regular user account. Hyprland 0.55 or newer is required for the included Lua configuration. An AUR helper (`paru` or `yay`) is needed only if you want the installer to build AUR packages automatically.

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles
./scripts/install.sh
```

The installer copies the configurations included in `configs/` to your home directory. It also installs packages unless `--no-deps` is passed, and places the bundled wallpapers in `~/Pictures/Wallpapers` and `~/Videos/wallpaper-live`.

<details>
  <summary><strong>Backup and recovery</strong></summary>

  ```bash
  ./scripts/backup.sh --list
  ./scripts/restore.sh
  ./scripts/restore.sh --dry-run
  ```

  Backups are stored under `~/.local/share/monolith-dotfiles/backups/`. See the [installation guide](docs/Installation.md#backup-and-recovery) for restoring a specific snapshot or recovering files manually.
</details>

## Installer preview

<p align="center">
  <img src="assets/previews/installer-welcome.svg" alt="MONOLITH installer welcome and setup steps" width="760">
</p>

<details>
  <summary>View an additional installer screen</summary>
  <p align="center"><img src="assets/previews/installer-run.svg" alt="MONOLITH installer progress and completion screen" width="760"></p>
</details>

## Documentation

| Guide | English | Português (Brasil) |
|---|---|---|
| Installation and recovery | [Installation](docs/Installation.md) | [Instalação](docs/Instalacao.md) |
| Configuration and hardware notes | [Configuration](docs/config.md) | [Configuração](docs/configuracao.md) |
| Package rationale | [Dependencies](docs/dependencies.md) | [Dependências](docs/Dependencias.md) |
| Common issues | [Troubleshooting](docs/Troubleshooting.md) | [Solução de problemas](docs/Problemas-conhecidos.md) |
| Contributing | [Contributing](CONTRIBUTING.en.md) | [Contribuindo](CONTRIBUTING.md) |

## Repository map

```text
configs/                 Desktop configuration payload copied into your home
scripts/                 Installer, backup, restore, checks and import utility
docs/                    Paired English and Brazilian Portuguese guides
assets/                  Brand artwork, installer previews and screenshot slots
wallpapers/              Bundled static and live wallpapers
tests/                   Installer and documentation checks
tools/                   Utility for rendering terminal previews
packages.txt             Required, optional and AUR package manifest
LICENSE                  MIT
```

The installer and configuration files are provided as-is. Read the [third-party notices](THIRD-PARTY-CREDITS.md) before redistributing included components.
