<h1 align="center">
  <strong>monolith-dotfiles.</strong>
</h1>

<p align="center">
  <img alt="Arch Linux" src="https://img.shields.io/badge/Arch_Linux-1793d1?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="CachyOS" src="https://img.shields.io/badge/CachyOS-00aa88?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland_0.55+-00d9f5?style=for-the-badge&logo=hyprland&logoColor=black">
  <img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-QML-41cd52?style=for-the-badge&logo=qt&logoColor=white">
  <img alt="Lua" src="https://img.shields.io/badge/Config-Lua-2c2d72?style=for-the-badge&logo=lua&logoColor=white">
  <img alt="Licença MIT" src="https://img.shields.io/badge/Licen%C3%A7a-MIT-8b9099?style=for-the-badge">
</p>

<p align="center">
  <strong>🇧🇷 Português (Brasil)</strong> &nbsp;·&nbsp; <a href="README.md">🇺🇸 English</a>
</p>

<p align="center">
  <em>Um desktop Hyprland monocromático — compositor, shell, terminal e ferramentas em um só repositório.</em>
</p>

<p align="center">
  <a href="#destaques">Destaques</a> &nbsp;•&nbsp;
  <a href="#início-rápido">Instalar</a> &nbsp;•&nbsp;
  <a href="#atalhos">Atalhos</a> &nbsp;•&nbsp;
  <a href="#documentação">Docs</a>
</p>


## O que vem incluído

| Camada | O que está incluído |
|---|---|
| 🪟 Gerenciador de janelas | Hyprland, configurado em Lua e dividido em módulos |
| 🧩 Shell gráfico | Barra, menus, notificações, OSD e app de Configurações em Quickshell |
| 💻 Terminal e shell | Ghostty, Fish, Starship e Atuin |
| 🚀 Lançadores e arquivos | Rofi, Nautilus e seletor de wallpapers |
| 🛠️ Ferramentas pessoais | Configurações para Neovim, Micro e btop |
| 🎨 Aparência | Ajustes GTK, paletas derivadas de wallpapers e shaders de cursor |

## Início rápido

Um repositório, dois caminhos: o instalador em shell no **Arch Linux / CachyOS** e o flake Nix no **NixOS**. A configuração do desktop em `configs/` é a mesma nos dois.

### Arch Linux e CachyOS

> [!CAUTION]
> Algumas opções dependem do hardware (monitores, entrada, idioma). Revise [`docs/configuracao.md`](docs/configuracao.md) antes de instalar.

