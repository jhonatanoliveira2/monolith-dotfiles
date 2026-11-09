<h1 align="center">
  <strong>monolith-dotfiles.</strong>
</h1>

<p align="center">
  <img alt="NixOS" src="https://img.shields.io/badge/NixOS-5277c3?style=for-the-badge&logo=nixos&logoColor=white">
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland_0.55+-00d9f5?style=for-the-badge&logo=hyprland&logoColor=black">
  <img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-QML-41cd52?style=for-the-badge&logo=qt&logoColor=white">
  <img alt="MIT" src="https://img.shields.io/badge/License-MIT-8b9099?style=for-the-badge">
</p>

<p align="center">
  <a href="README.pt-br.md">🇧🇷 Português (Brasil)</a> &nbsp;·&nbsp; <strong>🇺🇸 English</strong>
</p>

<p align="center">
  <em>A monochrome Hyprland desktop for NixOS — compositor, shell, boot and tools in one flake.</em>
</p>

<p align="center">
  <a href="#highlights">Highlights</a> &nbsp;•&nbsp;
  <a href="#install">Install</a> &nbsp;•&nbsp;
  <a href="#keybinds">Keybinds</a> &nbsp;•&nbsp;
  <a href="#documentation">Docs</a>
</p>

---

> [!IMPORTANT]
> **Branch `feature/nothing-theme` — NixOS only.** The Arch Linux / CachyOS version (shell installer, `packages.txt`) lives
> on [`main`](https://github.com/jhonatanoliveira2/monolith-dotfiles/tree/main); the plain NixOS version on
> [`feature/nixos-support`](https://github.com/jhonatanoliveira2/monolith-dotfiles/tree/feature/nixos-support).
> This branch adds the **Nothing theme** (dot matrix / LEDs), on by default. This project is not affiliated with
> Nothing Technology Limited.

## Highlights

- **Native Quickshell bar** — workspaces, MPRIS player with hover miniplayer, system monitor, network, Bluetooth, audio, brightness, battery and notifications, all without polling scripts.
- **Monolith Settings app** — searchable pages for display (drag-and-drop monitor layout with snapping and auto-revert), audio, network, Bluetooth, power, storage cleanup, input and updates. Changes apply live through the Hyprland Lua API.
- **Media menu** — cover crossfade, seekable progress, volume, player switcher and a searchable history of recently played tracks that plays again with one click.
- **Hyprland in Lua** — modular `hyprland.lua` with separate files for keybindings, layout, rules and autostart.
- **Declarative install** — a Nix flake: NixOS + Home Manager modules, a guided installer for the NixOS ISO and pinned versions.
- **Nothing theme** — greys, Doto / Space Grotesk / Space Mono, LED meters, an edge glow on notifications and still wallpapers rendered as LED matrices per monitor (`monolith-dotmatrix`).
- **Boot to desktop** — GRUB theme, Plymouth splash and a Quickshell greeter with the same look.
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

## Install

From the NixOS installer ISO (the minimal one is enough), connected to the network:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:jhonatanoliveira2/monolith-dotfiles/feature/nothing-theme#install
```

The guided installer asks for the disk, user, hostname, locale, keyboard, LUKS and swap, shows a summary and only
erases the disk after its name is typed back. On an installed NixOS, or in an existing flake, see
[docs/nixos.md](docs/nixos.md#installing). Updates: Settings > Update, or
`sudo nix flake update monolith --flake /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos`.

## Keybinds

`SUPER` is the main modifier. Media keys (volume, brightness, player) are handled natively by the shell with an on-screen display.

<details open>
  <summary><strong>Apps and shell</strong></summary>

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Return` | Terminal | Opens the terminal (`programs.terminal`) |
| `SUPER + X` | File Manager | Opens the file manager (`programs.fileManager`) |
| `SUPER + C` | Code | Opens VS Code / Cursor |
| `SUPER + TAB` | Browser | Opens the browser (`programs.monolith.apps.browser`, Firefox by default) |
| `SUPER + Z` | Lock | Locks the session with `hyprlock` |
| `SUPER + A` | App Launcher | Toggles Rofi launcher (`~/.config/hypr/rofi/launcher.sh`) |
| `SUPER + D` | Wallpaper Menu | Opens wallpaper selector (`~/.local/bin/wallpaper-menu`) |
| `SUPER + SHIFT + X` | Exit Session | Runs `hyprshutdown` if available, otherwise exits Hyprland |
| `SUPER + N` | Notifications | Opens the notification center |
| `SUPER + M` | Media | Opens the media player (cover, seek, volume, search) |
| `SUPER + ,` | Settings | Opens the Monolith Settings app |
| `SUPER + Escape` | Session | Opens the system / session menu |
| `SUPER + B` | Widgets | Arranges the desktop widgets (add, move, resize, remove) |
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
| Touchpad: 4-finger swipe | Move Window | Carries the window under the pointer, in any direction (no key, no click) |
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
flake.nix, flake.lock    the flake (packages, NixOS / Home Manager modules, installer, template)
nix/                     modules, packages, guided installer, checks
configs/                 desktop configuration linked into your home by Home Manager
branding/                GRUB theme, Plymouth splash and boot artwork sources
greeter/                 Quickshell greeter for greetd
templates/nixos/         starting configuration (nix flake init -t)
wallpapers/              bundled wallpapers
docs/                    English and Brazilian Portuguese guides
tests/                   installer and documentation checks
```

## Documentation

| Guide | English | Português (Brasil) |
|---|---|---|
| Install, options, boot and login | [NixOS](docs/nixos.md) | [NixOS](docs/nixos.pt-br.md) |
| Nothing theme, wallpapers, switching branches | [Nothing theme](docs/nothing-theme.md) | [Tema Nothing](docs/nothing-theme.pt-br.md) |
| Contributing | [Contributing](CONTRIBUTING.en.md) | [Contribuindo](CONTRIBUTING.md) |

> [!NOTE]
> Provided as-is. Read the [third-party notices](THIRD-PARTY-CREDITS.md) before redistributing included components.

---

<p align="center">
  Made with ☕ on NixOS · <a href="LICENSE">MIT License</a>
</p>
