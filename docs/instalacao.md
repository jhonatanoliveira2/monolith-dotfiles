# Instalação e recuperação

[English](installation.md) · **Português (Brasil)**

Este guia instala as configurações já incluídas no repositório. Não é necessário importar arquivos da sua pasta pessoal para começar.

## Requisitos

- Arch Linux, CachyOS ou outra distribuição baseada no Arch que use `pacman` (veja [Arch Linux e CachyOS](#arch-linux-e-cachyos)).
- Bash 4.4+, Git e uma conta de usuário comum. O instalador recusa execução como root.
- Hyprland 0.55 ou superior para a configuração Lua incluída.
- `paru` ou `yay` somente se quiser compilar pacotes do AUR automaticamente. Sem um auxiliar, o instalador mostra os comandos para instalação manual (no CachyOS, ele propõe instalar um a partir dos repositórios).

## Instalar

Clone o repositório e revise as opções de hardware antes de aplicar as configurações:

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles
```

Faça uma simulação e, se o plano estiver correto, execute a instalação:

```bash
./scripts/install.sh
```

O instalador verifica os pré-requisitos e as dependências, planeja os arquivos a instalar, cria um snapshot dos arquivos que serão substituídos e então copia a configuração. Ele também disponibiliza os wallpapers do projeto em `~/Pictures/Wallpapers` e `~/Videos/wallpaper-live`.

## Arch Linux e CachyOS

O instalador lê o `/etc/os-release` e informa o que encontrou: Arch Linux (`ID=arch`), CachyOS (`ID=cachyos`) ou outra distribuição com `pacman` (`ID_LIKE=arch`). Todas passam pelas mesmas etapas; as diferenças entre elas são tratadas por verificações que também rodam no Arch, e não por caminhos de código separados:

- **Repositórios.** Cada pacote é procurado primeiro nos repositórios configurados no `pacman.conf`. No CachyOS, isso inclui os repositórios dele (compilações otimizadas e pacotes que no Arch só existem no AUR), que são instalados com o `pacman` em vez de compilados.
- **Auxiliar do AUR.** Se nem o `paru` nem o `yay` estiverem instalados, mas os repositórios oferecerem um deles (o CachyOS oferece), o instalador propõe instalá-lo com o `pacman` e passa a usá-lo. No Arch nada muda: sem auxiliar, os comandos manuais são exibidos.
- **Conflitos.** Um pacote que conflita com algo já instalado (um servidor de áudio ou daemon de energia escolhido pela distribuição, por exemplo) é deixado de fora e listado no resumo; o instalado é mantido. Sem isso, o `pacman` abortaria a instalação inteira. Substitua manualmente se preferir a escolha do MONOLITH.
- **Kernel e ferramentas do sistema.** Nada depende do pacote do kernel (`linux`, `linux-cachyos`, ...): o shell lê `/proc` e `/sys`. Partições com vários subvolumes btrfs (o padrão do CachyOS) aparecem uma vez na aba Performance, com o número de pontos de montagem extras.
- **fish.** No CachyOS, o `~/.config/fish/config.fish` normalmente só carrega o `cachyos-fish-config`. O instalador o substitui pela versão do MONOLITH (o original vai para o snapshot de backup). Para manter os aliases do CachyOS, adicione `source /usr/share/cachyos-fish-config/cachyos-config.fish` dentro do bloco `status is-interactive`.
- **Edição Hyprland.** Um `~/.config/hypr/hyprland.conf` existente não atrapalha: quando os dois arquivos existem, o Hyprland carrega o `hyprland.lua`.
- **Logo.** O shell mostra o logo da distribuição em uso (barra, menu rápido, tela de boas-vindas, dashboard). O logo do CachyOS vem do glifo `linux-cachyos` da Nerd Font (presente na `ttf-jetbrains-mono-nerd` 3.5).

## Opções do instalador

| Opção | Efeito |
|---|---|
| `--lang en\|pt_BR` | Escolhe o idioma da interface e ignora a seleção interativa. Também aceita `MONOLITH_LANG`. |
| `-y`, `--yes` | Aceita os padrões sem perguntar; pacotes opcionais são incluídos (use `--no-optional` para pulá-los). |
| `-n`, `--dry-run` | Mostra o que seria feito sem aplicar alterações. |
| `--no-deps` | Não instala pacotes. |
| `--with-optional` | Instala os pacotes opcionais de `packages.txt` sem perguntar. |
| `--no-optional` | Pula os pacotes opcionais. |
| `--no-aur` | Não chama auxiliar do AUR; exibe os comandos manuais. |
| `--aur-helper NOME` | Seleciona o auxiliar do AUR (por padrão, `paru` e depois `yay`). |
| `--force-symlinks` | Permite escrever por diretórios simbólicos dentro de `$HOME`. Use apenas após revisar os destinos. |
| `--no-color`, `--no-clear` | Desativa cores ou a limpeza de tela. |
| `--version`, `-h`, `--help` | Mostra a versão ou a ajuda. |

Sem terminal interativo, use `--yes`. Confira `./scripts/install.sh --help` para a sintaxe correspondente à versão instalada.

## Backup e recuperação

O instalador executa como usuário comum; `sudo` é usado somente nas operações do `pacman` que precisam de privilégio. Um snapshot é criado quando arquivos existentes serão substituídos. Arquivos iguais são ignorados e arquivos pessoais que não existem no repositório não são removidos.

```bash
./scripts/backup.sh --list
./scripts/backup.sh --dry-run
./scripts/restore.sh --dry-run
./scripts/restore.sh
```

`restore.sh` restaura o snapshot mais recente por padrão e pede confirmação. Para selecionar um snapshot, use `./scripts/restore.sh --id ID`. A opção `--remove-new` também remove os arquivos que não existiam antes da instalação; revise o snapshot com `--dry-run` antes de usá-la. A restauração salva o estado atual antes de sobrescrevê-lo, permitindo desfazer também essa operação.

Snapshots ficam em `~/.local/share/monolith-dotfiles/backups/`. O manifesto registra quais arquivos foram substituídos e quais foram criados. Logs técnicos ficam em `~/.local/state/monolith-dotfiles/`.

## Importar configurações próprias

A importação é opcional e serve para preparar uma cópia de trabalho a partir de `~/.config`; não é uma etapa necessária para instalar o payload incluído.

```bash
./scripts/import-configs.sh --dry-run
./scripts/import-configs.sh --with-local-bin
```

O importador considera apenas as pastas que reconhece, preserva a estrutura e não apaga arquivos da origem. Ele exclui caches, arquivos de backup do Micro, `fish_variables`, arquivos `.env.fish` gerados e outros artefatos locais; consulte a lista em [Configuração](configuracao.md#arquivos-excluídos-na-importação). Revise tudo que será publicado: a filtragem não identifica todo segredo possível.

## Desinstalar

Para reverter uma instalação, liste os snapshots, identifique o anterior à primeira instalação e simule a restauração:

```bash
./scripts/restore.sh --list
./scripts/restore.sh --id ID_DO_SNAPSHOT --dry-run
./scripts/restore.sh --id ID_DO_SNAPSHOT --remove-new
```

Isso pode restaurar arquivos substituídos e remover os arquivos criados naquele snapshot. Pacotes instalados pelo `pacman` ou pelo AUR não são removidos automaticamente.

## Limitações conhecidas

- Algumas configurações dependem do hardware e do software instalado; confira [Configuração](configuracao.md) antes de iniciar a sessão.
- A disponibilidade de alguns pacotes pode variar entre os repositórios oficiais e o AUR. O instalador consulta os repositórios oficiais antes de recorrer ao auxiliar do AUR.
- A restauração recupera arquivos, não pacotes, serviços ou configurações externas ao payload.
