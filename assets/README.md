# assets

| Folder | What goes here |
|---|---|
| `logo/` | `logo.svg` (mark) and `banner.svg` (README header) — vector, graphite + cyan. |
| `screenshots/` | **Your** screenshots (see the list below). Not generated. |
| `previews/` | `installer-welcome.svg` and `installer-run.svg`: terminal renderings of the installer. |

## Screenshots to add / Capturas de tela para adicionar

The READMEs reference these names inside HTML comments. Add the files, then uncomment the lines.
Os READMEs referenciam estes nomes dentro de comentários HTML. Adicione os arquivos e descomente as linhas.

| File | Suggested content / Conteúdo sugerido |
|---|---|
| `screenshots/desktop.png` | Full desktop with Waybar and a terminal / Desktop completo com Waybar e terminal |
| `screenshots/waybar.png` | Close-up of the bar / Detalhe da barra |
| `screenshots/launcher.png` | Rofi launcher / Lançador Rofi |
| `screenshots/notifications.png` | swaync notifications and control center / Notificações e central do swaync |
| `screenshots/terminal.png` | Ghostty + fish + fastfetch |
| `screenshots/neovim.png` | Neovim (LazyVim) |
| `screenshots/lockscreen.png` | hyprlock |

Recommended: PNG, 1920×1080 or smaller, no personal data on screen (file names, e-mails, tokens).
Recomendado: PNG, 1920×1080 ou menor, sem dados pessoais visíveis (nomes de arquivos, e-mails, tokens).

## About `previews/`

The two SVGs were produced by `tools/ansi2svg.py` from a **dry-run in a simulated environment**
(fixture files, a stubbed `pacman`). They illustrate the interface; they are **not** a recording of a
real installation. To regenerate them from your own machine:

```bash
script -qec "stty cols 76; ./scripts/install.sh --dry-run --no-clear" /tmp/run.typescript
python3 tools/ansi2svg.py /tmp/run.typescript assets/previews/installer-run.svg --title "MONOLITH installer" --from "[1/7]" --until "To undo" --extra 2
```
