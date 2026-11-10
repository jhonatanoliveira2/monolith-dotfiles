# Configuração do desktop

[English](config.md) · **Português (Brasil)**

`configs/` espelha caminhos dentro da sua pasta pessoal: `configs/.config/` é instalado em `~/.config/`, e `configs/.local/bin/` em `~/.local/bin/`. O instalador copia o conteúdo; ele não gera nem adapta as configurações ao seu hardware.

## O que está incluído

| Pasta | Conteúdo |
|---|---|
| `hypr/` | Configuração modular do Hyprland em Lua, bloqueio de tela, idle, portal e temas do Rofi |
| `quickshell/` | Barra, menus de configurações, rede, Bluetooth, áudio, brilho, notificações e módulos de sistema |
| `fish/` | Configuração do Fish, inicialização do Hyprland no TTY1, Starship, Atuin e completions |
| `ghostty/` | Configuração do terminal e shaders de cursor |
| `gtk-3.0/`, `gtk-4.0/`, `nwg-look/` | Aparência e preferências de aplicativos GTK |
| `nvim/`, `micro/`, `btop/` | Inicialização do Neovim com LazyVim, editor Micro e monitor de recursos |
| `wal/`, `wpg/` | Configuração para temas derivados de wallpapers |

`wallpapers/` contém mídia distribuída separadamente das configurações. `scripts/import-configs.sh` pode copiar pastas selecionadas do seu `~/.config` para o payload do repositório; essa operação é opcional.

## Revise antes de instalar

As configurações têm algumas escolhas locais que podem não corresponder ao seu equipamento:

- `hypr/modules/monitors.lua` seleciona automaticamente a saída preferida, posição automática e escala `1`. Ajuste o arquivo se seu arranjo de monitores exigir outra coisa.
- `hypr/modules/environment.lua` define `LANG` e `LC_TIME` como `pt_BR.UTF-8`. Esse locale precisa existir no sistema; o instalador avisa, mas não o gera.
- `hypr/modules/input.lua` contém as preferências de teclado e entrada. Revise o layout e os valores antes de usar.
- `fish/config.fish` inicia Hyprland no TTY1 sob as condições definidas no arquivo. Isso depende do shell de login e do modo como você inicia sua sessão.
- `hypr/modules/keybindings.lua` contém atalhos e comandos locais. Confirme que os programas associados estão instalados.

O ponto de entrada do compositor é `hypr/hyprland.lua`. O Quickshell começa em `quickshell/shell.qml`; sua barra e seus componentes ficam nas pastas `components/`, `modules/`, `menus/`, `services/` e `core/`.

## Wallpapers

O atalho `SUPER+D` abre o menu Rofi configurado em `hypr/rofi/wallpaper-menu.rasi` e executa `~/.local/bin/wallpaper-menu`.

| Tipo | Destino na sua pasta pessoal | Motor |
|---|---|---|
| Estático | `~/Pictures/Wallpapers` | `awww` |
| Vídeo `.mp4` | `~/Videos/wallpaper-live` | `mpvpaper` |

O instalador cria esses destinos e copia os wallpapers que acompanham o projeto. O menu usa `ffmpeg` para gerar prévias em cache; `wallpaper-menu --clear-cache` limpa esse cache.

### Temas de cores

Configurações > Temas alterna entre o tema original do Monolith, temas predefinidos e uma paleta dinâmica. A paleta dinâmica vem do wallpaper alterado mais recentemente, em qualquer monitor: `~/.local/bin/monolith-theme` executa o `wpgtk` em uma pasta própria (`~/.cache/monolith-theme`), então ele nunca define wallpapers nem altera `~/.config/wpg`. Para vídeos, lê um frame representativo quando o vídeo é escolhido. A escolha e a paleta ficam em `~/.local/state/quickshell-monolith/settings.json`; `fish/conf.d/monolith-theme.fish` aplica as mesmas cores ao Fish, em sessões novas e abertas. `monolith-theme check` lista as dependências e `monolith-theme clear-cache` apaga as paletas geradas.

## Arquivos excluídos na importação

O importador evita copiar alguns dados de máquina e artefatos, incluindo:

| Caminho ou padrão | Por que é excluído |
|---|---|
| `micro/backups/` | Pode conter versões de qualquer arquivo editado. |
| `fish/fish_variables` | Pode guardar variáveis e caminhos particulares da máquina. |
| `fish/conf.d/*.env.fish` | Arquivos gerados por instaladores de terceiros e com caminhos locais. |
| `*.bak`, `*~`, `*.swp`, `*.tmp`, `*.log`, `__pycache__`, `.git`, `.DS_Store` | Backups temporários e artefatos locais. |

