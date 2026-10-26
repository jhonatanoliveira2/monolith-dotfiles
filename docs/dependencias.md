# Dependências e pacotes

[English](dependencies.md) · **Português (Brasil)**

A relação de pacotes em [`../packages.txt`](../packages.txt) é a fonte usada pelo instalador. Este guia resume os critérios e explica como interpretar as categorias.

## Como as categorias funcionam

- **Obrigatório**: usado por um atalho, serviço iniciado pela configuração, componente ativo do Quickshell ou script incluído.
- **Opcional**: necessário apenas para aplicativos ou recursos que não são iniciados automaticamente, ou para hardware específico.
- **AUR**: alguns pacotes podem existir nos repositórios oficiais. O instalador os procura com `pacman` antes de recorrer ao auxiliar do AUR.
- **Manual**: itens que não são instalados pelo `pacman` ou pelo AUR. No manifesto atual, não há itens nesta categoria.

O instalador não executa `pacman -Sy`. Se um pacote não for encontrado, atualize o sistema com `sudo pacman -Syu` e tente novamente.

## Repositórios oficiais — obrigatórios

| Pacote | Uso principal |
|---|---|
| `hyprland`, `hyprlock`, `hypridle`, `xdg-desktop-portal-hyprland` | Compositor, bloqueio, inatividade e compartilhamento de tela |
| `quickshell`, `upower` | Barra, menus e informações de bateria do shell gráfico |
| `lxqt-policykit`, `qt6ct`, `dconf`, `materia-gtk-theme` | Autorização gráfica e preferências visuais |
| `git`, `base-devel` | Dependências usadas no setup e compilação de pacotes quando necessário |
| `rofi` | Lançador e menu de wallpapers; precisa de suporte a Wayland |
| `ghostty`, `fish`, `starship`, `atuin` | Terminal e ambiente de shell |
| `nautilus` | Gerenciador de arquivos associado a atalho |
| `ttf-jetbrains-mono-nerd` | Tipografia do desktop |
| `grim`, `slurp`, `wl-clipboard`, `libnotify`, `jq` | Capturas de tela, área de seleção, cópia, notificações e leitura de dados |
| `ffmpeg` | Pré-visualizações do menu de wallpapers |
| `pipewire`, `pipewire-pulse`, `wireplumber`, `playerctl` | Áudio e controles de mídia |
| `brightnessctl` | Controle de brilho |
| `networkmanager`, `network-manager-applet`, `blueman`, `curl` | Rede, Bluetooth e verificação de conectividade |
| `udisks2`, `pciutils`, `pacman-contrib` | Saúde dos discos, nome da GPU e limpeza do cache do pacman (Configurações) |

## Repositórios oficiais — opcionais

| Pacote | Quando é necessário |
|---|---|
| `fastfetch`, `btop`, `micro` | Ao usar esses aplicativos configurados manualmente |
| `neovim`, `gcc`, `tree-sitter-cli`, `ripgrep`, `fd` | Para o Neovim/LazyVim e seus recursos de busca e compilação de parsers |
| `nwg-look` | Para ajustar temas GTK pela interface gráfica |
| `pavucontrol` | Para abrir o mixer de áudio do menu do Quickshell |
| `power-profiles-daemon` | Para controles de perfil de energia em equipamentos compatíveis |
| `xorg-xwayland` | Para executar aplicativos X11 |

## AUR

| Pacote | Categoria | Uso |
|---|---|---|
| `awww`, `mpvpaper`, `wpgtk` | Obrigatório no manifesto | Wallpapers, integração de cores e temas |
| `ttf-material-icons-git` | Obrigatório no manifesto | Ícones do Quickshell |
| `zen-browser-bin`, `gpu-screen-recorder` | Opcional | Navegador associado a atalho e gravação de tela |

O manifesto é a referência final para a categoria de cada pacote e pode mudar conforme o projeto evolui.

## Conferir o sistema

```bash
./scripts/check-dependencies.sh
./scripts/check-dependencies.sh --list-missing=required
./scripts/check-dependencies.sh --strict
```

A primeira forma mostra o relatório completo. A segunda lista os pacotes obrigatórios ausentes. `--strict` retorna código diferente de zero quando falta uma dependência obrigatória. A verificação também aponta arquivos usados pela configuração que não estejam disponíveis.
