<p align="center">
  <img src="assets/previews/logo.svg" alt="MONOLITH" width="560">
</p>

<p align="center">
  <em>Um desktop Hyprland monocromático: compositor, shell, terminal e ferramentas em um só repositório.</em>
</p>

<p align="center">
  <img alt="Arch Linux" src="https://img.shields.io/badge/Arch_Linux-111111?style=flat-square&logo=archlinux&logoColor=white">
  <img alt="CachyOS" src="https://img.shields.io/badge/CachyOS-111111?style=flat-square&logo=archlinux&logoColor=white">
  <img alt="NixOS" src="https://img.shields.io/badge/NixOS-111111?style=flat-square&logo=nixos&logoColor=white">
  <img alt="Hyprland 0.55+" src="https://img.shields.io/badge/Hyprland-0.55+-111111?style=flat-square&logo=hyprland&logoColor=white">
  <img alt="MIT" src="https://img.shields.io/badge/licen%C3%A7a-MIT-111111?style=flat-square">
</p>

<p align="center">
  <strong>Português (Brasil)</strong> &nbsp;·&nbsp; <a href="README.md">English</a>
</p>

## Instalação

**Arch Linux / CachyOS**

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles && ./scripts/install.sh
```

Seus arquivos passam por backup antes; `./scripts/restore.sh` desfaz. [Guia de instalação](docs/instalacao.md)

**NixOS**, pela ISO de instalação:

```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:jhonatanoliveira2/monolith-dotfiles#install
```

[Guia do NixOS](docs/nixos.pt-br.md)

Os dois instaladores perguntam o tema: **padrão** ou **Nothing** (LEDs e matriz de pontos). Instalou a partir de uma
branch antiga? [Atualizar a partir de uma branch antiga](docs/migracao.md).

## Prévia

### Tema padrão

<table>
  <tr>
    <td colspan="2"><img src="assets/previews/default/nautilus.svg" alt="Nautilus no tema padrão: vidro escuro sobre o wallpaper, Monolith-Icons em cinza"></td>
  </tr>
  <tr>
    <td width="50%"><img src="assets/previews/default/fastfetch.svg" alt="fastfetch no NixOS, tema padrão"></td>
    <td width="50%"><img src="assets/previews/default/installer-nixos.svg" alt="Instalador do NixOS, visual padrão"></td>
  </tr>
  <tr>
    <td colspan="2"><img src="assets/previews/default/installer.svg" alt="Instalador do Arch: boas-vindas e escolha do tema"></td>
  </tr>
</table>

### Tema Nothing (opcional)

LEDs e matriz de pontos, desligado a menos que você o escolha no instalador ou o ligue depois
([Tema Nothing](docs/nothing-theme.pt-br.md)).

<details>
<summary>Mostrar as prévias do tema Nothing</summary>
<br>

<table>
  <tr>
    <td colspan="2"><img src="assets/previews/nothing/wallpaper.svg" alt="Um wallpaper como é e em matriz de LEDs"></td>
  </tr>
  <tr>
    <td colspan="2"><img src="assets/previews/nothing/fastfetch.svg" alt="fastfetch no NixOS, tema Nothing: o floco de neve em LEDs"></td>
  </tr>
  <tr>
    <td colspan="2"><img src="assets/previews/nothing/nautilus.svg" alt="Nautilus no tema Nothing: preto OLED a 85 %, ícones e cursor MONOLITH Dots"></td>
  </tr>
  <tr>
    <td width="50%"><img src="assets/previews/nothing/cava.svg" alt="monolith-cava"></td>
    <td width="50%"><img src="assets/previews/nothing/installer-nixos.svg" alt="Instalador do NixOS, visual Nothing"></td>
  </tr>
</table>

</details>

## Documentação

[Instalação](docs/instalacao.md) · [NixOS](docs/nixos.pt-br.md) · [Tema Nothing](docs/nothing-theme.pt-br.md) ·
[Atalhos](docs/atalhos.md) · [Configuração](docs/configuracao.md) · [Dependências](docs/dependencias.md) ·
[Problemas conhecidos](docs/problemas-conhecidos.md) · [Atualizar a partir de uma branch antiga](docs/migracao.md) ·
[Contribuindo](CONTRIBUTING.md)

<p align="center">
  <sub><a href="LICENSE">MIT</a> · <a href="THIRD-PARTY-CREDITS.md">créditos de terceiros</a> · o tema Nothing não tem vínculo com a Nothing Technology Limited</sub>
</p>
