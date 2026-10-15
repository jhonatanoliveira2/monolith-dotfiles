# Configuração

[Português (Brasil)](configuracao.md) · [English](configuration.md)

Este documento descreve **como o repositório é organizado** e o que as configurações fazem.

## Estrutura do repositório

```text
monolith-dotfiles/
├── .github/                 modelos de issue/PR e CI (ci.yml)
├── assets/
│   ├── logo/                logo.svg, banner.svg
│   ├── screenshots/         SUAS capturas de tela (vazio)
│   └── previews/            prévias SVG do instalador
├── configs/
│   ├── .config/             → ~/.config      (hypr waybar fish ghostty fastfetch btop swaync nvim micro
│   │                                          gtk-3.0 gtk-4.0 nwg-look wal wpg)
│   └── .local/bin/          → ~/.local/bin   (scripts chamados por atalhos)
├── scripts/
│   ├── install.sh           instalador (ponto de entrada)
│   ├── backup.sh            snapshots e listagem de backups
│   ├── restore.sh           restauração dos originais
│   ├── check-dependencies.sh  pacotes, arquivos referenciados e avisos de sistema
│   ├── import-configs.sh    copia ~/.config para configs/ (com exclusões)
│   └── lib/                 common, i18n, messages, ui, packages
├── docs/                    esta documentação
├── tests/test-installer.sh  testes com fixtures
├── tools/ansi2svg.py        gera as prévias SVG
├── packages.txt  README*.md  CONTRIBUTING*.md  LICENSE  THIRD_PARTY_NOTICES.md  .gitignore
```

Regra: **tudo dentro de `configs/` é copiado como está** para a home; nada é gerado ou reescrito.
Os arquivos `.gitkeep` são marcadores e nunca são instalados.

## O que cada pasta contém

| Pasta | Conteúdo |
|---|---|
| `hypr/` | `hyprland.lua` carrega módulos Lua em `modules/`: `core`, `environment`, `monitors`, `input`, `layout`, `animations`, `misc`, `autostart`, `programs`, `keybindings`, `media-keys`, `window-rules`; além de `scheme/current.lua` (cores), `hyprland-gui.lua`, `hyprlock.conf`, `xdph.conf` e `rofi/launcher.{sh,rasi}`, `rofi/wallpaper-menu.rasi` |
| `waybar/` | `config.jsonc`, `style.css`, `colors/`, `rofi/audio-menu.rasi` e `scripts/` (`player`, `sysmon`, `network-status`, `audio-menu`, `power-profile`, `waybar-launch`) |
| `swaync/` | Central de notificações |
| `ghostty/` | `config.ghostty` (usa `fish` como comando) e `shaders/` de cursor (licença MIT própria) |
| `fish/` | `config.fish` (autostart do Hyprland no TTY1, funções `ai`/`aic`, starship, atuin), completions |
| `fastfetch/` | `config.jsonc`, `random_logo.sh`, `ascii/arch.txt` (+ imagens PNG de logos) |
| `btop/` | `btop.conf` |
| `micro/` | `settings.json`, `bindings.json`, `colorschemes/one-dark.micro` |
| `nvim/` | Starter do LazyVim (`init.lua`, `lua/config/*`, `lazyvim.json`, `lazy-lock.json`) |
| `gtk-3.0/`, `gtk-4.0/`, `nwg-look/` | `settings.ini`, `gtk.css`, config do `nwg-look` (tema Adwaita) |
| `wal/`, `wpg/` | `wpg.conf` (backend `wal`), `keywords.conf`, `wp_init.sh` |

### Atalhos principais (`hypr/modules/keybindings.lua`)

