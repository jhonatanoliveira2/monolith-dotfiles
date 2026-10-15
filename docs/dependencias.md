# Dependências

[Português (Brasil)](dependencias.md) · [English](dependencies.md)

A lista legível por máquina é [`../packages.txt`](../packages.txt) (seções `[origem:escopo]`). Este documento
explica **como** ela foi montada e **por quê**. 

## Critérios

- **Obrigatório**: algo na configuração *ativa* o chama — autostart, atalho, módulo da Waybar, script ou
  variável de ambiente.
- **Opcional**: o app tem configuração incluída, mas **nada o inicia** (você o abre à mão), ou o recurso só
  vale em certas máquinas (notebook, X11).
- Itens **comentados ou inertes não foram promovidos** (ex.: a chamada do `fastfetch` no `config.fish`
  está comentada; `programs.ide = "code"` não é usado por nenhum atalho).
- Pacotes do grupo `base` (bash, coreutils, procps-ng, util-linux, systemd, …) são presumidos.

## Pacotes oficiais obrigatórios

| Pacote | Quem usa |
|---|---|
| `hyprland` | `hyprland.lua`, `start-hyprland` (fish) |
| `hyprlock` | atalho `SUPER+Z`, `hyprlock.conf` |
| `xdg-desktop-portal-hyprland` | `hypr/xdph.conf` |
| `lxqt-policykit` | autostart `/usr/bin/lxqt-policykit-agent` |
| `qt6ct` | `QT_QPA_PLATFORMTHEME=qt6ct` |
| `waybar`, `swaync`, `rofi` | autostart, atalhos `SUPER+A`/`SUPER+C`, menu de áudio |
| `ghostty`, `fish`, `starship`, `atuin` | terminal; shell; `starship`/`atuin init fish` em todo shell interativo |
| `nautilus` | `programs.lua` (`SUPER+X`) |
| `ttf-jetbrains-mono-nerd` | Temas da Waybar, do Rofi e do swaync (*JetBrainsMono Nerd Font*) |
| `grim`, `slurp`, `wl-clipboard`, `libnotify`, `jq` | atalhos de captura e gravação (`grim`, `slurp`, `wl-copy`, `notify-send`, `jq`); `jq` também é usado pelo `wallpaper-menu` |
| `ffmpeg` | `wallpaper-menu`: prévias de imagens e vídeos |
| `pipewire`, `pipewire-pulse`, `wireplumber`, `libpulse` | `wpctl` (teclas de mídia), `pactl` (Waybar: mudo e menu de saídas) |
| `playerctl` | teclas de mídia, player da Waybar, rótulo do hyprlock |
| `brightnessctl` | teclas de brilho |
| `networkmanager`, `network-manager-applet` | módulo de rede (clique abre `nm-connection-editor`) |
| `blueman` | módulo Bluetooth (clique abre `blueman-manager`) |
| `curl` | `network-status.sh` (teste real de internet) |

## Pacotes oficiais opcionais

| Pacote | Observação |
|---|---|
| `fastfetch`, `btop`, `micro` | configurações incluídas; nada os inicia |
| `neovim`, `git`, `gcc`, `tree-sitter-cli`, `ripgrep`, `fd` | LazyVim: `git` clona os plugins; `gcc` e `tree-sitter-cli` compilam parsers; `ripgrep`/`fd` são recomendados |
| `nwg-look` | gerenciador de tema GTK, usado à mão |
| `python-pywal` | backend do `wpg` (`backend = wal`); só se você rodar o `wpg` |
| `power-profiles-daemon` | módulo de perfil de energia (notebook); sem ele o módulo fica oculto. Com TLP/auto-cpufreq, não instale |
| `xorg-xwayland` | apps X11 (há uma regra de janela para `xwayland`) |

## AUR

| Pacote | Escopo | Observação |
|---|---|---|
| `awww` | obrigatório | autostart do `awww-daemon`; wallpapers estáticos do `wallpaper-menu`. Pode já estar nos repositórios oficiais |
| `mpvpaper` | obrigatório | wallpapers animados do `wallpaper-menu` (pode já estar nos repositórios oficiais) |
| `zen-browser-bin` | opcional | `SUPER+TAB` |
| `gpu-screen-recorder` | opcional | `SUPER+R` (pode estar nos repositórios oficiais) |
| `hyprshutdown` | opcional | `SUPER+X` tem *fallback* para `hyprctl dispatch exit` |
| `wpgtk` | opcional | comando `wpg` (`wp_init.sh`, `wpg/`) |

O instalador consulta `pacman -Si` antes: o que já estiver nos repositórios oficiais é instalado com o `pacman`.

## Serviços e locale (não alterados pelo instalador)

`NetworkManager.service`, `bluetooth.service` e, em notebook, `power-profiles-daemon.service` precisam estar
ativos para os módulos correspondentes. O locale `pt_BR.UTF-8` precisa estar gerado (`/etc/locale.gen`).
O `check-dependencies.sh` apenas avisa.

## Verificar

```bash
./scripts/check-dependencies.sh                         # relatório completo
./scripts/check-dependencies.sh --list-missing=required # só o que falta (saída para máquinas)
./scripts/check-dependencies.sh --strict                # sai com 1 se faltar algo obrigatório
```