Essas exclusões são aplicadas pelo importador; elas não substituem a revisão manual dos arquivos antes de publicar. O projeto não deve receber tokens, chaves, credenciais, e-mails ou caminhos privados.

## Estrutura simplificada

```text
configs/
├── .config/
│   ├── hypr/         compositor, atalhos e Rofi
│   ├── quickshell/   barra, menus e componentes do desktop
│   ├── fish/         shell e inicialização
│   ├── ghostty/      terminal e shaders
│   └── ...           ferramentas e preferências visuais
└── .local/bin/       utilitários chamados pelos atalhos
```

Para instalar ou desfazer a instalação, consulte o [guia de instalação](instalacao.md).

## Aplicativo de configurações

Menu `Super` → **Configurações** (ou `qs ipc call shell settings <página>`). Abas: Sistema, Tela, Hyprland, Barra,
Áudio, Microfone, Widgets, Notificações, Rede, Bluetooth, Energia (só em notebooks), Armazenamento, Entrada e Atualização.

- **Tela** e **Hyprland** aplicam as mudanças na hora pela API Lua do Hyprland (`hyprctl eval`) e as salvam em
  `~/.config/hypr/generated/monitors.lua` e `~/.config/hypr/generated/settings.lua`. O `hyprland.lua` carrega
  esses dois arquivos por último. Apague um arquivo para voltar aos seus `modules/*.lua`. Uma mudança de
  monitor é revertida após 15 segundos se você não clicar em **Manter**.
- **Microfone** tem supressão de ruído RNNoise (pacote `noise-suppression-for-voice`, intensidade ajustável) e
  um equalizador de 5 faixas (100 Hz – 8 kHz, ±12 dB, com corte abaixo de 80 Hz) com predefinições, incluindo
  *Voz grave*. Arraste uma faixa, role sobre ela (±1 dB) ou dê clique duplo (0 dB); **Desfazer alterações**
  volta aos valores de quando a página foi aberta; **Zerar** volta ao plano. Os efeitos criam a entrada
  **Monolith Mic**, que vira a padrão enquanto estão ligados; escolher outra entrada muda o microfone filtrado. **Ouvir o microfone** toca a entrada padrão de
  volta via `pw-loopback` (atraso opcional de 0,3 / 1 s, para após 2 min); use fones. Logs: `[micfx]` /
  `[mictest]` no log do Quickshell, `journalctl --user -u monolith-micfx`.
- **Áudio** tem o mesmo equalizador para a saída (10 faixas, 31 Hz – 16 kHz) com predefinições (Bass boost,
  Extreme bass, Funk, Trap, Rock, Vocal boost, Deep house, ASMR, Pop, Eletrônica, Jazz, Clássica, Lo-fi, Podcast,
  Volume baixo, Agudos). A gaveta **Mais efeitos** guarda o reforço de grave, o reforço de volume (pré-ganho;
  valores altos podem distorcer) e um virtualizador para fones (crossfeed). A saída **Monolith Audio** vira a
  padrão enquanto os efeitos estão ligados, e escolher outra saída muda o dispositivo para onde o som vai.
- **Persistência dos efeitos**: cada cadeia é um filter-chain do PipeWire rodado por uma unit de usuário do
  systemd (`~/.config/systemd/user/monolith-micfx.service` / `monolith-audiofx.service`,
  `WantedBy=pipewire.service`) que lê `~/.local/state/quickshell-monolith/micfx.conf` / `audiofx.conf`. Toda
  mudança é salva na hora e os efeitos sobem com o PipeWire no login, mesmo com o shell parado ou reiniciando.
  Desligar os efeitos desativa e remove a unit. Logs: `[micfx]` / `[audiofx]` / `[mictest]`,
  `journalctl --user -u monolith-audiofx`.
- **Estilo da barra** (Configurações → Barra): *Plana* (faixa de ponta a ponta), *Cápsula* (pílula arredondada
  com margem das bordas da tela; numa barra lateral vira uma pílula vertical) ou *Moldura* (a barra continua como
  uma borda fina em volta da tela toda, com cantos internos arredondados, no estilo Caelestia). Só o fundo muda,
  não os módulos. Cápsula e Moldura podem ter sombra (*Sombra da barra*, *Intensidade da sombra*). A moldura é
  opaca; o *Tom da moldura* vai do preto (0%) à cor do tema (100%), e os módulos passam a usar tons claros ou
  escuros das próprias cores do tema para continuarem legíveis.