| Atalho | Ação |
|---|---|
| `SUPER+Return` | terminal (`ghostty`) |
| `SUPER+A` | alterna o lançador Rofi (`~/.config/hypr/rofi/launcher.sh`) |
| `SUPER+C` | central de notificações (`swaync-client -t -sw`) |
| `SUPER+TAB` | `zen-browser` |
| `SUPER+Delete` / `+SHIFT` | captura de tela (monitor `DP-1`) / de uma área; copia para a área de transferência |
| `SUPER+R` | liga/desliga a gravação de tela (`gpu-screen-recorder`, HEVC 60 FPS) |
| `SUPER+D` | menu de wallpapers (`~/.local/bin/wallpaper-menu`) |
| `SUPER+Space` / `S` / `F` / `Q` | flutuar e centralizar a 70% / alternar flutuante / tela cheia / fechar |
| `SUPER+W` (+`SHIFT`/`ALT`) | workspace especial |
| Teclas de mídia | `wpctl` (volume/mudo), `brightnessctl`, `playerctl` |

## Itens específicos da máquina

Revise **antes** de usar em outro computador:

- `hypr/modules/monitors.lua`: saídas `DP-1` (1920×1080@300, posição `1920x0`) e `DP-2` (1920×1080@180,
  posição `0x0`). Ajuste nomes, resoluções e taxas.
- `hypr/modules/keybindings.lua`: a captura de tela cheia usa `grim -o DP-1` (monitor fixo); a gravação exige
  codificação HEVC por GPU e usa `/tmp/osu-gsr.pid`.
- `hypr/modules/core.lua`: `cursor.no_hardware_cursors = 1` (costuma ser contorno para certas GPUs).
- `hypr/modules/environment.lua`: `LANG`/`LC_TIME = pt_BR.UTF-8` — o locale precisa existir no sistema
  (o instalador avisa se não existir, mas **não** o gera).
- `hypr/modules/input.lua`: layout `us`, sensibilidade `-0.2`, gesto de 3 dedos para workspaces.
- `fish/config.fish`: no TTY1, sem `WAYLAND_DISPLAY`, executa `exec start-hyprland` — só funciona se o
  seu shell de login for `fish` (o instalador não troca o shell).
- `waybar/config.jsonc`: dispositivo de brilho `intel_backlight` (ver `ls /sys/class/backlight`).

## Wallpapers

`SUPER+D` abre o `wallpaper-menu`, um menu Rofi (tema: `hypr/rofi/wallpaper-menu.rasi`) com prévias:

| Tipo | Pasta | Motor |
|---|---|---|
| Estático | `~/Pictures/Wallpapers` | `awww` |
| Animado (`.mp4`) | `~/Videos/wallpaper-live` | `mpvpaper` |

O instalador cria as duas pastas (sem tocar no conteúdo). As prévias são geradas com `ffmpeg` e guardadas em
`~/.cache/wallpaper-menu/`. Use `wallpaper-menu --restore` no autostart (depois do `awww-daemon`) para reaplicar a
última escolha; `wallpaper-menu --clear-cache` remove as prévias.

## Arquivos deixados de fora

O `import-configs.sh` e o `.gitignore` **não incluem** (nada é apagado da sua máquina):

| Padrão | Motivo |
|---|---|
| `micro/backups/` | cópias de arquivos editados — podem conter segredos e caminhos pessoais |
| `fish/fish_variables` | variáveis universais: `PATH` e caminhos da máquina |
| `fish/conf.d/*.env.fish` | gerados por instaladores de terceiros, com caminhos absolutos |
| `wpg/schemes/`, `wpg/sequences`, `wpg/samples/` | gerados a partir do papel de parede, com caminhos absolutos |
| `wal/colors*`, `wal/sequences` | cache do pywal |
| `*.bak`, `*~`, `*.swp`, `*.tmp`, `*.log`, `__pycache__`, `.git`, `.DS_Store` | lixo e artefatos locais |
| `.env*`, `*.key`, `*.pem`, `*.gpg`, `auth.json`, `credentials*`… | segredos (só no `.gitignore`) |

Se quiser publicar algum deles, remova o padrão do `.gitignore` e de `EXCLUDES` em `scripts/import-configs.sh`
**depois de conferir o conteúdo**. Antes de qualquer `git push`, revise o que está em `configs/` — dados
pessoais ainda podem existir em arquivos que o filtro não conhece.
