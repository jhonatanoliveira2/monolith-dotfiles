<h1 align="center">monolith-Dotfiles</h1>

<p align="center">
  <img alt="Arch Linux" src="https://img.shields.io/badge/SO-Arch_Linux-1793d1?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Hyprland" src="https://img.shields.io/badge/Compositor-Hyprland-00d9f5?style=for-the-badge">
  <img alt="Bash" src="https://img.shields.io/badge/Instalador-Bash-4eaa25?style=for-the-badge&logo=gnubash&logoColor=white">
  <img alt="Licença MIT" src="https://img.shields.io/badge/Licen%C3%A7a-MIT-8b9099?style=for-the-badge">
</p>

<p align="center">
  <strong>Português (Brasil)</strong> · <a href="README.md">English</a>
</p>

https://github.com/user-attachments/assets/3df9da29-d3b5-43b1-9512-f72b0a0250b3
[Video YouTube](https://youtu.be/W_SYo-i9fXk)

### Captura de tela 

<p align="center">
  <img src="assets/screenshots/1.png" width="100%">
  <img src="assets/screenshots/2.png" width="100%">
  <img src="assets/screenshots/3.png" width="100%">
</p>

<p align="center">
  <a href="#capturas-de-tela">Conheça o desktop</a> ·
  <a href="#início-rápido">Instale</a> ·
  <a href="#documentação">Leia os guias</a>
</p>

### Visão geral

O MONOLITH reúne compositor, shell gráfico, terminal, ambiente de shell, lançadores e configurações visuais em um só repositório. O instalador verifica dependências, cria cópias de segurança antes de substituir arquivos e pode reverter uma cópia interrompida. Algumas opções dependem do hardware; revise-as antes de aplicar as configurações em outra máquina.

| Camada do desktop | O que está incluído |
|---|---|
| Gerenciador de janelas | Hyprland, configurado em Lua e dividido em módulos |
| Shell gráfico | Barra, menus, notificações e controles do Quickshell |
| Terminal e shell | Ghostty, Fish, Starship e Atuin |
| Lançadores e arquivos | Rofi, Nautilus e seletor de wallpapers |
| Ferramentas pessoais | Configurações para Neovim, Micro e btop |
| Aparência | Ajustes GTK, paletas derivadas de wallpapers e shaders de cursor |


### Início rápido

> [!CAUTION]
> Confira as opções específicas de monitor, entrada e idioma em [`docs/configuracao.md`](docs/configuracao.md) antes de instalar.

Requisitos: `Arch Linux`, `Bash 4.4+`, `Git` e uma `conta de usuário comum`. A configuração Lua incluída requer Hyprland 0.55 ou superior. Um auxiliar do AUR (**paru** ou **yay**) só é necessário se você quiser que o instalador compile pacotes do AUR automaticamente.

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles
./scripts/install.sh
```

> [!TIP]
> O instalador copia as configurações que já estão em `configs/` para sua pasta pessoal. Também instala pacotes, a menos que você use `--no-deps`, e coloca os wallpapers incluídos em `~/Pictures/Wallpapers` e `~/Videos/wallpaper-live`.

<details>
  <summary><strong>Backup e recuperação</strong></summary>

  ```bash
  ./scripts/backup.sh --list
  ./scripts/restore.sh
  ./scripts/restore.sh --dry-run
  ```

  Os backups ficam em `~/.local/share/monolith-dotfiles/backups/`. Consulte o [guia de instalação](docs/Instalacao.md#backup-e-recuperação) para restaurar um snapshot específico ou recuperar arquivos manualmente.
</details>

### Prévia do instalador

<p align="center">
  <img src="assets/previews/installer-welcome.svg" alt="Boas-vindas e etapas do instalador MONOLITH" width="760">
</p>

<details>
  <summary>Ver outra tela do instalador</summary>
  <p align="center"><img src="assets/previews/installer-run.svg" alt="Progresso e conclusão do instalador MONOLITH" width="760"></p>
</details>

### Atalhos do Hyprland

| Atalho | Ação | Descrição |
|--------|------|-----------|
| `SUPER + Return` | Terminal | Abre o terminal (`programs.terminal`) |
| `SUPER + X` | Gerenciador de Arquivos | Abre o gerenciador de arquivos (`programs.fileManager`) |
| `SUPER + C` | Code | Abre o VS Code / Cursor |
| `SUPER + TAB` | Navegador | Abre o Zen Browser |
| `SUPER + Z` | Bloquear | Bloqueia a sessão com `hyprlock` |
| `SUPER + A` | Lançador de Apps | Alterna o Rofi (`~/.config/hypr/rofi/launcher.sh`) |
| `SUPER + Delete` | Screenshot (Tela Cheia) | Captura a tela inteira (DP-1), salva em `~/Pictures` e copia para a área de transferência |
| `SUPER + SHIFT + Delete` | Screenshot (Área) | Captura a área selecionada com `slurp` + `grim`, salva e copia para a área de transferência |
| `SUPER + R` | Gravação de Tela | Alterna o GPU Screen Recorder (`toggle-gsr.sh`) salva em `~/Videos` |
| `SUPER + D` | Menu de Wallpaper | Abre o seletor de wallpapers (`~/.local/bin/wallpaper-menu`) |
| `SUPER + SHIFT + X` | Sair da Sessão | Executa `hyprshutdown` se disponível, senão sai do Hyprland |
| `SUPER + Space` | Flutuante + Centralizar | Alterna o modo flutuante e centraliza a janela (70% do tamanho do monitor) |
| `SUPER + S` | Alternar Flutuante | Alterna o modo flutuante sem centralizar |
| `SUPER + Q` | Fechar Janela | Fecha a janela ativa |
| `SUPER + F` | Tela Cheia | Alterna o modo tela cheia |
| `SUPER + SHIFT + ←/→/↑/↓` | Mover Janela | Move a janela ativa na direção indicada (respeitando grupos) |
| `SUPER + ←/→/↑/↓` | Focar Janela | Move o foco na direção indicada |
| `SUPER + ALT + ←/→/↑/↓` | Redimensionar Janela | Redimensiona a janela ativa (passos de 40px, com repetição) |
| `SUPER + W` | Workspace Especial | Alterna o workspace especial `"magic"` |
| `SUPER + SHIFT + W` | Mover para Especial | Move a janela ativa para o workspace especial |
| `SUPER + ALT + W` | Mover para Próximo Monitor | Move a janela ativa para o próximo monitor (`m+`) |
| `SUPER + 1–0` | Focar Workspace | Troca para o workspace 1–10 |
| `SUPER + SHIFT + 1–0` | Mover para Workspace | Move a janela ativa para o workspace 1–10 |
| `SUPER + Scroll Down` | Zoom Out | Diminui o fator de zoom do cursor (mínimo 1.0) |
| `SUPER + Scroll Up` | Zoom In | Aumenta o fator de zoom do cursor (máximo 1.5) |
| `SUPER + Numpad -` | Zoom Out | Diminui o zoom do cursor em 0.3 |
| `SUPER + Numpad +` | Zoom In | Aumenta o zoom do cursor em 0.3 |
| `SUPER + Clique Esquerdo` | Arrastar Janela | Move/arrasta a janela com o mouse |
| `SUPER + Clique Direito` | Redimensionar Janela | Redimensiona a janela com o mouse |

### Estrutura do repositório

```text
configs/                 Configurações de desktop instaladas na pasta pessoal
scripts/                 Instalador, backup, restauração, verificações e importação
docs/                    Guias em inglês e português do Brasil
assets/                  Identidade visual, prévias e espaços de screenshots
wallpapers/              Wallpapers estáticos e animados incluídos
tests/                   Testes do instalador e da documentação
tools/                   Utilitário para renderizar prévias do terminal
packages.txt             Relação de pacotes oficiais, opcionais e AUR
LICENSE                  MIT
```

### Documentação

| Guia | English | Português (Brasil) |
|---|---|---|
| Instalação e recuperação | [Installation](docs/installation.md) | [Instalação](docs/instalacao.md) |
| Configuração e notas de hardware | [Configuration](docs/config.md) | [Configuração](docs/configuracao.md) |
| Justificativas dos pacotes | [Dependencies](docs/dependencies.md) | [Dependências](docs/dependencias.md) |
| Problemas comuns | [Troubleshooting](docs/troubleshooting.md) | [Solução de problemas](docs/problemas-conhecidos.md) |
| Contribuição | [Contributing](CONTRIBUTING.en.md) | [Contribuindo](CONTRIBUTING.md) |

> [!NOTE] 
> O instalador e os arquivos de configuração são fornecidos como estão. Leia os [créditos e avisos de licença](THIRD-PARTY-CREDITS.md) antes de redistribuir componentes incluídos.