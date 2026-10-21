# Solução de problemas

[English](troubleshooting.md) · **Português (Brasil)**

Comece pelo log da execução mais recente. Os logs técnicos ficam em `~/.local/state/monolith-dotfiles/` e podem conter caminhos locais; remova informações pessoais antes de compartilhar qualquer trecho.

```bash
ls -t ~/.local/state/monolith-dotfiles/*.log | head -1
```

## Instalador

| Sintoma | O que verificar |
|---|---|
| `No configuration files found` | Confirme que `configs/.config/` contém arquivos de configuração e não apenas marcadores vazios. |
| Recusa em executar como root | Execute como seu usuário comum; o instalador só chama `sudo` quando uma operação de pacote precisa dele. |
| Aviso sobre diretório simbólico | Confira o destino do link. Só use `--force-symlinks` se realmente quiser gravar através dele. |
| `No interactive terminal detected` | Em execução por pipe ou automação, use `--yes` para aceitar os padrões. |
| Falha no `pacman` ou pacote não encontrado | Verifique conexão e conflito; em Arch, sincronize o sistema com `sudo pacman -Syu` e tente novamente. Consulte `packages.txt`. |
| Aviso sobre pacotes do AUR | Instale `paru`/`yay` ou use o comando impresso. `--no-aur` impede a chamada do auxiliar. |
| Falha ao criar backup | Confira espaço livre e permissões de `~/.local/share/monolith-dotfiles/`. A instalação não deve prosseguir sem o snapshot necessário. |
| Falha durante a cópia | Consulte o log. O instalador tenta reverter as alterações feitas durante aquela operação; confira o estado antes de executá-lo novamente. |
| Banner ou caracteres quebrados | Use um terminal UTF-8; tente `--no-color` se o problema for relacionado às cores. |

## Depois da instalação

**Hyprland não inicia ou ignora a configuração.** Confira a versão do Hyprland e confirme que ela aceita a configuração Lua `hyprland.lua`. Consulte o log do compositor e valide os módulos em `~/.config/hypr/`.

**A sessão inicia sem barra ou menus.** O desktop usa Quickshell. Confirme que o pacote `quickshell` está instalado e que `~/.config/quickshell/shell.qml` foi copiado. Rode `./scripts/check-dependencies.sh` para identificar dependências e arquivos ausentes.

**A rede, Bluetooth, áudio ou brilho não responde.** Confirme que os pacotes correspondentes estão instalados e que os serviços necessários estão ativos. A configuração de cada controle fica sob `configs/.config/quickshell/`.

**Wallpapers não aparecem.** Confira se as imagens estão em `~/Pictures/Wallpapers` ou os vídeos em `~/Videos/wallpaper-live`, e se `awww`, `mpvpaper`, `ffmpeg`, `jq` e `rofi` estão disponíveis. Limpe as prévias antigas com `wallpaper-menu --clear-cache`.

**Idioma ou hora não correspondem à preferência.** A configuração define `pt_BR.UTF-8`. Gere esse locale no sistema se necessário; o instalador apenas avisa e não altera a configuração global de locales.

**Neovim mostra erros de parser ou plugins.** Confirme que os opcionais `git`, `gcc` e `tree-sitter-cli` estão instalados; no Neovim, sincronize os plugins com `:Lazy sync`.

**Ícones aparecem como quadrados.** Instale as fontes indicadas em `packages.txt` e reinicie o aplicativo afetado.

## Recuperar arquivos

```bash
./scripts/backup.sh --list
./scripts/restore.sh --dry-run
./scripts/restore.sh
```

A restauração padrão usa o snapshot mais recente. Para escolher outro, passe `--id ID`. Use `--remove-new` apenas se também quiser remover os arquivos que não existiam antes; faça uma simulação antes. O passo a passo completo está em [Instalação e recuperação](Instalacao.md#backup-e-recuperação).

## Pedir ajuda

Abra uma [issue no GitHub](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) com a versão do Hyprland, o comando executado, o comportamento esperado e um trecho do log já revisado para remover dados pessoais.
