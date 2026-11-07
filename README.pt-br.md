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
  <strong>🇧🇷 Português (Brasil)</strong> &nbsp;·&nbsp; <a href="README.md">🇺🇸 English</a>
</p>

<p align="center">
  <em>Um desktop Hyprland monocromático para NixOS — compositor, shell, boot e ferramentas em um flake.</em>
</p>

<p align="center">
  <a href="#destaques">Destaques</a> &nbsp;•&nbsp;
  <a href="#instalação">Instalação</a> &nbsp;•&nbsp;
  <a href="#atalhos">Atalhos</a> &nbsp;•&nbsp;
  <a href="#documentação">Documentação</a>
</p>

---

> [!IMPORTANT]
> **Branch `feature/nothing-theme` — somente NixOS.** A versão para Arch Linux / CachyOS (instalador em shell,
> `packages.txt`) fica na [`main`](https://github.com/jhonatanoliveira2/monolith-dotfiles/tree/main); a versão NixOS sem o
> tema, na [`feature/nixos-support`](https://github.com/jhonatanoliveira2/monolith-dotfiles/tree/feature/nixos-support).
> Esta branch acrescenta o **tema Nothing** (matriz de pontos / LEDs), ativado por padrão. Este projeto não é
> afiliado à Nothing Technology Limited.

## Destaques

- **Barra nativa em Quickshell** — workspaces, player MPRIS com miniplayer ao passar o mouse, monitor do sistema, rede, Bluetooth, áudio, brilho, bateria e notificações, sem scripts de polling.
- **App de Configurações do Monolith** — páginas pesquisáveis de tela (arranjo dos monitores arrastando, com encaixe e reversão automática), áudio, rede, Bluetooth, energia, limpeza de armazenamento, entrada e atualização. As mudanças são aplicadas na hora pela API Lua do Hyprland.
- **Menu de mídia** — transição de capas, barra de progresso, volume, troca de player e histórico pesquisável das faixas tocadas recentemente, que voltam a tocar com um clique.
- **Hyprland em Lua** — `hyprland.lua` modular, com arquivos separados para atalhos, layout, regras e autostart.
- **Instalação declarativa** — um flake Nix: módulos NixOS + Home Manager, instalador guiado para a ISO do NixOS e versões fixadas.
- **Tema Nothing** — cinzas, Doto / Space Grotesk / Space Mono, medidores de LEDs, brilho de borda nas notificações e wallpapers estáticos convertidos em matriz de LEDs por monitor (`monolith-dotmatrix`).
- **Do boot à área de trabalho** — tema do GRUB, splash do Plymouth e um greeter em Quickshell com o mesmo visual.
- **Bilíngue** — textos do shell e documentação em português do Brasil e inglês.

## O que vem incluído

| Camada | O que está incluído |
|---|---|
| 🪟 Gerenciador de janelas | Hyprland, configurado em Lua e dividido em módulos |
| 🧩 Shell gráfico | Barra, menus, notificações, OSD e app de Configurações em Quickshell |
| 💻 Terminal e shell | Ghostty, Fish, Starship e Atuin |
| 🚀 Lançadores e arquivos | Rofi, Nautilus e seletor de wallpapers |
| 🛠️ Ferramentas pessoais | Configurações para Neovim, Micro e btop |
| 🎨 Aparência | Ajustes GTK, paletas derivadas de wallpapers e shaders de cursor |

## Instalação

Pela ISO de instalação do NixOS (a mínima basta), conectado à rede:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:jhonatanoliveira2/monolith-dotfiles/feature/nothing-theme#install
```

O instalador guiado pergunta o disco, usuário, hostname, idioma, teclado, LUKS e swap, mostra um resumo e só
apaga o disco depois que o nome dele é digitado de volta. Num NixOS já instalado, ou num flake existente, veja
[docs/nixos.pt-br.md](docs/nixos.pt-br.md#instalação). Atualizações: Configurações > Atualização, ou
`sudo nix flake update monolith --flake /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos`.

## Atalhos

`SUPER` é o modificador principal. As teclas de mídia (volume, brilho, player) são tratadas nativamente pelo shell, com indicador na tela.

<details open>
  <summary><strong>Apps e shell</strong></summary>

| Atalho | Ação | Descrição |
|---|---|---|
| `SUPER + Return` | Terminal | Abre o terminal (`programs.terminal`) |
| `SUPER + X` | Gerenciador de Arquivos | Abre o gerenciador de arquivos (`programs.fileManager`) |
| `SUPER + C` | Code | Abre o VS Code / Cursor |
| `SUPER + TAB` | Navegador | Abre o navegador (`programs.monolith.apps.browser`, Firefox por padrão) |
| `SUPER + Z` | Bloquear | Bloqueia a sessão com `hyprlock` |
| `SUPER + A` | Lançador de Apps | Alterna o Rofi (`~/.config/hypr/rofi/launcher.sh`) |
| `SUPER + D` | Menu de Wallpaper | Abre o seletor de wallpapers (`~/.local/bin/wallpaper-menu`) |
| `SUPER + SHIFT + X` | Sair da Sessão | Executa `hyprshutdown` se disponível, senão sai do Hyprland |
| `SUPER + N` | Notificações | Abre a central de notificações |
| `SUPER + M` | Mídia | Abre o player (capa, seek, volume, busca) |
| `SUPER + ,` | Configurações | Abre o app Monolith Settings |
| `SUPER + Escape` | Sessão | Abre o menu de sistema / sessão |
| `SUPER + B` | Widgets | Organiza os widgets da área de trabalho (adicionar, mover, redimensionar, remover) |
| Teclas de mídia | Volume / Brilho / Player | Tratadas nativamente pelo shell com indicador na tela (fallback para CLI sem o shell) |
</details>

<details>
  <summary><strong>Janelas</strong></summary>

| Atalho | Ação | Descrição |
|---|---|---|
| `SUPER + Space` | Flutuante + Centralizar | Alterna o modo flutuante e centraliza a janela (70% do tamanho do monitor) |
| `SUPER + S` | Alternar Flutuante | Alterna o modo flutuante sem centralizar |
| `SUPER + Q` | Fechar Janela | Fecha a janela ativa |
| `SUPER + F` | Tela Cheia | Alterna o modo tela cheia |
| `SUPER + SHIFT + ←/→/↑/↓` | Mover Janela | Move a janela ativa na direção indicada (respeitando grupos) |
| `SUPER + ←/→/↑/↓` | Focar Janela | Move o foco na direção indicada |
| `SUPER + ALT + ←/→/↑/↓` | Redimensionar Janela | Redimensiona a janela ativa (passos de 40px, com repetição) |
| `SUPER + Clique Esquerdo` | Arrastar Janela | Move/arrasta a janela com o mouse |
| `SUPER + Clique Direito` | Redimensionar Janela | Redimensiona a janela com o mouse |
| `SUPER + J` | Alternar Divisão | Alterna a direção da divisão do dwindle |
| `SUPER + G` | Grupo | Cria/desfaz um grupo de janelas (abas) |
| `SUPER + grave` | Urgente / Anterior | Foca a janela urgente ou a anterior |
| `SUPER + CTRL + H/J/K/L` | Trocar Janela | Troca a janela ativa com a vizinha |
</details>

<details>
  <summary><strong>Workspaces e monitores</strong></summary>

| Atalho | Ação | Descrição |
|---|---|---|
| `SUPER + W` | Workspace Especial | Alterna o workspace especial `"magic"` |
| `SUPER + SHIFT + W` | Mover para Especial | Move a janela ativa para o workspace especial |
| `SUPER + ALT + W` | Mover para Próximo Monitor | Move a janela ativa para o próximo monitor (`m+`) |
| `SUPER + 1–0` | Focar Workspace | Troca para o workspace 1–10 |
| `SUPER + SHIFT + 1–0` | Mover para Workspace | Move a janela ativa para o workspace 1–10 |
| `SUPER + P` | Fixar | Fixa a janela ativa (flutuante) em todos os workspaces |
| `SUPER + CTRL + ←/→` | Workspace Anterior / Próximo | Percorre os workspaces ocupados |
</details>

<details>
  <summary><strong>Captura e zoom</strong></summary>

| Atalho | Ação | Descrição |
|---|---|---|
| `SUPER + Delete` | Screenshot (Tela Cheia) | Captura o monitor em foco, salva em `~/Pictures` e copia para a área de transferência |
| `SUPER + SHIFT + Delete` | Screenshot (Área) | Captura a área selecionada com `slurp` + `grim`, salva e copia para a área de transferência |
| `SUPER + R` | Gravação de Tela | Alterna o GPU Screen Recorder (`toggle-gsr.sh`) salva em `~/Videos` |
| `SUPER + Scroll Down` | Zoom Out | Diminui o fator de zoom do cursor (mínimo 1.0) |
| `SUPER + Scroll Up` | Zoom In | Aumenta o fator de zoom do cursor (máximo 1.5) |
| `SUPER + Numpad -` | Zoom Out | Diminui o zoom do cursor em 0.3 |
| `SUPER + Numpad +` | Zoom In | Aumenta o zoom do cursor em 0.3 |
</details>

## Estrutura do repositório

```text
flake.nix, flake.lock    o flake (pacotes, módulos NixOS / Home Manager, instalador, template)
nix/                     módulos, pacotes, instalador guiado, verificações
configs/                 configuração do desktop, ligada no seu home pelo Home Manager
branding/                fontes do tema do GRUB, do splash do Plymouth e da arte do boot
greeter/                 greeter em Quickshell para o greetd
templates/nixos/         configuração inicial (nix flake init -t)
wallpapers/              wallpapers incluídos
docs/                    guias em inglês e português do Brasil
tests/                   verificações do instalador e da documentação
```

## Documentação

| Guia | English | Português (Brasil) |
|---|---|---|
| Instalação, opções, boot e login | [NixOS](docs/nixos.md) | [NixOS](docs/nixos.pt-br.md) |
| Tema Nothing, wallpapers, troca de branch | [Nothing theme](docs/nothing-theme.md) | [Tema Nothing](docs/nothing-theme.pt-br.md) |
| Contribuição | [Contributing](CONTRIBUTING.en.md) | [Contribuindo](CONTRIBUTING.md) |

> [!NOTE]
> Fornecido como está. Leia os [avisos de terceiros](THIRD-PARTY-CREDITS.md) antes de redistribuir componentes incluídos.

---

<p align="center">
  Feito com ☕ no NixOS · <a href="LICENSE">Licença MIT</a>
</p>
