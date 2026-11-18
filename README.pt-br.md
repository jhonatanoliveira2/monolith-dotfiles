<h1 align="center">MONOLITH</h1>

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

## Atalhos

`SUPER` é o modificador principal. Toda combinação pode ser trocada em Configurações > Entrada ([Atalhos](docs/atalhos.md)).

<details>
<summary>Mostrar todos os atalhos</summary>
<br>

**Apps e shell**

| Atalho | Ação |
|---|---|
| `SUPER + Return` | Terminal (Ghostty) |
| `SUPER + X` | Gerenciador de arquivos |
| `SUPER + C` | Editor de código (VS Code / Cursor) |
| `SUPER + TAB` | Navegador |
| `SUPER + A` | Lançador de apps (rofi sem o shell) |
| `SUPER + D` | Seletor de wallpaper (`wallpaper-menu` sem o shell) |
| `SUPER + N` | Central de notificações |
| `SUPER + M` | Player de mídia |
| `SUPER + ,` | Configurações |
| `SUPER + Escape` | Menu rápido (sistema e sessão) |
| `SUPER + B` | Organizar os widgets da área de trabalho |

**Captura**

| Atalho | Ação |
|---|---|
| `SUPER + Delete` | Captura do monitor em foco (salva em `~/Pictures` e copiada) |
| `SUPER + SHIFT + Delete` | Captura de uma área |
| `SUPER + R` | Iniciar / parar a gravação da tela (`~/Videos`) |

**Sessão**

| Atalho | Ação |
|---|---|
| `SUPER + Z` | Bloquear (hyprlock) |
| `SUPER + SHIFT + X` | Sair da sessão |

**Janelas**

| Atalho | Ação |
|---|---|
| `SUPER + Q` | Fechar |
| `SUPER + Space` | Flutuar e centralizar (70 % do monitor) |
| `SUPER + S` | Flutuar, sem centralizar |
| `SUPER + F` | Tela cheia |
| `SUPER + P` | Fixar em todos os workspaces |
| `SUPER + J` | Alternar a direção da divisão |
| `SUPER + G` | Grupo (abas) |
| `SUPER + clique esquerdo` | Arrastar |
| `SUPER + clique direito` | Redimensionar com o mouse |
| `SUPER + ←/→/↑/↓` | Foco |
| `SUPER + grave` | Janela urgente ou anterior |
| `SUPER + SHIFT + ←/→/↑/↓` | Mover |
| `SUPER + CTRL + H/J/K/L` | Trocar com a vizinha |
| `SUPER + ALT + ←/→/↑/↓` | Redimensionar |

**Workspaces e monitores**

| Atalho | Ação |
|---|---|
| `SUPER + 1…0` | Ir para o workspace 1–10 |
| `SUPER + SHIFT + 1…0` | Mover a janela para o workspace 1–10 |
| `SUPER + CTRL + ←/→` | Workspace ocupado anterior / seguinte |
| `SUPER + W` | Workspace especial |
| `SUPER + SHIFT + W` | Mover a janela para o workspace especial |
| `SUPER + ALT + W` | Mover a janela para o próximo monitor |

**Zoom**

| Atalho | Ação |
|---|---|
| `SUPER + roda para cima` / `SUPER + Numpad +` | Aproximar |
| `SUPER + roda para baixo` / `SUPER + Numpad -` | Afastar |

**Teclas de mídia e de hardware**

| Tecla | Ação |
|---|---|
| Volume +/-, mudo | Volume da saída (com o indicador na tela) |
| Mudo do microfone | Microfone |
| Brilho +/- | Brilho da tela |
| Luz do teclado +/- / liga-desliga | Luz do teclado |
| Tocar, pausar, próxima, anterior | Player de mídia |
| Liga-desliga do touchpad | Ligar / desligar o touchpad |

</details>

## Documentação

[Instalação](docs/instalacao.md) · [NixOS](docs/nixos.pt-br.md) · [Tema Nothing](docs/nothing-theme.pt-br.md) ·
[Atalhos](docs/atalhos.md) · [Configuração](docs/configuracao.md) · [Dependências](docs/dependencias.md) ·
[Problemas conhecidos](docs/problemas-conhecidos.md) · [Atualizar a partir de uma branch antiga](docs/migracao.md) ·
[Contribuindo](CONTRIBUTING.md)

<p align="center">
  <sub> <a href="LICENSE">MIT</a> · <a href="THIRD-PARTY-CREDITS.md">créditos de terceiros</a> </sub>
</p>
