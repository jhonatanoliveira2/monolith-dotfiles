# Instalação

[Português (Brasil)](instalacao.md) · [English](installation.md)

## Sumário
- [Requisitos](#requisitos) · [Passo a passo](#passo-a-passo) · [Opções do instalador](#opções-do-instalador)
- [Como o instalador funciona](#como-o-instalador-funciona) · [Seleção de idioma](#seleção-de-idioma)
- [Backup e recuperação](#backup-e-recuperação) · [Estrutura do repositório](#estrutura-do-repositório)
- [Desinstalar](#desinstalar) · [Limitações conhecidas](#limitações-conhecidas)

## Requisitos

- Arch Linux (ou derivada com `pacman`), **Bash 4.4+**, `git`, `sudo` (apenas para o `pacman`).
- **Hyprland 0.55 ou superior** (configuração em Lua, `hyprland.lua`) — as configurações usam a API `hl.*`.
- Um auxiliar do AUR (`paru` ou `yay`) **se** quiser que os pacotes do AUR sejam instalados
  automaticamente. Sem ele, o instalador apenas mostra os comandos.
- Usuário comum: o instalador **recusa** rodar como root.

## Passo a passo

```bash
git clone https://github.com/SEU_USUARIO/monolith-dotfiles.git
cd monolith-dotfiles
```

**1. Copie suas configurações para o repositório.** O repositório vem sem elas, de propósito.

```bash
./scripts/import-configs.sh --with-local-bin     # recomendado
```

O script copia somente as pastas esperadas (`hypr waybar fish ghostty fastfetch btop swaync nvim micro
gtk-3.0 gtk-4.0 nwg-look wal wpg`), preserva a hierarquia e o conteúdo, e **não importa** arquivos
privados ou gerados (lista em [configuracao.md](configuracao.md#arquivos-deixados-de-fora)). Se preferir,
copie à mão para `configs/.config/` — o resultado é o mesmo. Depois confira `git status` e leia o que
vai ser publicado.

**2. Simule.**

```bash
./scripts/install.sh --dry-run
```

**3. Instale.**

```bash
./scripts/install.sh
```

Ao final, ajuste o que for específico do seu hardware (monitores etc. —
[configuracao.md](configuracao.md#itens-específicos-da-máquina)) e reinicie a sessão.

## Opções do instalador

| Opção | Efeito |
|---|---|
| `--lang en\|pt_BR` | Define o idioma e pula o menu (também: variável `MONOLITH_LANG`) |
| `-y`, `--yes` | Não pergunta nada; usa os padrões (opcionais **não** são instalados) |
| `-n`, `--dry-run` | Mostra o que seria feito, sem alterar nada |
| `--no-deps` | Não instala pacotes |
| `--with-optional` | Instala também os pacotes opcionais de `packages.txt` |
| `--no-aur` | Nunca usa auxiliar do AUR (imprime os comandos) |
| `--aur-helper NOME` | Usa esse auxiliar (padrão: `paru`, depois `yay`) |
| `--force-symlinks` | Permite gravar através de diretórios que são links simbólicos |
| `--no-color`, `--no-clear` | Sem cores / sem limpar a tela |
| `--version`, `-h` | Versão / ajuda |

Sem terminal interativo (por exemplo em um pipe), o instalador **exige** `--yes`.

## Como o instalador funciona

| # | Etapa | O que faz |
|---|---|---|
| 1 | Verificar o sistema | Recusa root; checa Bash, Arch, destino gravável, links simbólicos e se `configs/` tem arquivos |
| 2 | Revisar dependências | Relatório de pacotes e de arquivos referenciados que faltam (`check-dependencies.sh`) |
| 3 | Instalar pacotes | `pacman -S --needed` (oficiais) e auxiliar do AUR; pede confirmação |
| 4 | Planejar | Classifica cada arquivo: **novo**, **substituir** ou **já atualizado** |
| 5 | Backup | `backup.sh` copia os arquivos que serão substituídos e grava um manifesto |
| 6 | Copiar | Cada arquivo é escrito de forma atômica (arquivo temporário + renomeação) |
| 7 | Verificar | Compara cada arquivo copiado com o repositório (`cmp`), restaura o bit de execução de scripts e cria as pastas `~/Pictures/Wallpapers` e `~/Videos/wallpaper-live` se não existirem |

Garantias:

- **Nada em `$HOME` é tocado antes do backup dar certo.** A instalação de pacotes vem antes e, se falhar,
  nenhuma configuração foi alterada.
- **Reversão automática:** se qualquer cópia falhar (ou você interromper com Ctrl+C), os arquivos já
  gravados são desfeitos — os substituídos voltam do backup, os novos são removidos.
- **Idempotente:** arquivos idênticos são ignorados; sem mudanças, nenhum backup é criado.
- **Aditivo:** arquivos seus que não existem no repositório **nunca** são apagados.
- **Sem `pacman -Sy`:** o instalador não faz atualização parcial; se um pacote não for encontrado, rode
  `sudo pacman -Syu` e tente de novo.
- **Sem mudanças globais:** não troca seu shell de login, não habilita serviços, não gera locales,
  não edita `/etc`. Quando algo disso é necessário, aparece como aviso.
- O log técnico (em inglês) fica em `~/.local/state/monolith-dotfiles/install-*.log`.

Códigos de saída: `0` ok · `1` erro/sem terminal · `2` `configs/` vazio · `3` cancelado · `4` pré-requisito
(root, link simbólico, conflito) · `5` falha do `pacman` · `6` falha no backup · `7` falha ao copiar (revertido).

## Seleção de idioma

Ordem de decisão: `--lang` → variável `MONOLITH_LANG` → **menu** (em terminal interativo; sugere o idioma
do sistema, `pt_BR` se `LANG`/`LC_ALL` começar com `pt`, senão inglês) → em modo não interativo, o idioma do
sistema → **inglês** (padrão). O menu aceita Enter para o idioma sugerido.
Somente as mensagens para o usuário são traduzidas; scripts, comentários, variáveis e logs ficam em inglês.
As mensagens vivem em `scripts/lib/messages.sh` (uma linha por chave, com os dois idiomas lado a lado).

## Backup e recuperação

Cada execução que precisa substituir ou criar arquivos grava um *snapshot*:

```text
~/.local/share/monolith-dotfiles/backups/20261010-153012/
├── manifest.tsv        # replace<TAB>caminho  (foi copiado para files/)  |  new<TAB>caminho  (não existia)
└── files/.config/…     # cópias originais; links simbólicos continuam links simbólicos
```

O diretório é privado (`700`). Comandos:

```bash
./scripts/backup.sh --list                           # lista os snapshots
./scripts/backup.sh                                  # snapshot manual de tudo que o repositório gerencia
./scripts/restore.sh                                 # restaura o mais recente (pede confirmação)
./scripts/restore.sh --id 20261010-153012            # restaura um específico
./scripts/restore.sh --remove-new                    # também remove os arquivos que o instalador criou
./scripts/restore.sh --dry-run                       # só mostra
```

O `restore.sh` salva o estado atual **antes** de sobrescrever, então uma restauração também pode ser
desfeita. **Recuperação manual:** copie de `.../files/<caminho>` para o mesmo caminho dentro de `~`
(por exemplo `cp -a ~/.local/share/monolith-dotfiles/backups/ID/files/.config/hypr ~/.config/`).

## Estrutura do repositório

Veja a árvore completa e o papel de cada pasta em [configuracao.md](configuracao.md#estrutura-do-repositório).

## Desinstalar

```bash
./scripts/restore.sh --id ID_DO_PRIMEIRO_BACKUP --remove-new
```

Isso devolve os arquivos substituídos e remove os criados pelo instalador naquela execução. Pacotes
instalados pelo `pacman`/AUR **não** são removidos (use `pacman -Rns` por conta própria).

## Limitações conhecidas

- Pacotes marcados como AUR podem já estar nos repositórios oficiais (o instalador consulta `pacman -Si` primeiro).
- O instalador não valida a **versão** do Hyprland nem se o `rofi` instalado tem backend Wayland.
- Uma restauração restaura **arquivos**, não pacotes nem serviços.
- Em terminais sem UTF-8 ou sem cores a interface cai para ASCII simples; a arte do banner só aparece em UTF-8.