**Requisitos:** Arch Linux ou CachyOS ([detalhes](docs/instalacao.md#arch-linux-e-cachyos)) · Bash 4.4+ · Git · uma conta de usuário comum · Hyprland 0.55 ou superior. Um auxiliar do AUR (**paru** ou **yay**) só é necessário se você quiser que o instalador compile pacotes do AUR.

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles
./scripts/install.sh
```

> [!TIP]
> O instalador copia `configs/` para sua pasta pessoal, instala os pacotes (pule com `--no-deps`) e coloca os wallpapers incluídos em `~/Pictures/Wallpapers` e `~/Videos/wallpaper-live`.

<details>
  <summary><strong>Backup e recuperação</strong></summary>

  ```bash
  ./scripts/backup.sh --list
  ./scripts/restore.sh
  ./scripts/restore.sh --dry-run
  ```

  Os backups ficam em `~/.local/share/monolith-dotfiles/backups/`. Consulte o [guia de instalação](docs/instalacao.md#backup-e-recuperação) para restaurar um snapshot específico ou recuperar arquivos manualmente.
</details>

**Tema:** o instalador pergunta entre o tema padrão e o tema Nothing (`--theme default|nothing` pula a pergunta). Depois: `./scripts/nothing-theme.sh on` / `off` ([docs/nothing-theme.pt-br.md](docs/nothing-theme.pt-br.md#arch-linux--cachyos-scriptsnothing-themesh)).

## Atalhos

`SUPER` é o modificador principal. As teclas de mídia (volume, brilho, player) são tratadas nativamente pelo shell, com indicador na tela.

<details open>
  <summary><strong>Apps e shell</strong></summary>

| Atalho | Ação | Descrição |
|---|---|---|
| `SUPER + Return` | Terminal | Abre o terminal (`programs.terminal`) |
| `SUPER + X` | Gerenciador de Arquivos | Abre o gerenciador de arquivos (`programs.fileManager`) |
| `SUPER + C` | Code | Abre o VS Code / Cursor |
| `SUPER + TAB` | Navegador | Abre o Zen Browser |
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

### NixOS

Pela ISO de instalação do NixOS, conectado à rede:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:jhonatanoliveira2/monolith-dotfiles#install
```

O instalador guiado pergunta o disco, usuário, hostname, idioma, teclado, LUKS, swap e tema (padrão ou Nothing), mostra um resumo e só
apaga o disco depois que o nome dele é digitado de volta. Num NixOS já instalado, ou num flake existente, veja
[docs/nixos.pt-br.md](docs/nixos.pt-br.md#instalação). Atualizações: Configurações > Atualização, ou
`sudo nix flake update monolith --flake /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos`.
O tema Nothing escolhido ali é uma linha da configuração (`monolith.nothingTheme.enable = true;`,
[docs/nothing-theme.pt-br.md](docs/nothing-theme.pt-br.md)): mude-a e reconstrua para trocar depois.

## Estrutura do repositório

```text
configs/                 Configurações de desktop instaladas na pasta pessoal
scripts/                 Instalador, backup, restauração, verificações e importação
docs/                    Guias em inglês e português do Brasil
assets/                  Imagens usadas pela documentação
wallpapers/              Wallpapers estáticos e animados incluídos
tests/                   Lint e testes do instalador, do shell (QML sem compositor) e da documentação
flake.nix, flake.lock    O flake (pacotes, módulos NixOS / Home Manager, instalador, template)
nix/                     NixOS: módulos, pacotes, instalador guiado, verificações, ferramentas do tema Nothing
branding/                NixOS: fontes do tema do GRUB, do splash do Plymouth e da arte do boot
greeter/                 NixOS: greeter em Quickshell para o greetd
templates/nixos/         NixOS: configuração inicial (nix flake init -t)
tools/                   Utilitário para renderizar prévias do terminal
packages.txt             Relação de pacotes oficiais, opcionais e AUR
LICENSE                  MIT
```

## Documentação

| Guia | English | Português (Brasil) |
|---|---|---|
| Instalação e recuperação | [Installation](docs/installation.md) | [Instalação](docs/instalacao.md) |
| Configuração e notas de hardware | [Configuration](docs/config.md) | [Configuração](docs/configuracao.md) |
| Justificativas dos pacotes | [Dependencies](docs/dependencies.md) | [Dependências](docs/dependencias.md) |
| NixOS: instalação, opções, boot e login | [NixOS](docs/nixos.md) | [NixOS](docs/nixos.pt-br.md) |
| Tema Nothing e seus wallpapers (NixOS, Arch / CachyOS) | [Nothing theme](docs/nothing-theme.md) | [Tema Nothing](docs/nothing-theme.pt-br.md) |
| Problemas comuns | [Troubleshooting](docs/troubleshooting.md) | [Solução de problemas](docs/problemas-conhecidos.md) |
| Contribuição | [Contributing](CONTRIBUTING.en.md) | [Contribuindo](CONTRIBUTING.md) |

> [!NOTE]
> O instalador e os arquivos de configuração são fornecidos como estão. Leia os [avisos de terceiros](THIRD-PARTY-CREDITS.md) antes de redistribuir componentes incluídos.

---

<p align="center">
  Feito com ☕ no Arch Linux · <a href="LICENSE">Licença MIT</a>
</p>