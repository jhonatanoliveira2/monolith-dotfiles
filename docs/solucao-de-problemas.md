# Solução de problemas

[Português (Brasil)](solucao-de-problemas.md) · [English](troubleshooting.md)

Primeiro, olhe o **log técnico** (em inglês) da última execução:

```bash
ls -t ~/.local/state/monolith-dotfiles/*.log | head -1 | xargs less
```

Ao abrir uma *issue*, anexe o log **depois de remover dados pessoais**.

## Instalador

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `No configuration files found in …` (código 2) | `configs/.config/` só tem marcadores | Copie suas pastas: `./scripts/import-configs.sh` |
| `Do not run this installer as root` (4) | Executado com `sudo`/root | Rode como usuário comum; o `sudo` é chamado só para o `pacman` |
| `Refusing to write through a symlinked directory` (4) | `~/.config/<pasta>` é link simbólico (ex.: gerenciado por stow) | Remova o link, ou use `--force-symlinks` sabendo que o destino do link será alterado |
| `A directory exists where a file is expected` (4) | Existe pasta com o nome de um arquivo do repositório | Renomeie/mova a pasta e rode de novo |
| `No interactive terminal detected` (1) | Sem TTY (pipe, CI) | Use `--yes` |
| `pacman failed` (5) | Base de dados desatualizada, rede ou conflito | `sudo pacman -Syu` e tente de novo — nenhuma configuração foi alterada |
| Aviso de pacotes do AUR | Sem `paru`/`yay`, ou a compilação falhou | Instale um auxiliar, ou rode o comando impresso; use `--no-aur` para silenciar |
| Pacote não encontrado | Nome mudou ou ainda não está nos repositórios | Veja `packages.txt`; instale manualmente e use `--no-deps` |
| `Backup failed` (6) | Disco cheio ou sem permissão em `~/.local/share` | Libere espaço/permissão — nada foi alterado |
| `Failed to copy` (7) | Erro ao gravar um arquivo | O instalador já **reverteu** tudo; veja o log e rode de novo |
| Banner ou bordas estranhos | Terminal sem UTF-8/256 cores | Use `--no-color`; defina um locale UTF-8 (`LANG=pt_BR.UTF-8`) |

## Depois de instalar

**Hyprland não inicia / config ignorada.** As configs usam Lua (`hl.*`). Confirme que o seu Hyprland suporta
`hyprland.lua` (`Hyprland --version`; veja as notas de versão). Procure o log do Hyprland (em `$XDG_RUNTIME_DIR/hypr/` ou
`~/.cache/hyprland/`, conforme a versão). Para voltar ao estado anterior: `./scripts/restore.sh`.

**Tela preta no TTY1 ou sessão não sobe.** O `fish/config.fish` faz `exec start-hyprland` no TTY1. Se o seu
shell de login não é `fish`, nada acontece; se é, um erro na config derruba a sessão. Troque para outro TTY
(`Ctrl+Alt+F2`), restaure (`./scripts/restore.sh`) e investigue.

**Monitores errados / resolução incorreta.** Edite `~/.config/hypr/modules/monitors.lua` 

**Textos em inglês ou caracteres quebrados.** O locale `pt_BR.UTF-8` não existe: descomente-o em
`/etc/locale.gen` e rode `sudo locale-gen`.

**Bloqueio de tela com erro / sem rótulos.** Faltam `hypr/hyprlock-colors.conf` ou
`hypr/scripts/password-cursor.sh`. Copie-os para `configs/` e rode o instalador de novo;
`./scripts/check-dependencies.sh --section advice` lista o que falta.

**`SUPER+D` não abre o menu de wallpapers.** Confirme `~/.local/bin/wallpaper-menu` (executável) e
`~/.config/hypr/rofi/wallpaper-menu.rasi`; instale `rofi`, `jq`, `awww`, `mpvpaper` e `ffmpeg`. As pastas são
`~/Pictures/Wallpapers` (estáticos) e `~/Videos/wallpaper-live` (`.mp4`). Prévias erradas: `wallpaper-menu --clear-cache`.

**Barra, rede, áudio ou Bluetooth sem resposta.** Verifique os serviços e pacotes:
`systemctl status NetworkManager bluetooth`, `pactl info`, `playerctl -l`.
**Perfil de energia não aparece:** só em notebook e com `power-profiles-daemon` ativo.

**Capturas/gravação falham.** `grim`, `slurp`, `wl-clipboard`, `jq` e `gpu-screen-recorder` precisam estar
instalados; a gravação exige GPU com codificação HEVC.

**Neovim baixa plugins a cada abertura / erros de parser.** Instale `git`, `gcc` e `tree-sitter-cli`
(opcionais em `packages.txt`) e rode `:Lazy sync`.

**Ícones quadrados na barra/terminal.** Instale `ttf-jetbrains-mono-nerd` e reinicie a barra.

## Recuperação

```bash
./scripts/backup.sh --list          # snapshots disponíveis
./scripts/restore.sh                # volta ao mais recente
./scripts/restore.sh --dry-run      # só mostra o que seria restaurado
```

Passo a passo e recuperação manual: [instalacao.md](instalacao.md#backup-e-recuperação).

## Ainda não resolveu?

Abra uma *issue* com o modelo de relatório: versão do Hyprland, comando usado, trecho do log (sem dados
pessoais) e o que você esperava.
