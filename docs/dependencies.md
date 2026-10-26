# Dependencies and packages

[Português (Brasil)](dependencias.md) · **English**

The package list in [`../packages.txt`](../packages.txt) is the source used by the installer. This guide summarises the criteria and explains the categories.

## How the categories work

- **Required**: used by a shortcut, service started by the configuration, active Quickshell component or included script.
- **Optional**: needed only for applications or features that are not started automatically, or for specific hardware.
- **AUR**: some packages may be available in the official repositories. The installer checks with `pacman` before calling an AUR helper.
- **Manual**: items not installed through `pacman` or the AUR. The current manifest has no entries in this category.

The installer does not run `pacman -Sy`. If a package cannot be found, update the system with `sudo pacman -Syu` and try again.

## Official repositories — required

| Package | Main use |
|---|---|
| `hyprland`, `hyprlock`, `hypridle`, `xdg-desktop-portal-hyprland` | Compositor, lock screen, idle handling and screen sharing |
| `quickshell`, `upower` | Desktop shell bar, menus and battery status |
| `lxqt-policykit`, `qt6ct`, `dconf`, `materia-gtk-theme` | Graphical authorization and appearance settings |
| `git`, `base-devel` | Setup dependencies and building packages when needed |
| `rofi` | Application launcher and wallpaper menu; requires Wayland support |
| `ghostty`, `fish`, `starship`, `atuin` | Terminal and shell environment |
| `nautilus` | File manager launched by a shortcut |
| `ttf-jetbrains-mono-nerd` | Desktop typography |
| `grim`, `slurp`, `wl-clipboard`, `libnotify`, `jq` | Screenshots, area selection, clipboard, notifications and data parsing |
| `ffmpeg` | Wallpaper-menu previews |
| `pipewire`, `pipewire-pulse`, `wireplumber`, `playerctl` | Audio and media controls |
| `brightnessctl` | Brightness controls |
| `networkmanager`, `network-manager-applet`, `blueman`, `bluez-utils`, `curl` | Network (iwd and systemd-networkd also work), Bluetooth (bluetoothctl is the pairing agent) and connectivity checks |
| `udisks2`, `pciutils`, `pacman-contrib` | Disk health, GPU name and pacman cache cleanup (Settings app) |

## Official repositories — optional

| Package | Needed when |
|---|---|
| `fastfetch`, `btop`, `micro` | You use these manually launched configured applications |
| `neovim`, `gcc`, `tree-sitter-cli`, `ripgrep`, `fd` | You use Neovim/LazyVim and its search or parser-building features |
| `nwg-look` | You want to adjust GTK themes through a graphical interface |
| `pavucontrol` | You open the audio mixer from a Quickshell menu |
| `power-profiles-daemon` | You use power-profile controls on supported hardware |
| `xorg-xwayland` | You run X11 applications |

## AUR

| Package | Category | Use |
|---|---|---|
| `awww`, `mpvpaper`, `wpgtk` | Required in the manifest | Wallpapers, colour integration and themes |
| `ttf-material-icons-git` | Required in the manifest | Quickshell icons |
| `zen-browser-bin`, `gpu-screen-recorder` | Optional | Shortcut browser and screen recording |

The manifest is the final reference for each package category and may change as the project evolves.

## Check your system

```bash
./scripts/check-dependencies.sh
./scripts/check-dependencies.sh --list-missing=required
./scripts/check-dependencies.sh --strict
```

The first command prints the full report. The second lists missing required packages. `--strict` returns a non-zero status when a required dependency is missing. The check also reports files used by the configuration that are not available.
