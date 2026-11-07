# Tema Nothing (LED / matriz de pontos)

**Português (Brasil)** · [English](nothing-theme.md)

A branch `feature/nothing-theme` (criada a partir da `feature/nixos-support`, só NixOS) acrescenta ao MONOLITH
Shell uma identidade visual opcional inspirada no [NIHIL Shell](https://github.com/poligle/Nihil-Shell) (MIT) e
no visual de matriz de pontos dos aparelhos Nothing. Ela vem **ativada por padrão nesta branch**; desligada, o
shell fica exatamente como o da `feature/nixos-support`.

> Este projeto não é afiliado à Nothing Technology Limited. Nenhum logotipo da Nothing nem fonte proprietária
> (Ndot) é usado; as fontes são Doto, Space Grotesk e Space Mono (SIL OFL). Créditos:
> [`THIRD-PARTY-CREDITS.md`](../THIRD-PARTY-CREDITS.md).

## Conteúdo

- [O que muda](#o-que-muda)
- [Como é montado](#como-é-montado)
- [Opções (`monolith.nothingTheme`)](#opções-monolithnothingtheme)
- [Configurações: na hora vs. rebuild](#configurações-na-hora-vs-rebuild)
- [Wallpapers](#wallpapers)
- [Mudar um sistema de `feature/nixos-support` para `feature/nothing-theme`](#mudar-um-sistema-de-featurenixos-support-para-featurenothing-theme)
- [Problemas comuns](#problemas-comuns)

## O que muda

| Área | Tema Nothing |
|---|---|
| Cores | cinzas do preto OLED a `#F2F2F2` (substituem Configurações › Temas enquanto `monochrome` estiver ligado); vermelho `#D71921` **só** em alertas críticos (borda e LED da notificação crítica, itens críticos da barra) |
| Fontes | Space Mono na interface (monoespaçada, as larguras do layout se mantêm), Space Grotesk em títulos e no texto das notificações, Doto nos relógios (barra e widget); os ícones Nerd Font vêm da JetBrainsMono Nerd Font |
| Medidores | o OSD (volume, brilho...), todos os sliders e os medidores circulares viram fileiras / anéis de LEDs; os interruptores viram pílulas com um LED |
| Barra | estilo moldura: moldura preta OLED com uma linha de 1 px na borda interna e cantos de 20 px (a moldura do NIHIL Shell); na barra lateral o relógio fica em horas sobre minutos em Doto; os módulos da barra lateral mostram só ícones |
| Menu central | relógio em Doto, abas com LED, calendário com o dia contornado, colunas de LEDs para CPU / GPU / RAM e fileiras de LEDs em toda barra de progresso, uso e temperatura; com a barra na lateral, ele abre no topo central quando o mouse para no meio da borda de cima (ou com um clique no relógio), como uma gaveta da moldura (estilo moldura: mesmo preto, junções côncavas, a linha da moldura contornando) |
| Bateria | a carga em LEDs (uma fileira; oito em coluna na barra lateral), vermelhos com carga baixa, uma luz subindo enquanto carrega |
| Widgets | todos os widgets de um tamanho têm a mesma largura (pequeno 256, médio 320, grande 416 px), o relógio centralizado no card; cada widget, fixo ou temporário, aparece só no workspace em que foi adicionado; o espectro de áudio (cava) do widget de letra é desenhado em colunas de LEDs |
| Cursor | **MONOLITH Dots**: um "+" de LEDs como ponteiro e formas de LEDs para links, texto, espera (animada), mover e redimensionar; LEDs brancos com contorno escuro e sombra, visíveis em fundo claro e escuro (Hyprland, GTK, Qt) |
| Superfícies | uma grade discreta de LEDs apagados atrás dos cards e dos widgets da área de trabalho; títulos das Configurações com marcador de LEDs |
| Notificações | nome do app em maiúsculas com um LED, texto em Space Grotesk; **brilho de borda** opcional: um trecho de luz percorre a borda interna da tela a cada notificação, duas vezes e em vermelho nas críticas |
| Wallpapers | wallpapers estáticos exibidos como matriz de LEDs na resolução nativa de cada monitor (os arquivos originais nunca são alterados); wallpapers animados (vídeo) ficam como estão |

O contraste e o brilho dos wallpapers podem ser aumentados à mão (`monolith-dotmatrix --contrast` /
`--brightness`, 1 = a curva padrão). Para legibilidade, Configurações › Barra › **Sem transparência no shell** deixa a
barra, os menus e os widgets opacos com um único botão (o terminal e os outros apps mantêm a transparência deles;
funciona com ou sem o tema).

As animações são curtas e desaceleradas, e seguem Configurações › Aparência › animações (desligadas = sem brilho e sem fades).

## Como é montado

```
nix/nothing/tokens.nix          paleta, fontes, tempos (fonte única de verdade)
nix/modules/nothing-options.nix opções, compartilhadas pelo NixOS (monolith.nothingTheme) e pelo Home Manager
nix/modules/nixos/nothing.nix   fontes no sistema, repassa as opções ao Home Manager
nix/modules/home-nothing.nix    ~/.config/monolith/nothing.json, fontes + conversor no PATH, wallpapers do build
nix/nothing/dotmatrix.py        monolith-dotmatrix (Python + numpy + Pillow): imagem -> matriz de LEDs
nix/pkgs/nothing-fonts.nix      Doto, Space Grotesk, Space Mono (arquivos avulsos do google/fonts, com hash)
nix/pkgs/nothing-wallpapers.nix cada imagem estática x cada monitor declarado, uma derivação por par
configs/.config/quickshell/core/Nothing.qml   lê o nothing.json + os ajustes de runtime (Settings.nothing)
```

O Nix gera os tokens em JSON; o `core/Nothing.qml` os entrega ao QML (`Theme.p`, `Theme.font`,
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
| `cursor.enable`, `cursor.size` | `true`, `32` | rebuild | o tema de cursor de LEDs (Monolith-Dots) e o tamanho; entre de novo na sessão para vê-lo em tudo |
| `edgeGlow` | `true` | na hora | luz na borda da tela nas notificações |
| `wallpaper.style` | `"dotmatrix"` | na hora | `dotmatrix` ou `original` |
| `wallpaper.dither` | `"none"` | na hora | `none` (tamanho e brilho do LED seguem a imagem), `floyd` (Floyd-Steinberg), `bayer` (ordenado) |
| `wallpaper.levels` | `2` | na hora | níveis de brilho com pontilhado (`2` = aceso / apagado) |
| `wallpaper.invert` | `false` | na hora | acende as partes escuras |
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
# monolith.nothingTheme.enable = false;   # volta ao visual da feature/nixos-support
```

## Configurações: na hora vs. rebuild

**Configurações › Temas › Nothing** (só aparece quando o `nothing.json` existe):

- **Aplicam na hora:** tema ligado / desligado, monocromático, brilho de borda, formato, tamanho e espaçamento
  dos LEDs, estilo do wallpaper, pontilhado, níveis de brilho, inverter. Ficam salvos como ajustes em
  `~/.local/state/quickshell-monolith/settings.json` (`nothing`); mudar uma opção de wallpaper reaplica o
  wallpaper estático atual com o novo visual.
- **Restaurar padrões:** descarta os ajustes e volta aos valores da configuração Nix.
- **Apagar wallpapers convertidos (cache):** esvazia `~/.cache/monolith/dotmatrix`.
- **Exigem rebuild** (listados no fim da seção): `enable` como padrão, as fontes, os próprios padrões, as cores
  dos wallpapers e as conversões do build (`wallpaper.outputs`, `wallpaper.dirs`).

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

## Mudar um sistema de `feature/nixos-support` para `feature/nothing-theme`

O flake em `/etc/nixos` segue uma branch pelo input `monolith`. Aponte-o para esta branch:

```sh
sudo sed -i 's|monolith-dotfiles/feature/nixos-support|monolith-dotfiles/feature/nothing-theme|' /etc/nixos/flake.nix
sudo nix flake update monolith --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos
```

Saia e entre na sessão (ou reinicie o shell) para carregar as fontes novas. A partir daí Configurações ›
Atualização segue a `feature/nothing-theme`. Para voltar, rode o mesmo com os dois nomes de branch trocados (ou
defina `monolith.nothingTheme.enable = false;` para ficar nesta branch sem o tema). Instalação nova pela ISO:
`sudo nix --extra-experimental-features "nix-command flakes" run github:jhonatanoliveira2/monolith-dotfiles/feature/nothing-theme#install`.

## Problemas comuns

- **Quadrados no lugar das fontes Doto / Space:** saia e entre na sessão depois do primeiro rebuild (cache de
  fontes); o shell usa a JetBrainsMono Nerd Font para qualquer família que não encontrar.
- **O wallpaper continua o original:** confira Configurações › Temas › Nothing › Wallpaper = Matriz de LEDs;
  imagens animadas e vídeos nunca são convertidos; `monolith-dotmatrix --help` precisa funcionar no terminal.
- **Uma conversão parece desatualizada:** Configurações › Temas › Nothing › Apagar wallpapers convertidos, e
  escolha a imagem de novo.
- **A seção não aparece nas Configurações:** falta o `~/.config/monolith/nothing.json`: o tema está desligado
  (`monolith.nothingTheme.enable`) ou o sistema não está nesta branch.
