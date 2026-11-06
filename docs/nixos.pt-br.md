# MONOLITH no NixOS

**Português (Brasil)** · [English](nixos.md)

A branch `feature/nixos-support` entrega o MONOLITH Shell como um **flake Nix**: um módulo NixOS para o lado do
sistema, um módulo Home Manager para cada usuário e, só no NixOS, uma experiência de inicialização (tema do GRUB,
splash do Plymouth e um greeter em Quickshell) que leva a identidade do shell do momento em que o computador liga
até a área de trabalho.

O instalador do Arch Linux / CachyOS continua intacto e funciona a partir desta branch; no NixOS ele para e
aponta para cá, porque copiar arquivos para o `$HOME` brigaria com o Home Manager.

## Conteúdo

- [Como é construído](#como-é-construído)
- [Instalação](#instalação)
- [Opções](#opções)
- [Boot, splash e login](#boot-splash-e-login)
- [Diferenças em relação ao Arch](#diferenças-em-relação-ao-arch)
- [Verificação e problemas](#verificação-e-problemas)

## Como é construído

Uma única árvore de arquivos serve às duas distribuições; nada em `configs/` é duplicado para o Nix.

| Parte | Origem | No NixOS |
|---|---|---|
| Shell (barra, menus, configurações) | `configs/.config/quickshell/` | pacote `shell`, ligado como `~/.config/quickshell` |
| Demais configs (Hyprland, fish, ghostty...) | `configs/.config/*` | ligados arquivo a arquivo da Nix store |
| Arquivos que os programas reescrevem (btop, micro, nvim, GTK, wpgtk, HyprMod) | idem | copiados uma vez, graváveis ("semeados") |
| Utilitários de `~/.local/bin` | `configs/.local/bin/` | pacote `scripts` (ferramentas no `PATH`), ligados em `~/.local/bin` |
| Início sem THP | `configs/.config/quickshell/scripts/start.sh` | `monolith-nothp` (poucas linhas de C, sem python3) |
| Pacotes | `packages.txt` | `nix/packages.nix` (mesmos grupos) + serviços do NixOS |
| Identidade do boot | `branding/` | pacotes `branding`, `plymouth-theme`, `grub-theme` |
| Greeter | `greeter/` + `Txt`, `Btn`, `Avatar` do shell | pacote `greeter`, executado pelo greetd |

```
flake.nix
nix/
  meta.nix              versão / revisão mostradas nas Configurações
  packages.nix          o packages.txt do NixOS
  pkgs/                 shell, scripts, nothp, branding, plymouth-theme, grub-theme, greeter
  modules/home.nix      programs.monolith (Home Manager)
  modules/nixos/        monolith.* (system.nix, boot.nix, greeter.nix)
  checks/               máquina avaliada pelo `nix flake check`
branding/               composição do floco, wordmark, script do Plymouth, modelo do GRUB, build.sh
greeter/                greeter em Quickshell (shell.qml, GreeterWindow.qml, core/Theme.qml)
templates/nixos/        configuração inicial (nix flake init -t)
```

O shell só ganhou comportamentos neutros quanto à distribuição, então o Arch continua funcionando: ele reconhece
o NixOS (logo e nome), encontra o plugin RNNoise nos perfis do Nix, oferece a coleta de lixo do Nix em
Configurações > Armazenamento, guarda o limite de carga da bateria em `/var/lib/monolith` quando o `/etc` é
somente leitura e lê `~/.config/monolith/nix.json` (escrito pelo módulo Home Manager) em Configurações > Sistema
e Configurações > Atualização.

## Instalação

**Configuração nova** (um flake com NixOS + Home Manager + MONOLITH):

```bash
mkdir ~/nixos && cd ~/nixos
nix flake init -t github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support
cp /etc/nixos/hardware-configuration.nix .
# edite configuration.nix: usuário, hostname, teclado, bootloader
sudo nixos-rebuild switch --flake .#monolith-pc
```

**Flake existente:** adicione a entrada e o módulo e ative as opções.

```nix
inputs.monolith = {
  url = "github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
};
# em nixosSystem { modules = [ ... ]; }
home-manager.nixosModules.home-manager
monolith.nixosModules.default
```

```nix
monolith = {
  enable = true;
  homeUsers = [ "alice" ];
  boot.enable = true;
  greeter.enable = true;
};
home-manager.backupFileExtension = "pre-monolith";
```

O Home Manager avulso também funciona: importe `monolith.homeManagerModules.default` e defina
`programs.monolith.enable = true`; o sistema ainda precisa de `programs.hyprland.enable` (ou `monolith.enable`).

> Arquivos que já existem em `~/.config` (de uma instalação manual) bloqueiam o Home Manager.
> `backupFileExtension` os renomeia em vez de falhar.

## Opções

### NixOS (`monolith.*`)

| Opção | Padrão | O que faz |
|---|---|---|
| `enable` | `false` | Hyprland, PipeWire, NetworkManager, Bluetooth + Blueman, UPower, udisks2, power-profiles-daemon, gvfs, polkit, portais (Hyprland + GTK), PAM do hyprlock, fontes, gpu-screen-recorder |
| `language` | `"pt"` | `pt` ou `en`: GRUB, mensagens do Plymouth, greeter |
| `homeUsers` | `[ ]` | usuários que recebem `programs.monolith.enable` (módulo NixOS do Home Manager) |
| `battery.chargeLimit` | `null` | limite de carga inicial em %; Configurações > Bateria muda depois |
| `gpuScreenRecorder` | `true` | gravação com SUPER+R, com as capabilities necessárias |
| `boot.enable` | `false` | a experiência de boot abaixo |
| `boot.silent` | `true` | `quiet` e níveis de log baixos (as mensagens ficam no journal) |
| `boot.plymouth.enable` | `true` | splash do MONOLITH, inclusive para senhas LUKS |
| `boot.seamless` | `true` | o último quadro do splash fica na tela até o greeter desenhar o mesmo quadro |
| `boot.grub.enable` | GRUB em uso | tema do GRUB |
| `boot.grub.resolution` | `"1920x1080"` | tamanho para o qual o tema é desenhado; modo preferido do GRUB (com `,auto`) |
| `boot.recovery` | `true` | entrada de boot extra "recovery" (sem splash, verbosa, login em texto) |
| `greeter.enable` | `false` | greeter em Quickshell no greetd |
| `greeter.background` | `null` | wallpaper atrás do login (preto por padrão, contínuo com o splash) |
| `greeter.defaultUser` / `defaultSession` | `null` / `"hyprland"` | usados até um login ser lembrado |
| `greeter.allowOtherUsers` / `consoleSession` | `true` / `true` | digitar outro usuário / sessão "Console" |
| `greeter.clock24`, `animations`, `keyboard` | `true`, `true`, layout xkb | rodapé e comportamento |
| `greeter.startTimeout`, `fallback` | `25`, `true` | segundos até o greeter em texto (tuigreet) assumir |

### Home Manager (`programs.monolith.*`)

| Opção | Padrão | O que faz |
|---|---|---|
| `enable` | `false` | configs, shell, utilitários e pacotes |
| `optionalPackages` | `true` | o grupo opcional do `packages.txt` (RNNoise, cava, pavucontrol, btop, neovim...) |
| `extraPackages` | `[ ]` | mais pacotes |
| `apps` | `{ browser = "firefox"; }` | programas dos atalhos (`terminal`, `fileManager`, `ide`, `browser`, `lockScreen`) |
| `browserPackage` | `pkgs.firefox` | pacote de `apps.browser` (`null` se instalado de outro jeito, ex.: Zen pelo flake dele) |
| `updateCommand` | `null` | o que Configurações > Atualização > Atualizar agora executa num terminal |
| `mutableFiles` | btop, micro, nvim, nwg-look, GTK, wpg, HyprMod | copiados em vez de ligados |
| `wallpapers` | `true` | copia `wallpapers/` para `~/Pictures/Wallpapers` e `~/Videos/wallpaper-live` |
| `gtk` | `true` | `Materia-dark` e o esquema de cores escuro (dconf) |

## Boot, splash e login

As três etapas seguem uma linha visual: preto, o **floco de neve do NixOS desenhado no estilo Monolith** (cinza
claro, um halo discreto, sobre um horizonte iluminado), o wordmark `MONOLITH` em JetBrains Mono e uma linha de 2 px.

1. **GRUB**: marca e wordmark no topo, entradas em cinza, a selecionada em branco numa moldura fina (como as
   linhas selecionadas do shell). O tempo limite é a linha de 2 px, esvaziando. As teclas aparecem embaixo.
2. **Plymouth**: a marca surge no centro, uma faixa de luz a atravessa a cada poucos segundos e a linha enche
   com o progresso do boot. Senhas de disco e perguntas ocupam o lugar da linha; mensagens do systemd aparecem
   embaixo.
3. **Greeter**: abre no último quadro do Plymouth (mesmo lugar, mesmo tamanho) — o splash fica na tela até
   lá (`plymouth quit --retain-splash`) — então a marca sobe, a linha some e o relógio e o login aparecem.
   Um login bem-sucedido passa a faixa de luz, escurece a tela e inicia a sessão.

O greeter autentica pelo PAM (greetd): prompts extras (segundo fator, senha expirada) aparecem no mesmo campo.
Cima / Baixo escolhem o usuário, Ctrl+Esquerda / Direita a sessão, Esc cancela. O último usuário e a última
sessão ficam em `/var/lib/monolith-greeter`. As fotos de perfil vêm do AccountsService.

**Caminhos de recuperação**

- O GRUB mantém todas as gerações, o tempo limite configurado, `e` (editar a linha do kernel, ex.: tirar
  `quiet`) e `c`.
- A entrada **recovery** inicia o mesmo sistema sem splash nem greeter gráfico, com todas as mensagens.
- Esc durante o splash mostra o log do boot.
- Se o greeter não carregar ou não mostrar nada dentro de `greeter.startTimeout`, o **tuigreet** assume.
- A sessão "Console" dá um shell de login; Ctrl+Alt+F2… levam aos outros consoles.
- Cada etapa pode ser desligada sozinha (`boot.plymouth.enable`, `boot.grub.enable`, `greeter.enable`).

Com LUKS, `boot.initrd.systemd.enable = true` dá o prompt de senha mais limpo no splash; não é forçado porque
muda a forma como o initrd executa scripts personalizados.

Os scripts e imagens do splash são gerados de `branding/` por `branding/build.sh`, que pode ser executado à mão
para pré-visualizar (precisa de `rsvg-convert`, `magick`, `grub-mkfont` e do SVG do floco do `nixos-icons`).

## Diferenças em relação ao Arch

| Arch / CachyOS | NixOS |
|---|---|
| `scripts/install.sh` copia `configs/` e instala pacotes | o flake: o Home Manager liga os arquivos, o NixOS ativa os serviços |
| Configurações > Atualização: `git pull` + instalador | compara a revisão fixada com o GitHub; "Atualizar agora" executa `programs.monolith.updateCommand` |
| Configurações > Armazenamento: caches do pacman / paru / yay | coleta de lixo da Nix store (`nix-collect-garbage --delete-older-than 14d`, usuário + sistema), mantém gerações recentes |
| limite de carga mantido por regra udev em `/etc` | guardado em `/var/lib/monolith/charge-limit`, aplicado no boot por `monolith-charge-limit.service` |
| botão "Instalar" do RNNoise (pacman) | plugin instalado por `optionalPackages`; encontrado nos perfis do Nix |
| `start.sh` usa python3 para o THP | `monolith-nothp` |
| AUR: awww, mpvpaper, wpgtk, Material Icons | nixpkgs: `awww`, `mpvpaper`, `wpgtk`, `material-icons` |
| `zen-browser-bin` | fora do nixpkgs: `apps.browser` (Firefox por padrão) |
| boot e login sem mudanças | tema do GRUB, splash do Plymouth, greeter (`monolith.boot`, `monolith.greeter`) |

Editar um arquivo ligado não funciona (ele está na store, somente leitura): altere no seu fork do repositório ou
coloque-o em `mutableFiles`. Tudo o que o app de Configurações escreve (`~/.config/hypr/generated/`,
`~/.local/state/quickshell-monolith/`) continua gravável.

## Verificação e problemas

```bash
nix flake check                         # compila todos os pacotes e avalia uma máquina de exemplo completa
nix build .#greeter .#grub-theme        # um pacote
nixos-rebuild build-vm --flake .#host   # testa o boot inteiro numa VM
```

- **"Existing file ... is in the way"**: defina `home-manager.backupFileExtension`.
- **O shell não pegou a versão nova**: o Home Manager troca `~/.config/quickshell` atomicamente; reinicie o shell
  (saia da sessão, ou `pkill quickshell` e abra pelo lançador).
- **O greeter caiu para o de texto**: `journalctl -u greetd -b` mostra o motivo (o wrapper registra o status).
- **Sem splash com LUKS**: tente `boot.initrd.systemd.enable = true`; confira `boot.plymouth.enable`.
- **Texto do GRUB pequeno ou grande demais**: ajuste `monolith.boot.grub.resolution` para a resolução da tela.
