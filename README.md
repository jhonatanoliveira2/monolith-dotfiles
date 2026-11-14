<p align="center">
  <img src="assets/previews/logo.svg" alt="MONOLITH" width="560">
</p>

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

## Preview

### Default theme

<table>
  <tr>
    <td colspan="2"><img src="assets/previews/default/nautilus.svg" alt="Nautilus in the default theme: dark glass over the wallpaper, grey Monolith-Icons"></td>
  </tr>
  <tr>
    <td width="50%"><img src="assets/previews/default/fastfetch.svg" alt="fastfetch on NixOS, default theme"></td>
    <td width="50%"><img src="assets/previews/default/installer-nixos.svg" alt="NixOS installer, default look"></td>
  </tr>
  <tr>
    <td colspan="2"><img src="assets/previews/default/installer.svg" alt="Arch installer: welcome and theme choice"></td>
  </tr>
</table>

### Nothing theme (optional)

LEDs and dot matrix, off unless you pick it in the installer or turn it on later
([Nothing theme](docs/nothing-theme.md)).

<details>
<summary>Show the Nothing theme previews</summary>
<br>

<table>
  <tr>
    <td colspan="2"><img src="assets/previews/nothing/wallpaper.svg" alt="A wallpaper as it is and as an LED dot matrix"></td>
  </tr>
  <tr>
    <td colspan="2"><img src="assets/previews/nothing/fastfetch.svg" alt="fastfetch on NixOS, Nothing theme: the snowflake as LEDs"></td>
  </tr>
  <tr>
    <td colspan="2"><img src="assets/previews/nothing/nautilus.svg" alt="Nautilus in the Nothing theme: OLED black at 85 %, MONOLITH Dots icons and cursor"></td>
  </tr>
  <tr>
    <td width="50%"><img src="assets/previews/nothing/cava.svg" alt="monolith-cava"></td>
    <td width="50%"><img src="assets/previews/nothing/installer-nixos.svg" alt="NixOS installer, Nothing look"></td>
  </tr>
</table>

</details>

## Docs

[Installation](docs/installation.md) · [NixOS](docs/nixos.md) · [Nothing theme](docs/nothing-theme.md) ·
[Keybinds](docs/keybinds.md) · [Configuration](docs/config.md) · [Dependencies](docs/dependencies.md) ·
[Troubleshooting](docs/troubleshooting.md) · [Updating from an old branch](docs/migrating.md) ·
[Contributing](CONTRIBUTING.en.md)

<p align="center">
  <sub><a href="LICENSE">MIT</a> · <a href="THIRD-PARTY-CREDITS.md">third-party credits</a> · the Nothing theme is not affiliated with Nothing Technology Limited</sub>
</p>
