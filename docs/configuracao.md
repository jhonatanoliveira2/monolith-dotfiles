# Configuração do desktop

[English](config.md) · **Português (Brasil)**

`configs/` espelha caminhos dentro da sua pasta pessoal: `configs/.config/` é instalado em `~/.config/`, e `configs/.local/bin/` em `~/.local/bin/`. O instalador copia o conteúdo; ele não gera nem adapta as configurações ao seu hardware.

## O que está incluído

| Pasta | Conteúdo |
|---|---|
| `hypr/` | Configuração modular do Hyprland em Lua, bloqueio de tela, idle, portal e temas do Rofi |
| `quickshell/` | Barra, menus de configurações, rede, Bluetooth, áudio, brilho, notificações e módulos de sistema |
| `fish/` | Configuração do Fish, inicialização do Hyprland no TTY1, Starship, Atuin e completions |
| `ghostty/` | Configuração do terminal e shaders de cursor |
| `gtk-3.0/`, `gtk-4.0/`, `nwg-look/` | Aparência e preferências de aplicativos GTK |
| `nvim/`, `micro/`, `btop/` | Inicialização do Neovim com LazyVim, editor Micro e monitor de recursos |
| `wal/`, `wpg/` | Configuração para temas derivados de wallpapers |

`wallpapers/` contém mídia distribuída separadamente das configurações. `scripts/import-configs.sh` pode copiar pastas selecionadas do seu `~/.config` para o payload do repositório; essa operação é opcional.

## Revise antes de instalar

As configurações têm algumas escolhas locais que podem não corresponder ao seu equipamento:

- `hypr/modules/monitors.lua` seleciona automaticamente a saída preferida, posição automática e escala `1`. Ajuste o arquivo se seu arranjo de monitores exigir outra coisa.
- `hypr/modules/environment.lua` define `LANG` e `LC_TIME` como `pt_BR.UTF-8`. Esse locale precisa existir no sistema; o instalador avisa, mas não o gera.
- `hypr/modules/input.lua` contém as preferências de teclado e entrada. Revise o layout e os valores antes de usar.
- `fish/config.fish` inicia Hyprland no TTY1 sob as condições definidas no arquivo. Isso depende do shell de login e do modo como você inicia sua sessão.
- `hypr/modules/keybindings.lua` contém atalhos e comandos locais. Confirme que os programas associados estão instalados.

O ponto de entrada do compositor é `hypr/hyprland.lua`. O Quickshell começa em `quickshell/shell.qml`; sua barra e seus componentes ficam nas pastas `components/`, `modules/`, `menus/`, `services/` e `core/`.

## Wallpapers

O atalho `SUPER+D` abre o menu Rofi configurado em `hypr/rofi/wallpaper-menu.rasi` e executa `~/.local/bin/wallpaper-menu`.

| Tipo | Destino na sua pasta pessoal | Motor |
|---|---|---|
| Estático | `~/Pictures/Wallpapers` | `awww` |
| Vídeo `.mp4` | `~/Videos/wallpaper-live` | `mpvpaper` |

O instalador cria esses destinos e copia os wallpapers que acompanham o projeto. O menu usa `ffmpeg` para gerar prévias em cache; `wallpaper-menu --clear-cache` limpa esse cache.

## Arquivos excluídos na importação

O importador evita copiar alguns dados de máquina e artefatos, incluindo:

| Caminho ou padrão | Por que é excluído |
|---|---|
| `micro/backups/` | Pode conter versões de qualquer arquivo editado. |
| `fish/fish_variables` | Pode guardar variáveis e caminhos particulares da máquina. |
| `fish/conf.d/*.env.fish` | Arquivos gerados por instaladores de terceiros e com caminhos locais. |
| `*.bak`, `*~`, `*.swp`, `*.tmp`, `*.log`, `__pycache__`, `.git`, `.DS_Store` | Backups temporários e artefatos locais. |

Essas exclusões são aplicadas pelo importador; elas não substituem a revisão manual dos arquivos antes de publicar. O projeto não deve receber tokens, chaves, credenciais, e-mails ou caminhos privados.

## Estrutura simplificada

```text
configs/
├── .config/
│   ├── hypr/         compositor, atalhos e Rofi
│   ├── quickshell/   barra, menus e componentes do desktop
│   ├── fish/         shell e inicialização
│   ├── ghostty/      terminal e shaders
│   └── ...           ferramentas e preferências visuais
└── .local/bin/       utilitários chamados pelos atalhos
```

Para instalar ou desfazer a instalação, consulte o [guia de instalação](Instalacao.md).
