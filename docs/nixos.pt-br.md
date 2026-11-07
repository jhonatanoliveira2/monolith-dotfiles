# MONOLITH no NixOS

**Português (Brasil)** · [English](nixos.md)

A branch `feature/nixos-support` entrega o MONOLITH Shell como um **flake Nix**: um módulo NixOS para o lado do
sistema, um módulo Home Manager para cada usuário e, só no NixOS, uma experiência de inicialização (tema do GRUB,
splash do Plymouth e um greeter em Quickshell) que leva a identidade do shell do momento em que o computador liga
até a área de trabalho.

Nesta branch o MONOLITH tem suporte **somente ao NixOS** (a versão para Arch Linux / CachyOS fica na `main`).

## Conteúdo

- [Como é construído](#como-é-construído)
- [Instalação](#instalação)
- [Opções](#opções)
- [Boot, splash e login](#boot-splash-e-login)
- [Observações](#observações)
- [Verificação e problemas](#verificação-e-problemas)

## Como é construído

Tudo em `configs/` é usado como está; nada é duplicado para o Nix.

| Parte | Origem | No NixOS |
|---|---|---|
| Shell (barra, menus, configurações) | `configs/.config/quickshell/` | pacote `shell`, ligado como `~/.config/quickshell` |
| Demais configs (Hyprland, fish, ghostty...) | `configs/.config/*` | ligados arquivo a arquivo da Nix store |
| Arquivos que os programas reescrevem (btop, micro, nvim, GTK, wpgtk, HyprMod) | idem | copiados uma vez, graváveis ("semeados") |
| Utilitários de `~/.local/bin` | `configs/.local/bin/` | pacote `scripts` (ferramentas no `PATH`), ligados em `~/.local/bin` |
| Início sem THP | `configs/.config/quickshell/scripts/start.sh` | `monolith-nothp` (poucas linhas de C, sem python3) |
| Pacotes | `nix/packages.nix` | Home Manager (programas do usuário) + serviços do NixOS |
| Identidade do boot | `branding/` | pacotes `branding`, `plymouth-theme`, `grub-theme` |
| Greeter | `greeter/` + `Txt`, `Btn`, `Avatar` do shell | pacote `greeter`, executado pelo greetd |

```
flake.nix
nix/
  meta.nix              versão / revisão mostradas nas Configurações
  packages.nix          programas do usuário, obrigatórios e opcionais
  pkgs/                 shell, scripts, nothp, branding, plymouth-theme, grub-theme, greeter
  modules/home.nix      programs.monolith (Home Manager)
  modules/nixos/        monolith.* (system.nix, boot.nix, greeter.nix)
  checks/               máquina avaliada pelo `nix flake check`
branding/               composição do floco, wordmark, script do Plymouth, modelo do GRUB, build.sh
greeter/                greeter em Quickshell (shell.qml, GreeterWindow.qml, core/Theme.qml)
templates/nixos/        configuração inicial (nix flake init -t)
```

O shell reconhece o NixOS (logo e nome), encontra o plugin RNNoise nos perfis do Nix, oferece a coleta de lixo
do Nix em Configurações > Armazenamento, guarda o limite de carga da bateria em `/var/lib/monolith` (o `/etc` é
somente leitura) e lê `~/.config/monolith/nix.json` (escrito pelo módulo Home Manager) em Configurações >
Sistema e Configurações > Atualização.

## Instalação

### Instalador guiado (ISO do NixOS, recomendado)

Inicie a ISO de instalação do NixOS (a mínima basta), conecte-se à rede e rode:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support#install
```

Ele pergunta o idioma, o disco de destino, usuário, hostname, fuso, locale, teclado, criptografia do disco
(LUKS) e swap, mostra um resumo e só apaga o disco depois que o nome dele é digitado de volta. Então particiona
(GPT + partição EFI de 1 GiB no UEFI, MBR no BIOS), formata em ext4, executa `nixos-generate-config`, preenche o
template com as respostas, instala, define a senha do usuário (o root fica bloqueado: use `sudo`) e reinicia.

- Segurança: o pendrive da ISO, discos montados, discos em uso (swap, LUKS, LVM, RAID) e discos com menos de
  20 GiB nunca são oferecidos; `-- --dry-run` mostra cada comando sem alterar nada.
- Se a instalação parar depois de o disco ser preparado (rede, um erro corrigido na branch), rode o mesmo comando
  de novo: ele oferece retomar e busca a versão mais recente da branch (`--refresh`).
- Depois de instalar: `sudo nixos-rebuild switch --flake /etc/nixos`.

### Pela ISO de instalação do NixOS, à mão

A ISO ainda não tem `/etc/nixos/hardware-configuration.nix`: ele é gerado para o disco de destino depois de
particionar. Os flakes também vêm desligados na ISO, daí o `--extra-experimental-features`. Exemplo para uma
máquina UEFI com um disco inteiro (`/dev/nvme0n1`, **apagado**; confira o nome com `lsblk`):

```bash
sudo -i                                    # tudo abaixo como root
export NIX_CONFIG="experimental-features = nix-command flakes"
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS

# 1. particionar, formatar, montar
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart root ext4 1GiB 100%
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot && mount -o umask=077 /dev/disk/by-label/boot /mnt/boot

# 2. hardware-configuration.nix desta máquina (em /mnt/etc/nixos)
nixos-generate-config --root /mnt

# 3. o template do MONOLITH ao lado (substitui o configuration.nix gerado)
cd /mnt/etc/nixos && rm configuration.nix
nix flake init -t github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support
nano configuration.nix                     # usuário, hostname, fuso, teclado (e BIOS, veja o arquivo)

# 4. instalar, definir a senha do usuário, reiniciar
nixos-install --flake /mnt/etc/nixos#monolith-pc
nixos-enter --root /mnt -c 'passwd alice'  # seu usuário: o greeter precisa de uma senha
reboot
```

Numa máquina BIOS use tabela msdos e só a partição raiz, e no `configuration.nix` defina
`boot.loader.grub.device = "/dev/sda"` (o disco), `efiSupport = false` e remova `canTouchEfiVariables`.

### Num NixOS já instalado

```bash
mkdir ~/nixos && cd ~/nixos
nix --extra-experimental-features "nix-command flakes" flake init -t github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support
cp /etc/nixos/hardware-configuration.nix .
# edite configuration.nix: usuário, hostname, teclado, bootloader (mantenha o que você já usa)
sudo nixos-rebuild switch --flake .#monolith-pc
```

### Flake existente

Adicione a entrada e o módulo e ative as opções.

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
| `boot.gpuModules` | `[ ]` | driver de vídeo no initrd (`i915`, `xe`, `amdgpu`, `nouveau`...): o splash começa na hora e não é cortado quando o driver carrega; o instalador guiado preenche |
| `boot.splashMinSeconds` | `6` | tempo mínimo da tela de carregamento: ao ligar, o splash dura até esse número de segundos após o kernel iniciar (boots rápidos em NVMe); ao reiniciar / desligar, pelo menos esse tempo; `0` = desliga. Valor inicial: **Configurações › Sistema › Inicialização** muda sem rebuild (`/var/lib/monolith/splash-min-seconds`) |
| `boot.grub.enable` | GRUB em uso | tema do GRUB |
| `boot.grub.resolution` | `"1920x1080"` | tamanho para o qual o tema é desenhado; modo preferido do GRUB (com `,auto`) |
| `boot.recovery` | `true` | entrada de boot extra "recovery" (sem splash, verbosa, login em texto) |
| `greeter.enable` | `false` | greeter em Quickshell no greetd |
| `greeter.background` | `null` | wallpaper atrás do login (preto por padrão, contínuo com o splash) |
| `greeter.defaultUser` / `defaultSession` | `null` / `"hyprland"` | usados até um login ser lembrado |
| `greeter.allowOtherUsers` / `consoleSession` | `true` / `true` | digitar outro usuário / sessão "Console" |
| `greeter.clock24`, `animations`, `keyboard` | `true`, `true`, layout xkb | rodapé e comportamento |
| `greeter.output` | `null` | com vários monitores, o que mostra o login (ex.: `"HDMI-A-1"`); os outros mostram o céu. `null` = a tela do notebook, a menos que a tampa esteja fechada; senão o primeiro monitor |
| `greeter.startTimeout`, `fallback` | `25`, `true` | segundos até o greeter em texto (tuigreet) assumir |

### Home Manager (`programs.monolith.*`)

| Opção | Padrão | O que faz |
|---|---|---|
| `enable` | `false` | configs, shell, utilitários e pacotes |
| `optionalPackages` | `true` | o grupo opcional do `nix/packages.nix` (RNNoise, cava, pavucontrol, btop, neovim...) |
| `extraPackages` | `[ ]` | mais pacotes |
| `apps` | `{ browser = "firefox"; }` | programas dos atalhos (`terminal`, `fileManager`, `ide`, `browser`, `lockScreen`) |
| `browserPackage` | `pkgs.firefox` | pacote de `apps.browser` (`null` se instalado de outro jeito, ex.: Zen pelo flake dele) |
| `updateCommand` | `null` | o que Configurações > Atualização > Atualizar agora executa num terminal |
| `mutableFiles` | btop, micro, nvim, nwg-look, GTK, wpg, HyprMod | copiados em vez de ligados |
| `fetch.enable` | `true` | [fetch](https://github.com/areofyl/fetch): o logo do NixOS girando em 3D ao lado das informações do sistema, nos cinzas do MONOLITH (`~/.config/fetch/`). Rode `fetch`; qualquer tecla para, o mouse gira o logo |
| `fetch.atShellStart` | `false` | roda o `fetch` ao abrir o fish (não no console Linux; `MONOLITH_NO_FETCH=1` pula) |
| `fetch.shadingMode`, `extraConfig` | `"ascii"`, `""` | `ascii` (o relevo de `#`), `blocks` ou `sextants` (mais nítido, Ghostty / Kitty); linhas extras para `~/.config/fetch/config` (ex.: `"speed=1.2"`) |
| `wallpapers` | `true` | copia `wallpapers/` para `~/Pictures/Wallpapers` e `~/Videos/wallpaper-live` |
| `gtk` | `true` | `Materia-dark` e o esquema de cores escuro (dconf) |

## Boot, splash e login

As três etapas seguem uma linha visual: preto, o **floco de neve do NixOS desenhado no estilo Monolith** (cinza
claro, um halo discreto, sobre um horizonte iluminado), o wordmark `MONOLITH` em JetBrains Mono e uma linha de 2 px.

1. **GRUB**: marca e wordmark no topo, entradas em cinza, a selecionada em branco numa moldura fina (como as
   linhas selecionadas do shell). O tempo limite é a linha de 2 px, esvaziando. As teclas aparecem embaixo.
   Escolhida a entrada, a tela fica preta só com o floco pequeno no canto inferior direito enquanto o kernel
   carrega, até o splash assumir.
2. **Plymouth**: a marca aparece no centro com um bloom que "respira", uma faixa de luz a atravessa logo de
   início e depois a cada ~2 s, e a linha (com brilho próprio) enche com o progresso do boot. Desligar e reiniciar
   mostram a marca na hora. Senhas de disco e perguntas ocupam o lugar da linha; mensagens do systemd aparecem
   embaixo.
3. **Greeter**: abre no último quadro do Plymouth (mesmo lugar, mesmo tamanho) — o splash fica na tela até
   lá (`plymouth quit --retain-splash`) — então a marca sobe e fica branca com bloom e light sweep, a linha some, surge
   um céu noturno (poeira estelar e estrelas descendo em duas camadas, cintilações, brilhos em cruz, estrelas
   cadentes cujo bloom diminui enquanto cruzam o céu) e o login minimalista aparece: relógio,
   usuário, uma linha de senha que brilha ao focar, a sessão e três ícones de energia. Um login bem-sucedido
   intensifica o bloom, escurece a tela e inicia a sessão.

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

Com LUKS nada mais é necessário: o initrd é sempre baseado em systemd (o stage 1 em script e as opções
`boot.initrd.verbose` / `boot.initrd.systemd.enable` foram removidos do nixpkgs) e pede a senha pelo splash.

Os scripts e imagens do splash são gerados de `branding/` por `branding/build.sh`, que pode ser executado à mão
para pré-visualizar (precisa de `rsvg-convert`, `magick`, `grub-mkfont` e do SVG do floco do `nixos-icons`).

## Observações

- **Atualizações:** Configurações > Atualização compara a revisão fixada com o GitHub; "Atualizar agora"
  executa `programs.monolith.updateCommand` num terminal (flake update + rebuild).
- **Armazenamento:** Configurações > Armazenamento faz a coleta de lixo do Nix (`nix-collect-garbage
  --delete-older-than 14d`, usuário + sistema) e mantém as gerações recentes.
- **Bateria:** o limite de carga fica em `/var/lib/monolith/charge-limit` e é aplicado no boot por
  `monolith-charge-limit.service`.
- **Navegador:** `apps.browser` (Firefox por padrão; o Zen não está no nixpkgs, use o flake dele e
  `browserPackage = null`).
- **THP:** o shell inicia pelo `monolith-nothp` (sem python3).

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
- **Sem splash com LUKS**: confira `monolith.boot.plymouth.enable` e se o driver de vídeo carrega no initrd
  (`boot.initrd.kernelModules`, ex.: `amdgpu`, `i915`).
- **Texto do GRUB pequeno ou grande demais**: ajuste `monolith.boot.grub.resolution` para a resolução da tela.
