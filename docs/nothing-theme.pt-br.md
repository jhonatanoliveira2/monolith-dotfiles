# Tema Nothing (LED / matriz de pontos)

**Português (Brasil)** · [English](nothing-theme.md)

O tema Nothing é uma identidade visual opcional do MONOLITH Shell, inspirada no
[NIHIL Shell](https://github.com/poligle/Nihil-Shell) (MIT) e no visual de matriz de pontos dos aparelhos
Nothing. Ele vem **desligado por padrão** e funciona nos dois caminhos de instalação, a partir das mesmas
fontes: no **NixOS** uma linha (`monolith.nothingTheme.enable = true;`) o ativa; no **Arch Linux / CachyOS** um
comando (`./scripts/nothing-theme.sh on`, veja [abaixo](#arch-linux--cachyos-scriptsnothing-themesh)). Sem ele o
shell é exatamente o MONOLITH padrão.

> Este projeto não é afiliado à Nothing Technology Limited. Nenhum logotipo da Nothing nem fonte proprietária
> (Ndot) é usado; as fontes são Doto, Space Grotesk e Space Mono (SIL OFL). Créditos:
> [`THIRD-PARTY-CREDITS.md`](../THIRD-PARTY-CREDITS.md).

## Conteúdo

- [O que muda](#o-que-muda)
- [Como é montado](#como-é-montado)
- [Opções (`monolith.nothingTheme`)](#opções-monolithnothingtheme)
- [Configurações: na hora vs. rebuild](#configurações-na-hora-vs-rebuild)
- [Wallpapers](#wallpapers)
- [Ativar o tema num sistema já instalado](#ativar-o-tema-num-sistema-já-instalado)
- [Arch Linux / CachyOS: `scripts/nothing-theme.sh`](#arch-linux--cachyos-scriptsnothing-themesh)
- [Problemas comuns](#problemas-comuns)

## O que muda

| Área | Tema Nothing |
|---|---|
| Cores | cinzas do preto OLED a `#F2F2F2` (substituem Configurações › Temas enquanto `monochrome` estiver ligado); vermelho `#D71921` **só** em alertas críticos (borda e LED da notificação crítica, itens críticos da barra) |
| Fontes | Space Mono na interface (monoespaçada, as larguras do layout se mantêm), Space Grotesk em títulos e no texto das notificações, Doto nos relógios (barra e widget); os ícones Nerd Font vêm da JetBrainsMono Nerd Font |
| Medidores | o OSD (volume, brilho...), todos os sliders e os medidores circulares viram fileiras / anéis de LEDs; os interruptores viram pílulas com um LED |
| Barra | na primeira vez que o tema é ativado, a barra vai para a lateral esquerda em estilo moldura (uma vez só; depois Configurações › Barra muda); estilo moldura: moldura preta OLED com uma linha de 1 px na borda interna e cantos de 20 px (a moldura do NIHIL Shell); na barra lateral o relógio fica em horas sobre minutos em Doto; os módulos da barra lateral mostram só ícones |
| Menu central | relógio em Doto, abas com LED, calendário com o dia contornado, colunas de LEDs para CPU / GPU / RAM e fileiras de LEDs em toda barra de progresso, uso e temperatura; com a barra na lateral, ele abre no topo central quando o mouse para no meio da borda de cima (ou com um clique no relógio), como uma gaveta da moldura (estilo moldura: mesmo preto, junções côncavas, a linha da moldura contornando) |
| Lançador, seletor de wallpaper | buscas em pílula com um LED que respira, rótulos em maiúsculas, seleção contornada com um LED aceso, ícones dos apps em cinza, contagem de resultados |
| Player | barra: equalizador de LEDs e progresso pontilhado; menu: a capa como ela é, progresso e volume em LEDs, botão de play branco sólido e anéis finos nos outros |
| Login (greeter) | relógio em Doto, Space Mono, uma fileira de LEDs no lugar da linha de senha (um aceso por caractere digitado, os caracteres não aparecem), vermelho só para login com erro |
| Bloqueio, boot | hyprlock: relógio em Doto, Space Mono, textos em maiúsculas, campo de senha em pílula, fundo mais escuro, vermelho só para senha errada; Plymouth: o progresso do boot como uma fileira de 24 LEDs (uma luz percorre a fileira ao reiniciar / desligar); cava em colunas de LEDs (`cava` no fish abre o `monolith-cava`; `command cava` é o comum, em cinzas) |
| Bateria | a carga em LEDs (uma fileira; oito em coluna na barra lateral), vermelhos com carga baixa, uma luz subindo enquanto carrega |
| Widgets | todos os widgets de um tamanho têm a mesma largura (pequeno 256, médio 320, grande 416 px), o relógio centralizado no card; cada widget, fixo ou temporário, aparece só no workspace em que foi adicionado; o espectro de áudio (cava) do widget de letra é desenhado em colunas de LEDs; os cards são um vidro, 70 % opacos por padrão (Configurações › Widgets › Opacidade do fundo, guardada à parte do valor do tema padrão) |
| Cursor | **MONOLITH Dots**: um "+" de LEDs como ponteiro e formas de LEDs para links, texto, espera (animada), mover e redimensionar; LEDs brancos com contorno escuro e sombra, visíveis em fundo claro e escuro (Hyprland, GTK, Qt) |
| Ícones | **MONOLITH Dots Icons**: pastas (com um emblema por tipo: documentos, downloads, músicas, imagens, vídeos, área de trabalho, home...), tipos de arquivo, lixeira e dispositivos como matrizes de LEDs monocromáticas, para o Nautilus e todo app GTK; o resto vem do Adwaita |
| fastfetch | o floco do NixOS como uma matriz de LEDs, rótulos cinza em maiúsculas, linhas pontilhadas, memória e disco como fileiras de LEDs |
| Superfícies | uma grade discreta de LEDs apagados atrás dos cards e dos widgets da área de trabalho; títulos das Configurações com marcador de LEDs |
| Notificações | nome do app em maiúsculas com um LED, texto em Space Grotesk; **brilho de borda** opcional: um trecho de luz percorre a borda interna da tela quando o shell inicia (login, reinício) e a cada notificação, duas vezes e em vermelho nas críticas |
| Wallpapers | wallpapers estáticos exibidos como matriz de LEDs na resolução nativa de cada monitor (os arquivos originais nunca são alterados); wallpapers animados (vídeo) ficam como estão |

O contraste e o brilho dos wallpapers podem ser aumentados à mão (`monolith-dotmatrix --contrast` /
`--brightness`, 1 = a curva padrão). Para legibilidade, Configurações › Barra › **Sem transparência no shell** deixa a
barra, os menus e os widgets opacos com um único botão (o terminal e os outros apps mantêm a transparência deles;
funciona com ou sem o tema).

As animações são curtas e desaceleradas, e seguem Configurações › Aparência › animações (desligadas = sem brilho e sem fades).

## Como é montado

```
nix/nothing/tokens.json         paleta, fontes, tempos (fonte única de verdade; o tokens.nix o lê)
nix/modules/nothing-options.nix opções, compartilhadas pelo NixOS (monolith.nothingTheme) e pelo Home Manager
nix/modules/nixos/nothing.nix   fontes no sistema, repassa as opções ao Home Manager
nix/modules/home-nothing.nix    ~/.config/monolith/nothing.json, fontes + conversor no PATH, wallpapers do build
nix/nothing/dotmatrix.py        monolith-dotmatrix (Python + numpy + Pillow): imagem -> matriz de LEDs
nix/pkgs/nothing-fonts.nix      Doto, Space Grotesk, Space Mono (arquivos avulsos do google/fonts, com hash)
nix/pkgs/nothing-wallpapers.nix cada imagem estática x cada monitor declarado, uma derivação por par
configs/.config/quickshell/core/Nothing.qml   lê o nothing.json + os ajustes de runtime (Settings.nothing)
scripts/nothing-theme.sh        Arch Linux / CachyOS: o mesmo nothing.json, fontes, conversor, cursor, ícones,
                                fastfetch e cava, a partir dos mesmos arquivos de nix/nothing/
```

O Nix (ou o `scripts/nothing-theme.sh`) grava os tokens em JSON; o `core/Nothing.qml` os entrega ao QML (`Theme.p`, `Theme.font`,
`Theme.fontSans`, `Theme.fontDot`, `Theme.alert`, `Theme.nothing`). Sem o `nothing.json` (tema
desligado) `Nothing.available` é falso e nenhum arquivo do shell se comporta diferente.

## Opções (`monolith.nothingTheme`)

Defina em `/etc/nixos/configuration.nix` (ou por usuário como `programs.monolith.nothingTheme` no Home
Manager). As opções "na hora" também mudam pelo app de Configurações; o valor do Nix é o padrão de partida.

| Opção | Padrão | | Efeito |
|---|---|---|---|
| `enable` | `true` | rebuild | o tema inteiro (fontes, tokens, conversor, wallpapers do build) |
| `led.size` | `6` | na hora | diâmetro do LED em px (wallpapers; os medidores da interface o escalam) |
| `led.spacing` | `3` | na hora | espaço entre LEDs em px |
| `led.shape` | `"circle"` | na hora | `circle`, `rounded` ou `square` (wallpapers e LEDs da interface) |
| `monochrome` | `true` | na hora | paleta cinza no shell e LEDs cinza nos wallpapers; desligado: o tema de cores fica e os LEDs pegam as cores da imagem |
| `cursor.enable`, `cursor.size` | `true`, `24` | rebuild | o tema de cursor de LEDs (Monolith-Dots) e o tamanho; entre de novo na sessão para vê-lo em tudo |
| `icons`, `nautilus`, `fastfetch`, `cava` | `true`, `true`, `true`, `true` | rebuild | o tema de ícones de LEDs (Monolith-Dots-Icons), o Nautilus em preto OLED a 85 % (vidro leve), a config Nothing do fastfetch e o cava em LEDs |
| `edgeGlow` | `true` | na hora | luz na borda da tela nas notificações |
| `wallpaper.style` | `"dotmatrix"` | na hora | `dotmatrix` ou `original` |
| `wallpaper.dither` | `"none"` | na hora | `none` (tamanho e brilho do LED seguem a imagem), `floyd` (Floyd-Steinberg), `bayer` (ordenado) |
| `wallpaper.levels` | `2` | na hora | níveis de brilho com pontilhado (`2` = aceso / apagado) |
| `wallpaper.invert` | `false` | na hora | acende as partes escuras |
| `wallpaper.contrast`, `wallpaper.brightness` | `100`, `100` | na hora | contraste e brilho dos wallpapers em % (50 a 200; as Configurações têm um botão para voltar ao padrão) |
| `wallpaper.colors.{lit,off,background}` | `f2f2f2`, `141414`, `000000` | rebuild | cores dos LEDs dos wallpapers |
| `wallpaper.outputs` | `{ }` | rebuild | monitores convertidos no build, `{ eDP-1 = { width = 1920; height = 1200; }; }` |
| `wallpaper.dirs` | `[ <repo>/wallpapers/static ]` | rebuild | pastas cujas imagens estáticas são convertidas no build |

Exemplo:

```nix
monolith.nothingTheme = {
  led = { size = 5; spacing = 3; shape = "rounded"; };
  wallpaper.outputs = {
    eDP-1 = { width = 1920; height = 1200; };   # nomes e tamanhos: hyprctl monitors
    DP-1 = { width = 2560; height = 1440; };
  };
};
monolith.nothingTheme.enable = true;   # desligado por padrão; false = o visual padrão do MONOLITH
```

## Configurações: na hora vs. rebuild

**Configurações › Temas › Nothing** (só aparece quando o `nothing.json` existe):

- **Aplicam na hora:** tema ligado / desligado, monocromático, brilho de borda, formato, tamanho e espaçamento
  dos LEDs, estilo do wallpaper, pontilhado, níveis de brilho, inverter, contraste e brilho do wallpaper (com um
  botão para voltar ao padrão). Ficam salvos como ajustes em
  `~/.local/state/quickshell-monolith/settings.json` (`nothing`); mudar uma opção de wallpaper reaplica o
  wallpaper estático atual com o novo visual.
- **Restaurar padrões:** descarta os ajustes e volta aos padrões do `nothing.json` (a configuração Nix, ou os
  padrões do próprio tema no Arch / CachyOS).
- **Apagar wallpapers convertidos (cache):** esvazia `~/.cache/monolith/dotmatrix`.
- **Exigem rebuild** (listados no fim da seção): `enable` como padrão, as fontes, os próprios padrões, as cores
  dos wallpapers e as conversões do build (`wallpaper.outputs`, `wallpaper.dirs`). No Arch / CachyOS o fim da
  seção lista, em vez disso, o que exige rodar `./scripts/nothing-theme.sh on` de novo.

## Wallpapers

Só imagens **estáticas** (PNG, JPEG, WebP, BMP) são convertidas; um GIF animado aparece como é (com um aviso) e
os wallpapers animados (mpvpaper) não são tocados. **O arquivo original só é lido**: a conversão vai para o
store (build) ou para `~/.cache/monolith/dotmatrix` (runtime), e o estado do wallpaper continua apontando para
o original, então voltar o estilo para `original` mostra a imagem de novo.

### Aplicar um wallpaper

Escolha como sempre: Configurações › Wallpapers (ou o seletor), ou o menu do rofi (`wallpaper-menu`). Com o
estilo `dotmatrix`, o `wallpaper-menu` converte a imagem **para cada monitor na resolução nativa** (monitores
girados com largura e altura trocadas) e dá a cada monitor a sua matriz:

1. a conversão do build, quando a imagem tem o mesmo conteúdo (sha256), o visual em uso tem a mesma chave e
   o monitor tem aquele tamanho;
2. senão o cache, `~/.cache/monolith/dotmatrix/<hash>.png` (o hash cobre a imagem, o tamanho e o visual);
3. senão converte na hora (cerca de um segundo em 4K) e guarda no cache.

Pelo terminal: `wallpaper-menu --set static ~/Pictures/Wallpapers/blue_sky.png` (todos os monitores) ou
`... ALL|DP-1,eDP-1`. Depois de mudar o visual nas Configurações, o wallpaper atual é convertido de novo
sozinho; o `wallpaper-menu --restore` (autostart) faz o mesmo no login.

### Converter à mão: `monolith-dotmatrix`

Instalado no PATH pelo tema:

```sh
# uma imagem para uma resolução
monolith-dotmatrix ~/Pictures/foto.jpg -o ~/Pictures/foto-pontos.png --resolution 2560x1440
# vários monitores de uma vez (um PNG por nome)
monolith-dotmatrix foto.jpg --outdir ~/Pictures/pontos --output eDP-1:1920x1200 --output DP-1:2560x1440
# o visual
monolith-dotmatrix foto.jpg -o saida.png -r 1920x1080 --size 5 --spacing 2 --shape square \
  --dither floyd --levels 3 --invert --lit ffffff --off 101010 --background 000000 [--color]
monolith-dotmatrix --key [opções]     # a chave de cache de um visual (o que o build e o wallpaper-menu comparam)
```

`--size` / `--spacing` em px, `--shape circle|rounded|square`, `--dither none|floyd|bayer`, `--levels 2..16`,
`--color` mantém as cores da imagem, `--gamma`, `--black`, `--contrast` (1) e `--brightness` (1) ajustam a curva. Ele se recusa a gravar por cima da
origem e a converter imagens animadas (código de saída 2). O resultado é um PNG comum: aplique com
`wallpaper-menu --set static saida.png` (com o estilo em `original`, senão ele seria convertido de novo).

### Conversão no build

Com `wallpaper.outputs` definido, cada imagem estática de `wallpaper.dirs` é convertida para cada monitor da
lista durante o `nixos-rebuild` (uma derivação por imagem x monitor: um rebuild só converte o que mudou). As
conversões ficam no store, listadas no `nothing.json` (`wallpapers.dir`), e só são usadas enquanto o visual
das Configurações for igual ao do Nix; qualquer outro visual usa o cache de runtime.

## Ativar o tema num sistema já instalado

Uma instalação nova pela ISO pergunta o tema (padrão ou Nothing) e grava esta linha sozinha. Fora isso, acrescente a opção à configuração em `/etc/nixos` e reconstrua:

```nix
monolith.nothingTheme.enable = true;
```

```sh
sudo nixos-rebuild switch --flake /etc/nixos
```

Saia e entre na sessão (ou reinicie o shell) para carregar as fontes novas. `monolith.nothingTheme.enable = false;`
(ou apagar a linha) volta ao visual padrão.

Um sistema instalado a partir de uma das branches antigas (`feature/nixos-support`, `feature/nothing-theme`): veja
[Atualizar a partir de uma branch antiga](migracao.md#nixos).

## Arch Linux / CachyOS: `scripts/nothing-theme.sh`

No clone do MONOLITH (o mesmo de onde o `install.sh` rodou):

```sh
./scripts/nothing-theme.sh on        # liga (pode rodar de novo quando quiser: atualiza tudo)
./scripts/nothing-theme.sh status    # o que ele instalou
./scripts/nothing-theme.sh off       # desliga: remove o que instalou e devolve o que substituiu
./scripts/install.sh --theme nothing # ou junto com a instalação (ele também pergunta)
```

Ele faz na sua home o que o módulo do Home Manager faz no NixOS, a partir dos mesmos arquivos (`nix/nothing/`):

| Parte | Arquivos | Para deixar de fora |
|---|---|---|
| tokens e padrões | `~/.config/monolith/nothing.json` (o shell muda na hora) | — |
| fontes | Doto, Space Grotesk, Space Mono em `~/.local/share/fonts/monolith-nothing` (a mesma revisão do google/fonts e os mesmos sha256 do Nix; um arquivo que não confere é descartado) | — |
| conversor | `~/.local/bin/monolith-dotmatrix` (precisa de `python-numpy`, `python-pillow`) | — |
| cursor | MONOLITH Dots em `~/.icons`, `~/.config/monolith/cursor` (Hyprland), gsettings `cursor-theme` / `cursor-size` | `--no-cursor`, tamanho: `--cursor-size 32` |
| ícones | MONOLITH Dots Icons em `~/.local/share/icons`, gsettings `icon-theme` | `--no-icons` |
| nautilus | `~/.config/gtk-4.0/gtk.css`: o padrão com o `nix/nothing/nautilus.css` depois dele, então o Nautilus fica em preto OLED a 85 % de opacidade (vidro leve, sem blur) em vez do vidro mais escuro do tema padrão; o `off` devolve o arquivo padrão | `--no-nautilus` |
| fastfetch | `~/.config/fastfetch/nothing.jsonc`: o logo do Arch em LEDs e o nome da distribuição; a função `fastfetch` do fish o usa quando chamada sem argumentos | `--no-fastfetch` |
| cava | `~/.config/cava/config` em cinzas, `~/.local/bin/monolith-cava`, a função `cava` do fish (`command cava` é o comum) | `--no-cava` |

- Se faltar `python-numpy` / `python-pillow` (pacotes opcionais do `packages.txt`, instalados pelo `install.sh`
  a menos que use `--no-optional`), ele oferece `sudo pacman -S`. Sem o Pillow o cursor fica de fora; sem o
  numpy os wallpapers ficam como são até ele ser instalado.
- Um arquivo que já existia e não é do tema (um `~/.config/cava/config` seu, por exemplo) é guardado em
  `~/.local/state/monolith-dotfiles/nothing-theme/saved` e volta com `off`; os valores anteriores do gsettings também.
- Rodar `on` de novo com `--no-icons` (etc.) remove essa parte. O `./scripts/install.sh` atualiza o tema sozinho
  depois de uma atualização quando ele está ligado, mantendo as partes escolhidas antes.
- Não há conversão no build: cada wallpaper é convertido no primeiro uso e guardado em cache. Plymouth e greeter
  são recursos do NixOS, então as variantes em LED deles só existem lá.

## Problemas comuns

- **Quadrados no lugar das fontes Doto / Space:** saia e entre na sessão depois do primeiro rebuild ou do
  `nothing-theme.sh on` (no Arch, confira se o `nothing-theme.sh status` lista as fontes) (cache de
  fontes); o shell usa a JetBrainsMono Nerd Font para qualquer família que não encontrar.
- **O wallpaper continua o original:** confira Configurações › Temas › Nothing › Wallpaper = Matriz de LEDs;
  imagens animadas e vídeos nunca são convertidos; `monolith-dotmatrix --help` precisa funcionar no terminal.
- **Uma conversão parece desatualizada:** Configurações › Temas › Nothing › Apagar wallpapers convertidos, e
  escolha a imagem de novo.
- **A seção não aparece nas Configurações:** falta o `~/.config/monolith/nothing.json`: o tema está desligado
  (falta `monolith.nothingTheme.enable = true;`) ou o sistema não foi reconstruído depois disso; no Arch /
  CachyOS, execute `./scripts/nothing-theme.sh on`.
