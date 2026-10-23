<h1 align="center">monolith-Dotfiles</h1>

<p align="center">
  <img alt="Arch Linux" src="https://img.shields.io/badge/OS-Arch_Linux-1793d1?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Hyprland" src="https://img.shields.io/badge/Compositor-Hyprland-00d9f5?style=for-the-badge">
  <img alt="Bash" src="https://img.shields.io/badge/Installer-Bash-4eaa25?style=for-the-badge&logo=gnubash&logoColor=white">
  <img alt="MIT" src="https://img.shields.io/badge/License-MIT-8b9099?style=for-the-badge">
</p>

<p align="center">
  <a href="README.pt-br.md">Português (Brasil)</a> · <strong>English</strong>
</p>

https://github.com/user-attachments/assets/3df9da29-d3b5-43b1-9512-f72b0a0250b3
- [Watch on YouTube](https://youtu.be/W_SYo-i9fXk)


### Screenshots

<p align="center">
  <img src="assets/screenshots/1.png" width="100%">
  <img src="assets/screenshots/2.png" width="100%">
  <img src="assets/screenshots/3.png" width="100%">
</p>

<p align="center">
  <a href="#screenshots">Explore the desktop</a> ·
  <a href="#quick-start">Install</a> ·
  <a href="#documentation">Read the guides</a>
</p>

### At a glance

MONOLITH brings the compositor, desktop shell, terminal, shell environment, launchers and visual settings together in one repository. Its installer checks dependencies, backs up files before replacing  them and can roll back a failed copy. The supplied configuration is deliberately hardware-specific in a few places, so review it before applying it to another machine.

| Desktop layer | Included setup |
|---|---|
| Window manager | Hyprland, configured in Lua with modular settings |
| Desktop shell | Quickshell bar, menus, notifications and system controls |
| Terminal and shell | Ghostty, Fish, Starship and Atuin |
| Launching and files | Rofi, Nautilus and a wallpaper selector |
| Personal tools | Neovim, Micro and btop settings |
| Appearance | GTK settings, wallpaper-derived palettes and cursor shaders |


### Quick start

[!CAUTION] 
> Check the specific monitor, input, and language options in docs/configuracao.md before installing.

Requirements: `Arch Linux`, `Bash 4.4+`, `Git` and a regular `user account`. `Hyprland 0.55 or newer` is required for the included Lua configuration. An AUR helper (**paru** or **yay**) is needed only if you want the installer to build AUR packages automatically.

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles
./scripts/install.sh
```

> [!TIP]
> The installer copies the configurations included in `configs/` to your home directory. It also installs packages unless `--no-deps` is passed, and places the bundled wallpapers in `~/Pictures/Wallpapers` and `~/Videos/wallpaper-live`.

<details>
  <summary><strong>Backup and recovery</strong></summary>

  ```bash
  ./scripts/backup.sh --list
  ./scripts/restore.sh
  ./scripts/restore.sh --dry-run
  ```

  Backups are stored under `~/.local/share/monolith-dotfiles/backups/`. See the [installation guide](docs/Installation.md#backup-and-recovery) for restoring a specific snapshot or recovering files manually.
</details>

### Installer preview

<p align="center">
  <img src="assets/previews/installer-welcome.svg" alt="MONOLITH installer welcome and setup steps" width="760">
</p>

<details>
  <summary>View an additional installer screen</summary>
  <p align="center"><img src="assets/previews/installer-run.svg" alt="MONOLITH installer progress and completion screen" width="760"></p>
</details>

### Hyprland Keybinds

| Keybind | Action | Description |
|---------|--------|-------------|
| `SUPER + Return` | Terminal | Opens the terminal (`programs.terminal`) |
| `SUPER + X` | File Manager | Opens the file manager (`programs.fileManager`) |
| `SUPER + C` | Code | Opens VS Code / Cursor |
| `SUPER + TAB` | Browser | Opens Zen Browser |
| `SUPER + Z` | Lock | Locks the session with `hyprlock` |
| `SUPER + A` | App Launcher | Toggles Rofi launcher (`~/.config/hypr/rofi/launcher.sh`) |
| `SUPER + Delete` | Screenshot (Full) | Captures full screen (DP-1), saves to `~/Pictures` and copies to clipboard |
| `SUPER + SHIFT + Delete` | Screenshot (Area) | Captures selected area with `slurp` + `grim`, saves and copies to clipboard |
| `SUPER + R` | Screen Recording | Toggles GPU Screen Recorder (`toggle-gsr.sh`) saves to `~/Videos` |
| `SUPER + D` | Wallpaper Menu | Opens wallpaper selector (`~/.local/bin/wallpaper-menu`) |
| `SUPER + SHIFT + X` | Exit Session | Runs `hyprshutdown` if available, otherwise exits Hyprland |
| `SUPER + Space` | Toggle Float + Center | Toggles floating mode and centers the window (70% of monitor size) |
| `SUPER + S` | Toggle Float | Toggles floating mode without centering |
| `SUPER + Q` | Close Window | Closes the active window |
| `SUPER + F` | Fullscreen | Toggles fullscreen mode |
| `SUPER + SHIFT + ←/→/↑/↓` | Move Window | Moves the active window in the given direction (group-aware) |
| `SUPER + ←/→/↑/↓` | Focus Window | Moves focus in the given direction |
| `SUPER + ALT + ←/→/↑/↓` | Resize Window | Resizes the active window (40px steps, repeating) |
| `SUPER + W` | Special Workspace | Toggles the special workspace `"magic"` |
| `SUPER + SHIFT + W` | Move to Special | Moves active window to the special workspace |
| `SUPER + ALT + W` | Move to Next Monitor | Moves active window to the next monitor (`m+`) |
| `SUPER + 1–0` | Focus Workspace | Switches to workspace 1–10 |
| `SUPER + SHIFT + 1–0` | Move to Workspace | Moves active window to workspace 1–10 |
| `SUPER + Mouse Wheel Down` | Zoom Out | Decreases cursor zoom factor (min 1.0) |
| `SUPER + Mouse Wheel Up` | Zoom In | Increases cursor zoom factor (max 1.5) |
| `SUPER + Numpad -` | Zoom Out | Decreases cursor zoom factor by 0.3 |
| `SUPER + Numpad +` | Zoom In | Increases cursor zoom factor by 0.3 |
| `SUPER + Left Click` | Drag Window | Moves/drags the window with the mouse |
| `SUPER + Right Click` | Resize Window | Resizes the window with the mouse |

### Repository map

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

### Documentation

| Guide | English | Português (Brasil) |
|---|---|---|
| Installation and recovery | [Installation](docs/installation.md) | [Instalação](docs/instalacao.md) |
| Configuration and hardware notes | [Configuration](docs/config.md) | [Configuração](docs/configuracao.md) |
| Package rationale | [Dependencies](docs/dependencies.md) | [Dependências](docs/dependencias.md) |
| Common issues | [Troubleshooting](docs/troubleshooting.md) | [Solução de problemas](docs/problemas-conhecidos.md) |
| Contributing | [Contributing](CONTRIBUTING.en.md) | [Contribuindo](CONTRIBUTING.md) |

> [!NOTE] 
> The installer and configuration files are provided as-is. Read the [third-party notices](THIRD-PARTY-CREDITS.md) before redistributing included components.