# MONOLITH no NixOS

**Português (Brasil)** · [English](nixos.md)

No NixOS o MONOLITH Shell é instalado como um **flake Nix**: um módulo NixOS para o lado do
sistema, um módulo Home Manager para cada usuário e, só no NixOS, uma experiência de inicialização (tema do GRUB,
splash do Plymouth e um greeter em Quickshell) que leva a identidade do shell do momento em que o computador liga
até a área de trabalho.

Este guia trata do **NixOS**; Arch Linux e CachyOS usam o instalador em shell ([instalacao.md](instalacao.md)).

## Conteúdo

- [Como é construído](#como-é-construído)
- [Instalação](#instalação)
- [Opções](#opções)
- [Boot, splash e login](#boot-splash-e-login)
- [Observações](#observações)
- [Modo de desenvolvimento](#modo-de-desenvolvimento)
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
  run github:jhonatanoliveira2/monolith-dotfiles#install
```

Ele pergunta o idioma, o disco de destino, usuário, hostname, fuso, locale, teclado, criptografia do disco
(LUKS), swap e o tema (padrão ou [Nothing](nothing-theme.pt-br.md): `monolith.nothingTheme.enable`;
`-- --theme default|nothing` pula a pergunta), mostra um resumo e só apaga o disco depois que o nome dele é digitado de volta. Então particiona
(GPT + partição EFI de 1 GiB no UEFI, MBR no BIOS), formata em ext4, executa `nixos-generate-config`, preenche o
template com as respostas, instala, define a senha do usuário (o root fica bloqueado: use `sudo`) e reinicia.

- O visual segue a branch (`MONOLITH_INSTALL_THEME=monolith|nothing` muda); sem cores fora de um terminal ou
  com `NO_COLOR`.
- **Onde instalar**: *um disco inteiro* (apagado, como acima) ou *partições existentes*, ao lado de outro
  sistema (Windows, outro Linux). No segundo modo só a partição escolhida para o NixOS (20 GiB ou mais) é
  formatada (ext4); no UEFI uma partição EFI existente é mantida como está e montada em `/boot/efi` (os kernels
  ficam no ext4 do sistema, então até a ESP de 100 MiB do Windows basta); sem uma, uma partição **vazia** que
  você escolher vira a ESP do NixOS. Sem LUKS nesse modo; crie a partição antes (gparted, cfdisk, ou reduza a
  do Windows pelo próprio Windows).
- **Dual boot: o boot do outro sistema nunca é tocado.**
  - Todas as partições são lidas antes, só para leitura (o próprio dispositivo fica somente leitura enquanto é
    examinado, e journals não são reaplicados). Partições com um sistema (`os-release`, Windows), o `/boot` de
    outro sistema, uma ESP, LUKS / LVM / RAID ou uma swap aparecem como *protegidas* e nunca são oferecidas; uma
    com outros arquivos pode ser escolhida, mas só digitando `APAGAR` além do nome dela. A swap de um sistema
    hibernado interrompe o instalador antes de qualquer escrita.
  - UEFI: o GRUB do NixOS vai só para a própria pasta `EFI/NixOS-*` (`canTouchEfiVariables = false`, ou seja,
    `grub-install --no-nvram`, agora e em todo rebuild). A ordem de boot do firmware registrada antes da
    instalação é restaurada com o NixOS no **fim** dela: o outro sistema continua sendo o padrão. Todos os
    arquivos que já estavam numa ESP compartilhada são conferidos (checksum) e copiados
    (`/var/lib/monolith-install/esp-before.tar`) antes da instalação e verificados depois; o que mudou fora da
    pasta do NixOS é restaurado.
  - O os-prober **não** é usado: as entradas que ele adivinha para outro Linux (Arch com o kernel na ESP,
    microcode como primeiro initrd) podem iniciá-lo com o kernel / initrd errados, o que termina em kernel
    panic. Os carregadores dos outros sistemas na ESP entram no menu do NixOS por chainload
    (`boot.loader.grub.extraEntries`).
  - BIOS: o MBR não é alterado (`device = "nodev"`, o GRUB só grava `/boot/grub/grub.cfg`), a não ser que você
    peça para substituí-lo.
  - `/etc/nixos/DUAL-BOOT.txt` traz a entrada para acrescentar o NixOS ao GRUB do outro sistema
    (`/etc/grub.d/40_custom`); até lá ele inicia pelo menu de boot do firmware (F12 / F11 / F8 / Esc) ->
    "NixOS MONOLITH".
  - Instalou com uma versão anterior deste instalador? Remova `useOSProber = true;` e use
    `boot.loader.efi.canTouchEfiVariables = false;` em `/etc/nixos/configuration.nix`, depois
    `sudo nixos-rebuild switch --flake /etc/nixos`; `sudo efibootmgr -o <ordem>` põe o outro sistema na frente de novo.
- Segurança: o pendrive da ISO, discos montados, discos em uso (swap, LUKS, LVM, RAID) e discos com menos de
  20 GiB nunca são oferecidos; `-- --dry-run` mostra cada comando sem alterar nada.
- Pouca RAM (8 GB com parte dela tomada por uma GPU integrada): a swap perguntada só existe no sistema instalado,
  então durante a instalação o instalador cria uma swap temporária em arquivo na nova raiz
  (`/mnt/.monolith-install-swap`, até 8 GiB, o bastante para 16 GiB de RAM + swap, deixando 15 GiB livres), compila
  um pacote por vez com menos de 8 GiB de RAM (`--max-jobs 1`), limita os processos de compilador de cada pacote a
  cerca de um por 2 GiB de RAM (`--cores`: um pacote que falta no cache binário, como o Hyprland, compilaria com
  todos os threads) e deixa as árvores de build na raiz nova (`TMPDIR`), fora da RAM da ISO. O arquivo é desligado e apagado logo depois do
  `nixos-install`. Instalando à mão: `fallocate -l 8G /mnt/swapfile && chmod 600 /mnt/swapfile && mkswap /mnt/swapfile
  && swapon /mnt/swapfile` antes do `nixos-install`, depois `swapoff` e `rm` antes de reiniciar; `NIX_CONFIG=$'cores = 2\nmax-jobs = 1'` limita as compilações.
- Se a instalação parar depois de o disco ser preparado (rede, um erro corrigido na branch), rode o mesmo comando
  de novo: ele oferece retomar e busca a versão mais recente da branch (`--refresh`).
- A configuração busca o MONOLITH no mesmo lugar que o instalador: rodado com `?ref=<branch>`, o
  `/etc/nixos/flake.nix` segue essa branch (o próprio commit quando a branch não é encontrada);
  `MONOLITH_FLAKE=<flake ref>` escolhe outra origem.
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
nix flake init -t github:jhonatanoliveira2/monolith-dotfiles
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
nix --extra-experimental-features "nix-command flakes" flake init -t github:jhonatanoliveira2/monolith-dotfiles
cp /etc/nixos/hardware-configuration.nix .
# edite configuration.nix: usuário, hostname, teclado, bootloader (mantenha o que você já usa)
sudo nixos-rebuild switch --flake .#monolith-pc
```

### Flake existente

Adicione a entrada e o módulo e ative as opções.

```nix
inputs.monolith = {
  url = "github:jhonatanoliveira2/monolith-dotfiles";
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
| `gtk` | `true` | `Materia-dark`, o esquema de cores escuro e o tema de ícones `Monolith-Icons` (dconf) |
| `dev.enable`, `dev.source`, `dev.modules` | `false`, `null`, `null` | [modo de desenvolvimento](#modo-de-desenvolvimento): configuração ligada a um checkout editável |

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

## Tema Nothing

O tema Nothing é um visual opcional de matriz de pontos / LEDs (cinzas, fontes Doto / Space, medidores de LEDs,
brilho de borda, wallpapers em matriz de LEDs), desligado por padrão: `monolith.nothingTheme.enable = true;` o
ativa. Veja [`nothing-theme.pt-br.md`](nothing-theme.pt-br.md).

## Modo de desenvolvimento

Normalmente o Home Manager liga cada arquivo de `configs/.config` a partir da Nix store: somente leitura, então
cada mudança precisa de um rebuild. O **modo de desenvolvimento** liga os mesmos arquivos a um checkout do
repositório, para você editar no lugar e ver o resultado na hora:

```bash
git clone https://github.com/jhonatanoliveira2/monolith-dotfiles ~/monolith-dotfiles
```

```nix
# configuration.nix, dentro de home-manager.users.<você>.programs.monolith
dev = {
  enable = true;
  source = "/home/<você>/monolith-dotfiles";   # uma string (um caminho Nix seria copiado para a store)
  # modules = [ "quickshell" "hypr" "fastfetch" ];   # só estes; null (padrão) = tudo
};
```

`sudo nixos-rebuild switch --flake /etc/nixos` uma vez; a partir daí:

| Você edita (no checkout) | Vale |
|---|---|
| `configs/.config/quickshell/...` | na hora (o Quickshell recarrega sozinho) |
| `configs/.config/hypr/...` | `hyprctl reload` |
| `configs/.config/fastfetch/...`, `fish/...`, `ghostty/...` | na próxima execução do programa |
| um arquivo **novo** fora de `quickshell/` | depois de um rebuild (ele ganha o link) |

- `~/.config/<arquivo>` vira um link para `<checkout>/configs/.config/<arquivo>` (`mkOutOfStoreSymlink`); os
  arquivos são ligados um a um, então o que os programas escrevem ao lado deles (`fish_variables`,
  `hypr/generated/`) fica em `~/.config`, nunca no repositório. A pasta do Quickshell é ligada inteira.
- Todo o resto continua declarativo: pacotes, serviços, arquivos gerados (`monolith/nix.json`,
  `monolith/programs.lua`) e as cópias graváveis de `mutableFiles`.
- Um rebuild nunca escreve no checkout nem substitui os arquivos dele. Nenhuma permissão é alterada: o checkout
  é uma pasta sua.
- `dev.enable = false` e um rebuild trazem de volta os links da store. A ativação diz qual modo está valendo e
  avisa quando `source` não é um checkout.
- Mantenha o checkout na branch da qual o sistema é construído; faça commit e push dele normalmente, e
  Configurações > Atualização (ou `nix flake update monolith`) traz a versão publicada de volta para a store.
- Os arquivos próprios do tema Nothing também seguem: `nix/nothing/fastfetch.jsonc`,
  `fastfetch-logo.txt` (módulo `fastfetch`) e `cava.conf` (módulo `cava`).
- Outros módulos seguem a mesma chave com `config.programs.monolith.dev.link { module; path; store; }`
  (`nix/modules/dev.nix`): a fonte da store normalmente, o arquivo do checkout no modo de desenvolvimento.

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
- **`grub rescue>` com "file '/grub/x86_64-efi/normal.mod' not found" logo depois de instalar no disco inteiro**:
  instaladores anteriores a esta correção apagavam os módulos do GRUB e os kernels da ESP do próprio NixOS
  quando havia outro sistema (ou o pendrive Ventoy) em outro disco. O sistema em si está intacto; recoloque os
  arquivos de boot a partir de uma ISO live (na ISO do NixOS, o `nixos-enter` faz as montagens e o chroot):

  ```bash
  mount /dev/nvme0n1p2 /mnt && mount /dev/nvme0n1p1 /mnt/boot      # raiz (ext4 "nixos"), ESP (FAT32 "BOOT")
  nixos-enter --root /mnt -c 'NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot'
  # outra ISO live (Arch): for d in dev proc sys; do mount --rbind /$d /mnt/$d; done
  #   chroot /mnt /nix/var/nix/profiles/system/sw/bin/bash, depois /nix/var/nix/profiles/system/activate
  #   e o mesmo NIXOS_INSTALL_BOOTLOADER=1 ... switch-to-configuration boot
  ```
