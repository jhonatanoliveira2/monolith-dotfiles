# Atalhos

**Português (Brasil)** · [English](keybinds.md)

`SUPER` é o modificador principal. As teclas de mídia (volume, brilho, player) são tratadas nativamente pelo shell, com indicador na tela.

## Apps e shell

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

## Janelas

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

## Workspaces e monitores

| Atalho | Ação | Descrição |
|---|---|---|
| `SUPER + W` | Workspace Especial | Alterna o workspace especial `"magic"` |
| `SUPER + SHIFT + W` | Mover para Especial | Move a janela ativa para o workspace especial |
| `SUPER + ALT + W` | Mover para Próximo Monitor | Move a janela ativa para o próximo monitor (`m+`) |
| `SUPER + 1–0` | Focar Workspace | Troca para o workspace 1–10 |
| `SUPER + SHIFT + 1–0` | Mover para Workspace | Move a janela ativa para o workspace 1–10 |
| `SUPER + P` | Fixar | Fixa a janela ativa (flutuante) em todos os workspaces |
| `SUPER + CTRL + ←/→` | Workspace Anterior / Próximo | Percorre os workspaces ocupados |

## Captura e zoom

| Atalho | Ação | Descrição |
|---|---|---|
| `SUPER + Delete` | Screenshot (Tela Cheia) | Captura o monitor em foco, salva em `~/Pictures` e copia para a área de transferência |
| `SUPER + SHIFT + Delete` | Screenshot (Área) | Captura a área selecionada com `slurp` + `grim`, salva e copia para a área de transferência |
| `SUPER + R` | Gravação de Tela | Alterna o GPU Screen Recorder (`toggle-gsr.sh`) salva em `~/Videos` |
| `SUPER + Scroll Down` | Zoom Out | Diminui o fator de zoom do cursor (mínimo 1.0) |
| `SUPER + Scroll Up` | Zoom In | Aumenta o fator de zoom do cursor (máximo 1.5) |
| `SUPER + Numpad -` | Zoom Out | Diminui o zoom do cursor em 0.3 |
| `SUPER + Numpad +` | Zoom In | Aumenta o zoom do cursor em 0.3 |

