
<p align="center">
  <img src="assets/logo/banner.svg" alt="MONOLITH Dotfiles" width="100%">
</p>

<p align="center">
  <b>Português (Brasil)</b> · <a href="README.md">English</a>
</p>

<p align="center">
  <img alt="Plataforma: Arch Linux" src="https://img.shields.io/badge/platform-Arch_Linux-00e5ff?style=flat-square&labelColor=14161a&logo=archlinux&logoColor=white">
  <img alt="Gerenciador de janelas: Hyprland" src="https://img.shields.io/badge/WM-Hyprland-00e5ff?style=flat-square&labelColor=14161a">
  <img alt="Shell: Bash" src="https://img.shields.io/badge/shell-Bash-8b9099?style=flat-square&labelColor=14161a">
  <img alt="Documentação: português e inglês" src="https://img.shields.io/badge/docs-PT--BR_%7C_EN-8b9099?style=flat-square&labelColor=14161a">
  <img alt="Licença: ainda não definida" src="https://img.shields.io/badge/license-not_yet_defined-555b63?style=flat-square&labelColor=14161a">
</p>

# MONOLITH Dotfiles

Um ambiente **Arch Linux + Hyprland** minimalista. O MONOLITH reúne configuração do compositor em Lua, barra de status, notificações, lançador, terminal, shell, editores e temas — além de um instalador de terminal que cria backups antes de substituir arquivos existentes.

## Conteúdo

- [Destaques](#destaques)
- [Ambiente testado](#ambiente-testado)
- [Configurações incluídas](#configurações-incluídas)
- [Início rápido](#início-rápido)
- [Dependências](#dependências)
- [Backup e recuperação](#backup-e-recuperação)
- [Prévia do instalador](#prévia-do-instalador)
- [Documentação](#documentação)
- [Estrutura do repositório](#estrutura-do-repositório)

## Destaques

- **Instalador bilíngue:** inglês por padrão, com opção de português do Brasil; inclui tela de boas-vindas, seleção de idioma, sete etapas, barras de progresso e resumo final.
- **Backup antes de substituir:** salva cada arquivo diferente, reverte automaticamente as cópias se houver falha e oferece um comando de restauração (`scripts/restore.sh`).
- **Instalação idempotente:** ao executar novamente, ignora arquivos que já são idênticos e evita backups desnecessários.
- **Sem instalação como root:** `sudo` é usado somente para instalar pacotes com `pacman`. O instalador não altera seu shell de login, serviços nem o locale do sistema; ele apenas exibe avisos sobre esses itens.
- **Dependências objetivas:** pacotes oficiais, do AUR e manuais estão separados e justificados em [`packages.txt`](packages.txt) e na [análise de dependências](docs/dependencias.md).
- **Menu de wallpapers:** abra o menu do Rofi com `SUPER+D` para escolher wallpapers estáticos (`awww`) ou animados (`mpvpaper`).
- **Importação de configurações:** `import-configs.sh` copia pastas selecionadas de `~/.config` para o repositório, deixando de fora conteúdo privado ou específico da máquina.

## Ambiente testado

| Componente | Ambiente validado |
|---|---|
| Sistema operacional | Arch Linux, instalação mínima |
| Hyprland | 0.55 ou superior (configuração em Lua) |
| CPU | AMD Ryzen 7 5700X |
| GPU | AMD Radeon RX 9060 XT |

## Configurações incluídas

| Pasta | Conteúdo |
|---|---|
| `hypr/` | Hyprland em **Lua** (módulos), hyprlock, portal XDPH, lançador Rofi e menu de wallpapers |
| `waybar/` | Barra de status e scripts para player, rede, monitor do sistema, perfil de energia e menu de áudio; inclui tema do Rofi |
| `swaync/` | Central de notificações |
| `ghostty/` | Terminal e shaders de cursor |
| `fish/` | Configuração do shell com Starship e Atuin |
| `fastfetch/` | Informações do sistema com logos aleatórios |
| `btop/`, `micro/`, `nvim/` | Monitor de recursos e editores (Neovim com LazyVim) |
| `gtk-3.0/`, `gtk-4.0/`, `nwg-look/` | Configurações de tema GTK |
| `wal/`, `wpg/` | Esquemas de cores derivados do wallpaper |

Consulte [Configuração](docs/configuracao.md) para ver os detalhes de cada pasta, itens específicos da máquina e lacunas conhecidas.

## Início rápido

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles.git
cd monolith-dotfiles

# Permissões de execução.
chmod +x scripts/*.sh

# Aplique a instalação.
./scripts/install.sh
```

O instalador também cria estas pastas para wallpapers:

- `~/Pictures/Wallpapers` para imagens estáticas
- `~/Videos/wallpaper-live` para vídeos animados `.mp4`

<details>
<summary><strong>Opções do instalador</strong></summary>

| Opção | Finalidade |
|---|---|
| `--lang pt_BR` | Executar o instalador em português do Brasil |
| `--yes` | Pular as confirmações interativas |
| `--no-deps` | Não instalar dependências |
| `--with-optional` | Incluir pacotes opcionais |
| `--no-aur` | Ignorar pacotes do AUR |

Consulte o [guia completo de instalação](docs/instalacao.md) para ver todas as etapas.

</details>

## Dependências

As dependências obrigatórias, opcionais e manuais estão listadas em [`packages.txt`](packages.txt), com a justificativa de cada item. Você pode verificar o sistema a qualquer momento:

```bash
./scripts/check-dependencies.sh
```

Para entender os critérios usados na lista de pacotes, consulte a [análise de dependências](docs/dependencias.md).

## Backup e recuperação

Os backups são armazenados em `~/.local/share/monolith-dotfiles/backups/<data-hora>/`.

```bash
./scripts/backup.sh --list                             # Lista os backups disponíveis
./scripts/restore.sh                                   # Restaura o backup mais recente
./scripts/restore.sh --id AAAAMMDD-HHMMSS --remove-new # Restaura um backup e remove arquivos adicionados depois
```

Consulte [Backup e recuperação](docs/instalacao.md#backup-e-recuperação) para obter mais detalhes e instruções de recuperação manual.

## Prévia do instalador

<p align="center">
  <img src="assets/previews/installer-welcome.svg" alt="Tela de boas-vindas do instalador MONOLITH" width="640">
</p>

## Documentação

- [Instalação](docs/instalacao.md)
- [Configuração](docs/configuracao.md)
- [Dependências](docs/dependencias.md)
- [Solução de problemas](docs/solucao-de-problemas.md)
- [Contribuição](CONTRIBUTING.md)

## Estrutura do repositório

```text
monolith-dotfiles/
├── configs/.config/…      # Suas configurações → ~/.config
├── configs/.local/bin/    # Scripts usados pelos atalhos → ~/.local/bin
├── scripts/               # Instalação, backup, restauração, verificações e importação
│   └── lib/                # Interface, traduções, mensagens, pacotes e utilitários
├── docs/                   # Documentação em português do Brasil e inglês
├── assets/                 # Logo, capturas de tela e prévias
├── tests/                  # Testes do instalador
├── tools/                  # Gerador de prévias SVG
├── packages.txt            # Dependências oficiais, AUR e manuais
└── .github/                # Modelos de issues e pull requests; CI
```