- **Menu central** (Configurações → Barra → *Menu central*): parar o mouse no meio da barra abre um painel com
  relógio e data, clima (wttr.in; defina uma cidade ou deixe vazio para automático), medidores e histórico de
  CPU / RAM / GPU, o player e o tempo ligado. Fecha quando o mouse sai. Só existe enquanto está aberto, então
  não pesa quando fechado. `qs ipc call shell toggle center` abre fixo.
- **Widgets da área de trabalho** (Configurações → Widgets): relógio, sistema, clima e mídia na área de
  trabalho, por baixo das janelas. **Organizar widgets** (ou `qs ipc call widgets edit`) abre o editor: arraste
  para mover (encaixa numa grade de 8 px), × remove, a barra de cima adiciona; Esc ou **Concluir** sai. As
  posições ficam salvas por monitor no `settings.json`. Um novo tipo de widget é um arquivo QML em
  `quickshell/widgets/` mais uma linha em `services/Widgets.qml`.
- **Armazenamento** lê a saúde dos discos pelo UDisks2, sem root. A limpeza sempre analisa antes e mostra o que
  cada item remove. Apagar exige um segundo clique de confirmação. A limpeza do pacman e do journal pede a
  senha via `pkexec`.
- **Atualização** compara o clone local com o próprio remoto e branch dele: o upstream, se houver, senão
  `origin/<branch>`. Também mostra o status e o limite de requisições da API do GitHub.
- **YouTube Music** (app da th-ch) não expõe aleatório nem repetir via MPRIS. Para usar esses botões, ative o
  plugin *API Server* e escolha a autorização *Sem autorização* ou cole um token em Configurações → Barra. A
  porta padrão é 26538.
- As capas das últimas 50 músicas tocadas ficam em cache em `~/.cache/quickshell-monolith/covers`.
- **Título do player** acompanha o nome da faixa, entre um mínimo e um máximo de caracteres
  (Configurações → Barra → *Título do player: mínimo / máximo*). No menu de mídia, a fonte do título diminui
  em nomes longos e aumenta em nomes curtos.
- **Tocadas recentemente**: clicar em uma faixa envia ela ao player atual via MPRIS (`OpenUri`) e aperta Play
  até ela começar, então players que só carregam a página (YouTube Music) também começam a tocar. Players sem
  `OpenUri` abrem no navegador.
- **Busca de Bluetooth** mantém o pedido ativo por 60 s: se o BlueZ derrubar a descoberta logo após iniciar, o
  shell pede de novo sozinho, então um clique em **Procurar** basta.

## Requisições de rede feitas pelo shell

O shell contata os serviços abaixo, e só quando o recurso que precisa deles está em uso. Cada um pode ser
desligado; nada além disso sai da máquina.

| Recurso | Serviço | O que é enviado | Quando | Como desligar |
|---|---|---|---|---|
| Clima (menu central, widget de clima) | `api.open-meteo.com`, `air-quality-api.open-meteo.com` | latitude e longitude | quando a aba ou o widget aparece, no máximo a cada 20 minutos | Configurações > Barra > Menu central (sem widget de clima, menu central desligado) |
| Clima: busca da cidade | `geocoding-api.open-meteo.com` | a cidade digitada nas Configurações | uma vez por cidade | deixe a cidade vazia |
| Clima: localização sem cidade | `ipinfo.io` | o seu endereço IP (é a própria requisição) | quando não há cidade definida | Configurações > Barra > Menu central > *Clima: localizar pelo IP* (desligado: sem clima até definir uma cidade) |
| Letras | `lrclib.net`, `music.163.com` (NetEase), `api.lyrics.ovh` | artista, título, álbum e duração da faixa em reprodução | quando as letras são exibidas; os resultados ficam em cache | uma chave por fonte em Configurações > Barra > Player; todas desligadas = nenhuma requisição |
| Capas de álbum | a URL que o player publica (MPRIS `artUrl`) | um download simples | quando uma faixa entra no histórico | — (o endereço vem do seu player) |
| Verificação de atualização (Arch, CachyOS) | o remoto `origin` do seu clone, `api.github.com` | um `git fetch` e uma requisição anônima à API | quando Configurações > Atualização é aberta | não abra a página |
| Controles do YouTube Music | `127.0.0.1` (plugin API Server do player) | só local | quando o YouTube Music é o player | — |

Antes de uma atualização rodar, Configurações > Atualização lista os commits que ela traz (e avisa quando o próprio
instalador muda) e pede um segundo clique; o clone é então avançado exatamente para a revisão listada. A linha de
comando do menu central guarda o histórico no `settings.json`; *Guardar o histórico de comandos* (Configurações >
Barra > Menu central) desliga isso e apaga o que foi salvo.
