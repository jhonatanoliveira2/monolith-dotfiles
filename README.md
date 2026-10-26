<h1 align="center">
  <strong>monolith-dotfiles.</strong>
</h1>

<p align="center">
  <img alt="Arch Linux" src="https://img.shields.io/badge/Arch_Linux-1793d1?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland_0.55+-00d9f5?style=for-the-badge&logo=hyprland&logoColor=black">
  <img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-QML-41cd52?style=for-the-badge&logo=qt&logoColor=white">
  <img alt="Lua" src="https://img.shields.io/badge/Config-Lua-2c2d72?style=for-the-badge&logo=lua&logoColor=white">
  <img alt="MIT" src="https://img.shields.io/badge/License-MIT-8b9099?style=for-the-badge">
</p>

<p align="center">
  <a href="README.pt-br.md">🇧🇷 Português (Brasil)</a> &nbsp;·&nbsp; <strong>🇺🇸 English</strong>
</p>

<p align="center">
  <em>A monochrome, Hyprland desktop — compositor, shell, terminal and tools in one repository.</em>
</p>

<p align="center">
  <a href="#screenshots">Screenshots</a> &nbsp;•&nbsp;
  <a href="#highlights">Highlights</a> &nbsp;•&nbsp;
  <a href="#quick-start">Install</a> &nbsp;•&nbsp;
  <a href="#keybinds">Keybinds</a> &nbsp;•&nbsp;
  <a href="#documentation">Docs</a>
</p>

---

https://github.com/user-attachments/assets/3df9da29-d3b5-43b1-9512-f72b0a0250b3

<p align="center"><a href="https://youtu.be/W_SYo-i9fXk">▶ Watch the full tour on YouTube</a></p>

## Screenshots

<p align="center">
  <img src="assets/screenshots/1.png" alt="MONOLITH desktop with the Quickshell bar" width="100%">
</p>
<table>
  <tr>
    <td width="50%"><img src="assets/screenshots/2.png" alt="Menus and settings" width="100%"></td>
    <td width="50%"><img src="assets/screenshots/3.png" alt="Terminal and tools" width="100%"></td>
  </tr>
</table>

## Highlights

- **Native Quickshell bar** — workspaces, MPRIS player with hover miniplayer, system monitor, network, Bluetooth, audio, brightness, battery and notifications, all without polling scripts.
- **Monolith Settings app** — searchable pages for display (drag-and-drop monitor layout with snapping and auto-revert), audio, network, Bluetooth, power, storage cleanup, input and updates. Changes apply live through the Hyprland Lua API.
- **Media menu** — cover crossfade, seekable progress, volume, player switcher and a searchable history of recently played tracks that plays again with one click.
- **Hyprland in Lua** — modular `hyprland.lua` with separate files for keybindings, layout, rules and autostart.
- **Safe installer** — dependency checks, automatic backups, rollback on failure and a dry-run restore.
- **Bilingual** — shell strings and documentation in English and Brazilian Portuguese.

## What's inside

| Layer | Included setup |
|---|---|
| 🪟 Window manager | Hyprland, configured in Lua with modular settings |
| 🧩 Desktop shell | Quickshell bar, menus, notifications, OSD and Settings app |
| 💻 Terminal and shell | Ghostty, Fish, Starship and Atuin |
| 🚀 Launching and files | Rofi, Nautilus and a wallpaper selector |
| 🛠️ Personal tools | Neovim, Micro and btop settings |
| 🎨 Appearance | GTK settings, wallpaper-derived palettes and cursor shaders |

## Quick start

> [!CAUTION]
> Some options are hardware-specific (monitors, input, language). Review [`docs/config.md`](docs/config.md) before installing.

**Requirements:** Arch Linux · Bash 4.4+ · Git · a regular user account · Hyprland 0.55 or newer. An AUR helper (**paru** or **yay**) is only needed if you want the installer to build AUR packages.

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles
./scripts/install.sh
```

> [!TIP]
> The installer copies `configs/` into your home directory, installs packages (skip with `--no-deps`) and places the bundled wallpapers in `~/Pictures/Wallpapers` and `~/Videos/wallpaper-live`.

<details>
  <summary><strong>Backup and recovery</strong></summary>

  ```bash
  ./scripts/backup.sh --list
  ./scripts/restore.sh
  ./scripts/restore.sh --dry-run
  ```

  Backups are stored under `~/.local/share/monolith-dotfiles/backups/`. See the [installation guide](docs/installation.md#backup-and-recovery) to restore a specific snapshot or recover files manually.
</details>

<details>
  <summary><strong>Installer preview</strong></summary>
  <p align="center"><img src="assets/previews/installer-welcome.svg" alt="MONOLITH installer welcome and setup steps" width="760"></p>
  <p align="center"><img src="assets/previews/installer-run.svg" alt="MONOLITH installer progress and completion screen" width="760"></p>
</details>

## Keybinds

`SUPER` is the main modifier. Media keys (volume, brightness, player) are handled natively by the shell with an on-screen display.

<details open>
  <summary><strong>Apps and shell</strong></summary>

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Return` | Terminal | Opens the terminal (`programs.terminal`) |
| `SUPER + X` | File Manager | Opens the file manager (`programs.fileManager`) |
| `SUPER + C` | Code | Opens VS Code / Cursor |
| `SUPER + TAB` | Browser | Opens Zen Browser |
| `SUPER + Z` | Lock | Locks the session with `hyprlock` |
| `SUPER + A` | App Launcher | Toggles Rofi launcher (`~/.config/hypr/rofi/launcher.sh`) |
| `SUPER + D` | Wallpaper Menu | Opens wallpaper selector (`~/.local/bin/wallpaper-menu`) |
| `SUPER + SHIFT + X` | Exit Session | Runs `hyprshutdown` if available, otherwise exits Hyprland |
| `SUPER + N` | Notifications | Opens the notification center |
| `SUPER + M` | Media | Opens the media player (cover, seek, volume, search) |
| `SUPER + ,` | Settings | Opens the Monolith Settings app |
| `SUPER + Escape` | Session | Opens the system / session menu |
| Media keys | Volume / Brightness / Player | Handled natively by the shell with an on-screen display (CLI fallback when the shell is not running) |
</details>

