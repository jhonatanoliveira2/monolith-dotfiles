# Instalação e recuperação

[English](installation.md) · **Português (Brasil)**

Este guia instala as configurações já incluídas no repositório. Não é necessário importar arquivos da sua pasta pessoal para começar.

## Requisitos

- Arch Linux ou derivada que use `pacman`.
- Bash 4.4+, Git e uma conta de usuário comum. O instalador recusa execução como root.
- Hyprland 0.55 ou superior para a configuração Lua incluída.
- `paru` ou `yay` somente se quiser compilar pacotes do AUR automaticamente. Sem um auxiliar, o instalador mostra os comandos para instalação manual.

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

## Opções do instalador

| Opção | Efeito |
|---|---|
| `--lang en\|pt_BR` | Escolhe o idioma da interface e ignora a seleção interativa. Também aceita `MONOLITH_LANG`. |
| `-y`, `--yes` | Aceita os padrões sem perguntar; pacotes opcionais não são incluídos. |
| `-n`, `--dry-run` | Mostra o que seria feito sem aplicar alterações. |
| `--no-deps` | Não instala pacotes. |
| `--with-optional` | Inclui os pacotes opcionais de `packages.txt`. |
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
