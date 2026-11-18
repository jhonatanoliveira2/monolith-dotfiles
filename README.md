<h1 align="center">MONOLITH</h1>

<p align="center">
  <em>A monochrome Hyprland desktop: compositor, shell, terminal and tools in one repository.</em>
</p>

<p align="center">
  <img alt="Arch Linux" src="https://img.shields.io/badge/Arch_Linux-111111?style=flat-square&logo=archlinux&logoColor=white">
  <img alt="CachyOS" src="https://img.shields.io/badge/CachyOS-111111?style=flat-square&logo=archlinux&logoColor=white">
  <img alt="NixOS" src="https://img.shields.io/badge/NixOS-111111?style=flat-square&logo=nixos&logoColor=white">
  <img alt="Hyprland 0.55+" src="https://img.shields.io/badge/Hyprland-0.55+-111111?style=flat-square&logo=hyprland&logoColor=white">
  <img alt="MIT" src="https://img.shields.io/badge/license-MIT-111111?style=flat-square">
</p>

<p align="center">
  <a href="README.pt-br.md">Português (Brasil)</a> &nbsp;·&nbsp; <strong>English</strong>
</p>

## Install

**Arch Linux / CachyOS**

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles && ./scripts/install.sh
```

Your files are backed up first; `./scripts/restore.sh` undoes it. [Installation guide](docs/installation.md)

**NixOS**, from the installer ISO:

```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:jhonatanoliveira2/monolith-dotfiles#install
```

[NixOS guide](docs/nixos.md)

Both installers ask for the theme: **default** or **Nothing** (LEDs and dot matrix). Installed from an old branch?
[Updating from an old branch](docs/migrating.md).

## Keybinds

`SUPER` is the main modifier. Every combo can be changed in Settings > Input ([Keybinds](docs/keybinds.md)).

<details>
<summary>Show all the keybinds</summary>
<br>

**Apps and shell**

| Keybind | Action |
|---|---|
| `SUPER + Return` | Terminal (Ghostty) |
| `SUPER + X` | File manager |
| `SUPER + C` | Code editor (VS Code / Cursor) |
| `SUPER + TAB` | Browser |
| `SUPER + A` | App launcher (rofi without the shell) |
| `SUPER + D` | Wallpaper picker (`wallpaper-menu` without the shell) |
| `SUPER + N` | Notification centre |
| `SUPER + M` | Media player |
| `SUPER + ,` | Settings |
| `SUPER + Escape` | Quick menu (system and session) |
| `SUPER + B` | Arrange the desktop widgets |

**Capture**

| Keybind | Action |
|---|---|
| `SUPER + Delete` | Screenshot of the focused monitor (saved to `~/Pictures` and copied) |
| `SUPER + SHIFT + Delete` | Screenshot of an area |
| `SUPER + R` | Start / stop a screen recording (`~/Videos`) |

**Session**

| Keybind | Action |
|---|---|
| `SUPER + Z` | Lock (hyprlock) |
| `SUPER + SHIFT + X` | Exit the session |

**Windows**

| Keybind | Action |
|---|---|
| `SUPER + Q` | Close |
| `SUPER + Space` | Float and centre (70 % of the monitor) |
| `SUPER + S` | Float, without centring |
| `SUPER + F` | Fullscreen |
| `SUPER + P` | Pin on every workspace |
| `SUPER + J` | Toggle the split direction |
| `SUPER + G` | Group (tabs) |
| `SUPER + Left click` | Drag |
| `SUPER + Right click` | Resize with the mouse |
| `SUPER + ←/→/↑/↓` | Focus |
| `SUPER + grave` | Urgent or previous window |
| `SUPER + SHIFT + ←/→/↑/↓` | Move |
| `SUPER + CTRL + H/J/K/L` | Swap with the neighbour |
| `SUPER + ALT + ←/→/↑/↓` | Resize |

**Workspaces and monitors**

| Keybind | Action |
|---|---|
| `SUPER + 1…0` | Go to workspace 1–10 |
| `SUPER + SHIFT + 1…0` | Move the window to workspace 1–10 |
| `SUPER + CTRL + ←/→` | Previous / next occupied workspace |
| `SUPER + W` | Special workspace |
| `SUPER + SHIFT + W` | Move the window to the special workspace |
| `SUPER + ALT + W` | Move the window to the next monitor |

**Zoom**

| Keybind | Action |
|---|---|
| `SUPER + wheel up` / `SUPER + Numpad +` | Zoom in |
| `SUPER + wheel down` / `SUPER + Numpad -` | Zoom out |

**Media and hardware keys**

| Key | Action |
|---|---|
| Volume up / down, mute | Output volume (with the on-screen display) |
| Microphone mute | Microphone |
| Brightness up / down | Screen brightness |
| Keyboard backlight up / down / on-off | Keyboard backlight |
| Play, pause, next, previous | Media player |
| Touchpad toggle | Turn the touchpad on / off |

</details>

## Docs

[Installation](docs/installation.md) · [NixOS](docs/nixos.md) · [Nothing theme](docs/nothing-theme.md) ·
[Keybinds](docs/keybinds.md) · [Configuration](docs/config.md) · [Dependencies](docs/dependencies.md) ·
[Troubleshooting](docs/troubleshooting.md) · [Updating from an old branch](docs/migrating.md) ·
[Contributing](CONTRIBUTING.en.md)

<p align="center">
  <sub> <a href="LICENSE">MIT</a> · <a href="THIRD-PARTY-CREDITS.md">third-party credits</a> </sub>
</p>