<details>
  <summary><strong>Windows</strong></summary>

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Space` | Toggle Float + Center | Toggles floating mode and centers the window (70% of monitor size) |
| `SUPER + S` | Toggle Float | Toggles floating mode without centering |
| `SUPER + Q` | Close Window | Closes the active window |
| `SUPER + F` | Fullscreen | Toggles fullscreen mode |
| `SUPER + SHIFT + ←/→/↑/↓` | Move Window | Moves the active window in the given direction (group-aware) |
| `SUPER + ←/→/↑/↓` | Focus Window | Moves focus in the given direction |
| `SUPER + ALT + ←/→/↑/↓` | Resize Window | Resizes the active window (40px steps, repeating) |
| `SUPER + Left Click` | Drag Window | Moves/drags the window with the mouse |
| `SUPER + Right Click` | Resize Window | Resizes the window with the mouse |
| `SUPER + J` | Toggle Split | Toggles the dwindle split direction |
| `SUPER + G` | Group | Toggles a window group (tabs) |
| `SUPER + grave` | Urgent / Last | Focuses the urgent window, or the previous one |
| `SUPER + CTRL + H/J/K/L` | Swap Window | Swaps the active window with its neighbour |
</details>

<details>
  <summary><strong>Workspaces and monitors</strong></summary>

| Keybind | Action | Description |
|---|---|---|
| `SUPER + W` | Special Workspace | Toggles the special workspace `"magic"` |
| `SUPER + SHIFT + W` | Move to Special | Moves active window to the special workspace |
| `SUPER + ALT + W` | Move to Next Monitor | Moves active window to the next monitor (`m+`) |
| `SUPER + 1–0` | Focus Workspace | Switches to workspace 1–10 |
| `SUPER + SHIFT + 1–0` | Move to Workspace | Moves active window to workspace 1–10 |
| `SUPER + P` | Pin | Pins the active (floating) window on every workspace |
| `SUPER + CTRL + ←/→` | Previous / Next Workspace | Cycles through occupied workspaces |
</details>

<details>
  <summary><strong>Capture and zoom</strong></summary>

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Delete` | Screenshot (Full) | Captures the focused monitor, saves to `~/Pictures` and copies to clipboard |
| `SUPER + SHIFT + Delete` | Screenshot (Area) | Captures selected area with `slurp` + `grim`, saves and copies to clipboard |
| `SUPER + R` | Screen Recording | Toggles GPU Screen Recorder (`toggle-gsr.sh`) saves to `~/Videos` |
| `SUPER + Mouse Wheel Down` | Zoom Out | Decreases cursor zoom factor (min 1.0) |
| `SUPER + Mouse Wheel Up` | Zoom In | Increases cursor zoom factor (max 1.5) |
| `SUPER + Numpad -` | Zoom Out | Decreases cursor zoom factor by 0.3 |
| `SUPER + Numpad +` | Zoom In | Increases cursor zoom factor by 0.3 |
</details>

## Repository map

```text
configs/                 Desktop configuration payload copied into your home
scripts/                 Installer, backup, restore, checks and import utility
docs/                    Paired English and Brazilian Portuguese guides
assets/                  Brand artwork, installer previews and screenshots
wallpapers/              Bundled static and live wallpapers
tests/                   Installer and documentation checks
tools/                   Utility for rendering terminal previews
packages.txt             Required, optional and AUR package manifest
LICENSE                  MIT
```

## Documentation

| Guide | English | Português (Brasil) |
|---|---|---|
| Installation and recovery | [Installation](docs/installation.md) | [Instalação](docs/instalacao.md) |
| Configuration and hardware notes | [Configuration](docs/config.md) | [Configuração](docs/configuracao.md) |
| Package rationale | [Dependencies](docs/dependencies.md) | [Dependências](docs/dependencias.md) |
| Common issues | [Troubleshooting](docs/troubleshooting.md) | [Solução de problemas](docs/problemas-conhecidos.md) |
| Contributing | [Contributing](CONTRIBUTING.en.md) | [Contribuindo](CONTRIBUTING.md) |

> [!NOTE]
> The installer and configuration files are provided as-is. Read the [third-party notices](THIRD-PARTY-CREDITS.md) before redistributing included components.

---

<p align="center">
  Made with ☕ on Arch Linux · <a href="LICENSE">MIT License</a>
</p>