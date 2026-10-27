pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../core"
import "../services"

// Every simple setting, described once. The pages and the search box both render these entries.
// type: toggle | slider | choice | button | text      label: [pt, en]      kw: extra search words (both languages)
// cat: group heading inside the page (Labels "cat_<cat>")     when: () => bool, hides the entry
Singleton {
    id: root

    readonly property string repoUrl: "https://github.com/jhonatanoliveira2/monolith-dotfiles"
    readonly property string home: Quickshell.env("HOME")
    readonly property string repoPath: Settings.repoPath !== "" ? Settings.repoPath : home + "/monolith-dotfiles"
    readonly property bool laptop: UPower.displayDevice !== null && UPower.displayDevice.isPresent && UPower.displayDevice.isLaptopBattery
    readonly property var allPages: [
        { id: "system", glyph: 0xf108 }, { id: "profile", glyph: 0xf007 }, { id: "appearance", glyph: 0xf1fc },
        { id: "themes", glyph: 0xf03d8 },
        { id: "launcher", glyph: 0xf135 }, { id: "wallpaper", glyph: 0xf03e },
        { id: "display", glyph: 0xf26c }, { id: "configs", glyph: 0xf013 },
        { id: "bar", glyph: 0xf0c9 }, { id: "audio", glyph: 0xf028 }, { id: "mic", glyph: 0xf130 },
        { id: "notifications", glyph: 0xf0f3 }, { id: "network", glyph: 0xf1eb }, { id: "bluetooth", glyph: 0xf293 },
        { id: "power", glyph: 0xf240, when: () => root.laptop }, { id: "storage", glyph: 0xf0a0 },
        { id: "input", glyph: 0xf11c }, { id: "update", glyph: 0xf019 }
    ]
    readonly property var pages: allPages.filter(p => !p.when || p.when())

    function sys(key) { return Sys.values[key] !== undefined ? Sys.values[key] : 0 }
    function setSys(key) { return v => Sys.setValue(key, typeof v === "boolean" ? (v ? 1 : 0) : v) }
    function open(rel) { Quickshell.execDetached(["xdg-open", rel.indexOf("/") === 0 ? rel : home + "/" + rel]) }
    function run(cmd) { Quickshell.execDetached(cmd) }
    function lbl(pt, en) { return Settings.language === "en" ? en : pt }     // labels of choice buttons

    function tog(page, cat, id, label, kw, get, set, extra) { return Object.assign({ page, cat, id, type: "toggle", label, kw, get, set }, extra || {}) }
    function sld(page, cat, id, label, kw, min, max, step, suffix, get, set, extra) { return Object.assign({ page, cat, id, type: "slider", label, kw, min, max, step, suffix, get, set }, extra || {}) }
    function btn(page, cat, id, label, kw, run, extra) { return Object.assign({ page, cat, id, type: "button", label, kw, run }, extra || {}) }
    function cho(page, cat, id, label, kw, options, get, set, extra) { return Object.assign({ page, cat, id, type: "choice", label, kw, options, get, set }, extra || {}) }
    // Hyprland option shortcuts (the key is the Sys.options key)
    function htog(page, cat, key, label, kw) { return tog(page, cat, key, label, kw, () => !!root.sys(key), root.setSys(key)) }
    function hsld(page, cat, key, label, kw, min, max, step, suffix) { return sld(page, cat, key, label, kw, min, max, step, suffix, () => root.sys(key), root.setSys(key)) }
    // fraction options shown as percent
    function hpct(page, cat, key, label, kw, min, max) {
        return sld(page, cat, key, label, kw, min, max, 5, "%", () => Math.round(root.sys(key) * 100), v => Sys.setValue(key, v / 100))
    }

    readonly property var entries: [
        // ── system ──
        tog("system", "general", "dnd", ["Não perturbe", "Do not disturb"], "notifications notificações silêncio", () => Settings.dnd, v => Settings.dnd = v),
        tog("system", "general", "dark", ["Modo escuro", "Dark mode"], "gtk tema theme", () => Sys.darkMode, v => Sys.setDark(v)),
        cho("system", "general", "language", ["Idioma", "Language"], "language idioma português english",
            [{ v: "pt", l: "Português" }, { v: "en", l: "English" }], () => Settings.language, v => Settings.language = v),
        tog("system", "general", "keepAwake", ["Manter acordado", "Keep awake"], "idle caffeine suspender sleep", () => Settings.keepAwake, v => Settings.keepAwake = v),
        btn("system", "session", "lock", ["Bloquear", "Lock"], "hyprlock tela screen", () => Sys.lock()),
        btn("system", "session", "suspend", ["Suspender", "Suspend"], "sleep", () => Sys.suspend()),
        btn("system", "session", "logout", ["Sair", "Log out"], "sessão session exit", () => Sys.logout(), { confirm: true }),
        btn("system", "session", "reboot", ["Reiniciar", "Reboot"], "restart", () => Sys.reboot(), { confirm: true }),
        btn("system", "session", "poweroff", ["Desligar", "Power off"], "shutdown", () => Sys.poweroff(), { confirm: true }),

        // ── display (the monitor manager is drawn by PageDisplay) ──
        sld("display", "screen", "brightness", ["Brilho", "Brightness"], "backlight luz", 1, 100, 1, "%", () => Math.round(Brightness.fraction * 100), v => Brightness.set(v / 100), { when: () => Brightness.available }),
        cho("display", "screen", "vrr", ["VRR (taxa variável)", "VRR (variable refresh)"], "vrr freesync gsync adaptive sync fps hz",
            [{ v: 0, l: "Off" }, { v: 1, l: "On" }, { v: 2, l: "Fullscreen" }, { v: 3, l: "Game" }], () => root.sys("vrr"), v => Sys.setValue("vrr", v)),

        // ── configs: Hyprland, by category ──
        hsld("configs", "general", "gapsIn", ["Espaço interno", "Inner gaps"], "gaps janelas", 0, 40, 1, "px"),
        hsld("configs", "general", "gapsOut", ["Espaço externo", "Outer gaps"], "gaps margem", 0, 80, 1, "px"),
        hsld("configs", "general", "borderSize", ["Borda", "Border"], "border", 0, 10, 1, "px"),
        cho("configs", "general", "layout", ["Layout das janelas", "Window layout"], "tiling dwindle master scrolling",
            [{ v: "dwindle", l: "Dwindle" }, { v: "master", l: "Master" }, { v: "scrolling", l: "Scrolling" }], () => root.sys("layout"), v => Sys.setValue("layout", v)),
        htog("configs", "general", "resizeOnBorder", ["Redimensionar pela borda", "Resize on border"], "resize mouse"),
        htog("configs", "general", "snap", ["Encaixe de janelas flutuantes", "Snap floating windows"], "snap float"),
        htog("configs", "general", "allowTearing", ["Permitir tearing", "Allow tearing"], "tearing jogos games latency"),
        hsld("configs", "decoration", "rounding", ["Arredondamento", "Rounding"], "corner canto raio radius", 0, 30, 1, "px"),
        hsld("configs", "decoration", "roundingPower", ["Curvatura do canto", "Corner curve"], "rounding power squircle", 1, 10, 0.1, ""),
        hpct("configs", "decoration", "activeOpacity", ["Opacidade ativa", "Active opacity"], "transparência transparency", 10, 100),
        hpct("configs", "decoration", "inactiveOpacity", ["Opacidade inativa", "Inactive opacity"], "transparência transparency", 10, 100),
        htog("configs", "decoration", "dimInactive", ["Escurecer inativas", "Dim inactive"], "dim escurecer"),
        hpct("configs", "decoration", "dimStrength", ["Intensidade do escurecimento", "Dim strength"], "dim", 0, 100),
        tog("configs", "blur", "blur", ["Desfoque", "Blur"], "blur transparência transparency", () => !!root.sys("blur"), root.setSys("blur")),
        hsld("configs", "blur", "blurSize", ["Raio do desfoque", "Blur size"], "blur", 1, 20, 1, ""),
        hsld("configs", "blur", "blurPasses", ["Passagens", "Passes"], "blur qualidade quality", 1, 6, 1, ""),
        hsld("configs", "blur", "blurNoise", ["Ruído", "Noise"], "blur grain", 0, 0.2, 0.01, ""),
        hpct("configs", "blur", "blurVibrancy", ["Vibração", "Vibrancy"], "blur saturation saturação", 0, 100),
        htog("configs", "blur", "blurXray", ["Xray", "Xray"], "blur xray"),
        htog("configs", "blur", "blurPopups", ["Desfocar popups", "Blur popups"], "blur menus popups"),
        tog("configs", "shadow", "shadow", ["Sombras", "Shadows"], "shadow sombra", () => !!root.sys("shadow"), root.setSys("shadow")),
        hsld("configs", "shadow", "shadowRange", ["Alcance da sombra", "Shadow range"], "shadow", 0, 50, 1, "px"),
        hsld("configs", "shadow", "shadowPower", ["Intensidade da sombra", "Shadow power"], "shadow", 1, 4, 1, ""),
        htog("configs", "shadow", "shadowSharp", ["Sombra nítida", "Sharp shadow"], "shadow"),
        tog("configs", "animations", "hyprAnim", ["Animações do Hyprland", "Hyprland animations"], "animation animação janelas windows transição", () => !!root.sys("animations"), root.setSys("animations")),
        htog("configs", "animations", "wsWrap", ["Animação circular de workspaces", "Workspace wrap-around"], "animation workspaces"),
        htog("configs", "layouts", "preserveSplit", ["Dwindle: manter divisão", "Dwindle: preserve split"], "dwindle split"),
        htog("configs", "layouts", "smartSplit", ["Dwindle: divisão pelo cursor", "Dwindle: smart split"], "dwindle split cursor"),
        hpct("configs", "layouts", "mfact", ["Master: proporção", "Master: ratio"], "master mfact", 10, 90),
        cho("configs", "layouts", "newStatus", ["Master: novas janelas", "Master: new windows"], "master new",
            [{ v: "master", l: "Master" }, { v: "slave", l: "Slave" }, { v: "inherit", l: "Inherit" }], () => root.sys("newStatus"), v => Sys.setValue("newStatus", v)),
        htog("configs", "behavior", "focusOnActivate", ["Focar janelas que pedem atenção", "Focus on activate"], "focus foco"),
        htog("configs", "behavior", "swallow", ["Engolir terminal (swallow)", "Window swallowing"], "swallow terminal"),
        htog("configs", "behavior", "middlePaste", ["Colar com o botão do meio", "Middle-click paste"], "paste colar mouse"),
        hsld("configs", "cursor", "cursorTimeout", ["Esconder cursor parado após", "Hide idle cursor after"], "cursor mouse timeout", 0, 30, 1, "s"),
        htog("configs", "cursor", "hideOnKey", ["Esconder cursor ao digitar", "Hide cursor while typing"], "cursor teclado keyboard"),
        htog("configs", "cursor", "noWarps", ["Não mover o cursor sozinho", "No cursor warps"], "cursor warp"),
        btn("configs", "appearance", "wallpaper", ["Escolher wallpaper", "Choose wallpaper"], "papel de parede fundo background", () => { Popups.closeApp(); Popups.toggleOverlay("wallpaper") }),
        btn("configs", "appearance", "gtk", ["Tema GTK", "GTK theme"], "nwg-look aparência appearance", () => root.run(["nwg-look"])),
        btn("configs", "files", "cHypr", ["Abrir config do Hyprland", "Open Hyprland config"], "hypr hyprland.lua", () => root.open(".config/hypr")),
        btn("configs", "files", "cQs", ["Abrir config do shell", "Open shell config"], "quickshell qml", () => root.open(".config/quickshell")),
        btn("configs", "files", "cRofi", ["Abrir config do Rofi", "Open Rofi config"], "launcher lançador", () => root.open(".config/rofi")),
        btn("configs", "files", "cWall", ["Abrir wallpapers", "Open wallpapers"], "pictures imagens", () => root.open("Pictures/Wallpapers")),
        btn("configs", "files", "cBackup", ["Abrir backups", "Open backups"], "backup restore", () => root.open(".local/share/monolith-dotfiles")),
        btn("configs", "files", "reloadHypr", ["Recarregar Hyprland", "Reload Hyprland"], "reload hyprctl", () => Sys.reloadHyprland()),
        btn("configs", "files", "reloadShell", ["Recarregar shell", "Reload shell"], "reload quickshell restart reiniciar", () => Quickshell.reload(true)),
        btn("configs", "files", "resetHypr", ["Desfazer alterações feitas aqui", "Reset changes made here"], "reset padrão default generated", () => Sys.resetAll(), { confirm: true }),

        // ── bar / shell customization ──
        tog("bar", "modules", "showEqualizer", ["Equalizador animado", "Animated equalizer"], "música music bars barras visualizer", () => Settings.showEqualizer, v => Settings.showEqualizer = v),
        sld("bar", "modules", "persistentWs", ["Workspaces fixos", "Persistent workspaces"], "workspaces áreas de trabalho", 0, 10, 1, "", () => Settings.persistentWorkspaces, v => Settings.persistentWorkspaces = v),
        sld("bar", "modules", "titleMin", ["Título do player: mínimo", "Player title: minimum"], "player música music título title tamanho size caracteres", 6, 40, 1, "", () => Config.titleMin, v => { Settings.titleMin = v; if (Settings.titleMax < v) Settings.titleMax = v }),
        sld("bar", "modules", "titleMax", ["Título do player: máximo", "Player title: maximum"], "player música music título title tamanho size caracteres", 13, 80, 1, "", () => Config.titleMax, v => { Settings.titleMax = v; if (Settings.titleMin > v) Settings.titleMin = v }),
        sld("bar", "modules", "volumeStep", ["Passo do volume", "Volume step"], "scroll roda wheel", 1, 10, 1, "%", () => Settings.volumeStep, v => Settings.volumeStep = v),
        cho("bar", "position", "barPosition", ["Posição da barra", "Bar position"], "barra bar posição position topo top baixo bottom esquerda left direita right lateral vertical",
            [{ v: "top", l: lbl("Topo", "Top") }, { v: "bottom", l: lbl("Embaixo", "Bottom") }, { v: "left", l: lbl("Esquerda", "Left") }, { v: "right", l: lbl("Direita", "Right") }],
            () => Settings.barPosition, v => { Popups.close(); Settings.barPosition = v }),
        cho("bar", "position", "menuStyle", ["Estilo dos menus", "Menu style"], "menus colado attached flutuante floating gaveta drawer",
            [{ v: "auto", l: lbl("Automático", "Auto") }, { v: "attached", l: lbl("Colado à barra", "Attached") }, { v: "floating", l: lbl("Flutuante", "Floating") }],
            () => Settings.menuStyle, v => Settings.menuStyle = v),
        tog("bar", "look", "shellBlur", ["Desfoque (blur) na barra e nos menus", "Blur behind the bar and menus"], "blur desfoque vidro glass transparência",
            () => Settings.shellBlur, v => Sys.setShellBlur(v)),
        sld("bar", "spacing", "barGapStart", ["Início (esquerda / topo)", "Start (left / top)"], "espaçamento spacing gap módulos modules esquerda left",
            0, 30, 1, "px", () => Settings.barGapStart, v => Settings.barGapStart = v),
        sld("bar", "spacing", "barGapCenter", ["Centro", "Center"], "espaçamento spacing gap módulos modules centro center",
            0, 30, 1, "px", () => Settings.barGapCenter, v => Settings.barGapCenter = v),
        sld("bar", "spacing", "barGapEnd", ["Fim (direita / embaixo)", "End (right / bottom)"], "espaçamento spacing gap módulos modules direita right",
            0, 30, 1, "px", () => Settings.barGapEnd, v => Settings.barGapEnd = v),
        tog("bar", "behavior", "hoverMenus", ["Trocar menus ao passar o mouse", "Switch menus on hover"], "hover menus popups mouse", () => Settings.hoverMenus, v => Settings.hoverMenus = v),
        tog("bar", "behavior", "osd", ["Indicador na tela (volume/brilho)", "On-screen display (volume/brightness)"], "osd volume brilho brightness popup", () => Settings.osd, v => Settings.osd = v),
        cho("bar", "behavior", "settingsMode", ["Modo da janela de configurações", "Settings window mode"], "window janela overlay floating flutuante",
            [{ v: "window", l: "Window" }, { v: "overlay", l: "Overlay" }], () => Settings.settingsMode, v => Settings.settingsMode = v),
        tog("bar", "look", "shellAnim", ["Animações do shell", "Shell animations"], "animation animação transição menus transitions", () => Settings.shellAnimations, v => Settings.shellAnimations = v),
        sld("bar", "look", "animSpeed", ["Duração das animações", "Animation duration"], "animation speed velocidade tempo", 50, 200, 10, "%", () => Math.round(Settings.animationScale * 100), v => Settings.animationScale = v / 100),
        sld("bar", "look", "barOpacity", ["Opacidade da barra", "Bar opacity"], "transparência transparency fundo", 0, 100, 5, "%", () => Math.round(Settings.barOpacity * 100), v => Settings.barOpacity = v / 100),
        sld("bar", "look", "menuOpacity", ["Opacidade dos menus", "Menu opacity"], "transparência transparency painel panel", 30, 100, 5, "%", () => Math.round(Settings.menuOpacity * 100), v => Settings.menuOpacity = v / 100),
        { page: "bar", cat: "player", id: "ytmPort", type: "text", label: ["Porta da API do YouTube Music", "YouTube Music API port"], kw: "youtube music ytm api shuffle repeat aleatório repetir",
          get: () => String(Settings.ytmPort), set: v => { const n = parseInt(v); if (n > 0 && n < 65536) { Settings.ytmPort = n; Media.ytmRefresh() } } },
        { page: "bar", cat: "player", id: "ytmToken", type: "text", secret: true, label: ["Token da API do YouTube Music", "YouTube Music API token"], kw: "youtube music ytm api token",
          get: () => Settings.ytmToken, set: v => { Settings.ytmToken = String(v).trim(); Media.ytmRefresh() } },

        // ── audio / microphone ──
        sld("audio", "output", "volume", ["Volume", "Volume"], "som sound", 0, 100, 1, "%", () => Math.round(Audio.volume * 100), v => Audio.setVolume(v / 100)),
        tog("audio", "output", "mute", ["Silenciar", "Mute"], "mudo", () => Audio.muted, v => Audio.toggleMute()),
        btn("audio", "output", "mixer", ["Mixer de áudio", "Audio mixer"], "pavucontrol", () => root.run(["pavucontrol"])),
        sld("mic", "input", "micVolume", ["Volume do microfone", "Microphone volume"], "mic entrada input ganho gain", 0, 100, 1, "%", () => Math.round(Audio.micVolume * 100), v => Audio.setMic(v / 100), { when: () => Audio.source !== null }),
        tog("mic", "input", "micMute", ["Silenciar microfone", "Mute microphone"], "mic mudo", () => Audio.micMuted, v => Audio.toggleMic(), { when: () => Audio.source !== null }),

        // ── notifications ──
        tog("notifications", "general", "ndnd", ["Não perturbe", "Do not disturb"], "dnd silêncio", () => Settings.dnd, v => Settings.dnd = v),
        tog("notifications", "general", "builtinNotifs", ["Notificações do shell", "Shell notifications"], "swaync daemon toast", () => Settings.builtinNotifications, v => Settings.builtinNotifications = v),
        sld("notifications", "popups", "toastTimeout", ["Duração dos avisos", "Popup duration"], "toast tempo timeout", 2, 20, 1, "s", () => Math.round(Settings.toastTimeout / 1000), v => Settings.toastTimeout = v * 1000),
        sld("notifications", "popups", "maxToasts", ["Avisos ao mesmo tempo", "Popups at once"], "toast limite limit", 1, 8, 1, "", () => Settings.maxToasts, v => Settings.maxToasts = v),
        tog("notifications", "popups", "criticalSticky", ["Críticas ficam até fechar", "Critical stay until closed"], "critical urgente urgent", () => Settings.criticalSticky, v => Settings.criticalSticky = v),

        // ── power (laptops) ──
        sld("power", "screen", "pbrightness", ["Brilho", "Brightness"], "backlight luz", 1, 100, 1, "%", () => Math.round(Brightness.fraction * 100), v => Brightness.set(v / 100), { when: () => Brightness.available }),
        tog("power", "general", "pkeepAwake", ["Manter acordado", "Keep awake"], "idle caffeine suspender sleep", () => Settings.keepAwake, v => Settings.keepAwake = v),
        btn("power", "general", "psuspend", ["Suspender", "Suspend"], "sleep", () => Sys.suspend()),
        tog("power", "battery", "batSaver", ["Economia na bateria (sem blur, sombras e animações)", "Battery saver (no blur, shadows or animations)"],
            "economia saver efeitos blur sombra animação energia", () => Settings.batterySaver, v => Settings.batterySaver = v),
        cho("power", "battery", "autoProfile", ["Perfil automático (economia na bateria)", "Automatic profile (saver on battery)"], "power-profiles-daemon perfil tomada ac",
            [{ v: "off", l: lbl("Desligado", "Off") }, { v: "balanced", l: lbl("Equilibrado na tomada", "Balanced on AC") }, { v: "performance", l: lbl("Desempenho na tomada", "Performance on AC") }],
            () => Settings.autoProfile, v => { Settings.autoProfile = v; Battery.profile() }),
        tog("power", "battery", "batAlerts", ["Avisos de bateria fraca (20 / 10 / 5%)", "Low battery alerts (20 / 10 / 5%)"], "aviso alerta low notificação",
            () => Settings.batteryAlerts, v => Settings.batteryAlerts = v),
        cho("power", "battery", "critAction", ["Ação em bateria crítica (5%)", "Critical battery action (5%)"], "crítica suspender hibernar desligar",
            [{ v: "none", l: lbl("Nada", "None") }, { v: "suspend", l: lbl("Suspender", "Suspend") }, { v: "hibernate", l: lbl("Hibernar", "Hibernate") }, { v: "poweroff", l: lbl("Desligar", "Power off") }],
            () => Settings.criticalAction, v => Settings.criticalAction = v),
        cho("power", "battery", "chargeLimit", ["Limite de carga (preserva a bateria)", "Charge limit (preserves the battery)"], "limite carga threshold conservação saúde health",
            [{ v: 100, l: "100%" }, { v: 90, l: "90%" }, { v: 80, l: "80%" }, { v: 60, l: "60%" }],
            () => Battery.limit, v => Battery.setLimit(v), { when: () => Battery.limitFile !== "" }),

        // ── storage / network / bluetooth / update ──
        btn("update", "general", "openRepo", ["Abrir repositório", "Open repository"], "github git site", () => root.run(["xdg-open", root.repoUrl])),
        tog("bluetooth", "general", "btOn", ["Bluetooth", "Bluetooth"], "bluetooth sem fio wireless", () => Bt.enabled, v => Bt.setEnabled(v), { when: () => Bt.present }),
        tog("network", "general", "wifi", ["Wi-Fi", "Wi-Fi"], "wifi rede wireless internet", () => Net.wifiEnabled, v => Net.setWifi(v), { when: () => Net.hasWifi }),
        btn("network", "general", "rescan", ["Procurar redes", "Scan networks"], "wifi scan procurar", () => Net.scan(true), { when: () => Net.hasWifi }),
        btn("network", "general", "netAdv", ["Editor de conexões", "Connection editor"], "nm-connection-editor iwctl networkctl avançado advanced vpn", () => Net.advanced(), { when: () => Net.available }),

        // ── appearance: bar clock (the quick menu editor is drawn by PageAppearance) ──
        tog("appearance", "clock", "clock24", ["Formato 24 horas", "24-hour format"], "relógio hora clock time 12h am pm", () => Settings.clock24, v => Settings.clock24 = v),
        tog("appearance", "clock", "clockSeconds", ["Mostrar segundos", "Show seconds"], "relógio clock segundos seconds", () => Settings.clockSeconds, v => Settings.clockSeconds = v),
        cho("appearance", "clock", "clockDate", ["Data", "Date"], "relógio data date dia",
            ["", "dd/MM/yy", "dd/MM", "ddd dd MMM", "yyyy-MM-dd"].map(f => ({ v: f, l: f ? Qt.formatDate(new Date(), f) : lbl("Sem data", "No date") })),
            () => Settings.clockDate, v => Settings.clockDate = v),
        { page: "appearance", cat: "clock", id: "clockSep", type: "text", label: ["Separador entre hora e data", "Separator between time and date"], kw: "relógio separador clock",
          get: () => Settings.clockSep, set: v => Settings.clockSep = v },
        { page: "appearance", cat: "clock", id: "clockCustom", type: "text", label: ["Formato personalizado (vazio = acima)", "Custom format (empty = above)"],
          kw: "relógio formato custom qt HH mm ss dddd MMMM yyyy", get: () => Settings.clockCustom, set: v => Settings.clockCustom = v },

        // ── profile (picture and preview are drawn by PageProfile) ──
        { page: "profile", cat: "profile", id: "profileName", type: "text", label: ["Nome exibido (vazio = do sistema)", "Display name (empty = system)"], kw: "perfil nome name usuário user",
          get: () => Settings.profileName, set: v => Settings.profileName = v },
        { page: "profile", cat: "profile", id: "profileSubtitle", type: "text", label: ["Subtítulo (vazio = usuário@host)", "Subtitle (empty = user@host)"], kw: "perfil subtítulo bio host",
          get: () => Settings.profileSubtitle, set: v => Settings.profileSubtitle = v },
        tog("profile", "where", "profileInMenu", ["Mostrar no menu rápido", "Show in the quick menu"], "perfil menu rápido avatar", () => Settings.profileInMenu, v => Settings.profileInMenu = v),
        tog("profile", "where", "profileOnLock", ["Mostrar na tela de bloqueio (hyprlock)", "Show on the lock screen (hyprlock)"], "perfil hyprlock bloqueio lock avatar",
            () => Settings.profileOnLock, v => Settings.profileOnLock = v),
        tog("profile", "where", "profileAsLogo", ["Usar a foto no lugar do logo do Arch", "Use the picture instead of the Arch logo"], "perfil logo arch barra bar avatar foto",
            () => Settings.profileAsLogo, v => Settings.profileAsLogo = v),

        // ── launcher (menus/Launcher.qml) ──
        btn("launcher", "general", "lnOpen", ["Abrir o lançador (Super+A)", "Open the launcher (Super+A)"], "launcher lançador apps rofi drun",
            () => { Popups.closeApp(); Popups.toggleOverlay("launcher") }),
        tog("launcher", "results", "lnIcons", ["Mostrar ícones", "Show icons"], "launcher ícones icons", () => Settings.launcherIcons, v => Settings.launcherIcons = v),
        tog("launcher", "results", "lnComments", ["Mostrar descrição dos apps", "Show app descriptions"], "launcher descrição comment",
            () => Settings.launcherComments, v => Settings.launcherComments = v),
        cho("launcher", "results", "lnSort", ["Ordem dos resultados", "Result order"], "launcher ordem sort uso usage nome name",
            [{ v: "usage", l: lbl("Mais usados", "Most used") }, { v: "name", l: lbl("Nome", "Name") }], () => Settings.launcherSort, v => Settings.launcherSort = v),
        sld("launcher", "results", "lnMax", ["Resultados mostrados", "Results shown"], "launcher máximo max", 4, 15, 1, "", () => Settings.launcherMax, v => Settings.launcherMax = v),
        tog("launcher", "search", "lnCalc", ["Calculadora (ex.: 2+2)", "Calculator (e.g. 2+2)"], "launcher calculadora calc math",
            () => Settings.launcherCalc, v => Settings.launcherCalc = v),
        tog("launcher", "search", "lnCmd", ["Executar comandos com \"> comando\"", "Run commands with \"> command\""], "launcher comando command shell run",
            () => Settings.launcherCommands, v => Settings.launcherCommands = v),
        { page: "launcher", cat: "search", id: "lnTerm", type: "text", label: ["Terminal para apps de terminal", "Terminal for terminal apps"], kw: "launcher terminal ghostty kitty",
          get: () => Settings.launcherTerminal, set: v => Settings.launcherTerminal = v.trim() || "ghostty" },
        btn("launcher", "search", "lnReset", ["Zerar histórico de uso", "Clear usage history"], "launcher histórico usage", () => Settings.launcherUsage = ({}), { confirm: true }),

        // ── themes (drawn by PageThemes; these entries feed the search) ──
        cho("themes", "themeMode", "themeMode", ["Tema de cores", "Colour theme"], "tema theme cores colors paleta palette wpgtk wal pywal dinâmico dynamic",
            [{ v: "default", l: root.lbl("Padrão", "Default") }, { v: "dynamic", l: root.lbl("Dinâmico", "Dynamic") }, { v: "preset", l: root.lbl("Predefinido", "Preset") }],
            () => Settings.themeMode, v => Themes.setMode(v)),
        btn("themes", "themeDynamic", "themeRegen", ["Regenerar paleta do wallpaper", "Regenerate wallpaper palette"], "tema theme paleta palette wpgtk cores colors",
            () => { if (Settings.themeMode !== "dynamic") Settings.themeMode = "dynamic"; Themes.regenerate() }),

        // ── wallpapers (menus/WallpaperPicker.qml -> wallpaper-menu: awww / mpvpaper) ──
        btn("wallpaper", "general", "wpOpen", ["Abrir o seletor (Super+D)", "Open the picker (Super+D)"], "wallpaper papel de parede fundo",
            () => { Popups.closeApp(); Popups.toggleOverlay("wallpaper") }),
        { page: "wallpaper", cat: "folders", id: "wpStaticDir", type: "text", label: ["Pasta de imagens (vazio = ~/Pictures/Wallpapers)", "Image folder (empty = ~/Pictures/Wallpapers)"],
          kw: "wallpaper pasta folder imagens images", get: () => Settings.wpStaticDir, set: v => { Settings.wpStaticDir = v.trim(); Wallpapers.images = [] } },
        { page: "wallpaper", cat: "folders", id: "wpLiveDir", type: "text", label: ["Pasta de vídeos (vazio = ~/Videos/wallpaper-live)", "Video folder (empty = ~/Videos/wallpaper-live)"],
          kw: "wallpaper pasta folder vídeos videos live", get: () => Settings.wpLiveDir, set: v => { Settings.wpLiveDir = v.trim(); Wallpapers.videos = [] } },
        cho("wallpaper", "static", "wpTransition", ["Transição", "Transition"], "wallpaper awww transição transition",
            ["fade", "simple", "wipe", "grow", "outer", "wave", "random"].map(t => ({ v: t, l: t })), () => Settings.wpTransition, v => Settings.wpTransition = v),
        sld("wallpaper", "static", "wpDuration", ["Duração da transição", "Transition duration"], "wallpaper awww duração duration", 0, 3, 0.1, " s",
            () => Settings.wpDuration, v => Settings.wpDuration = v),
        tog("wallpaper", "live", "wpAudio", ["Som dos vídeos", "Video sound"], "wallpaper mpvpaper áudio audio som", () => Settings.wpLiveAudio, v => Settings.wpLiveAudio = v),
        tog("wallpaper", "live", "wpPause", ["Pausar quando coberto por janelas", "Pause while covered by windows"], "wallpaper mpvpaper pausar pause energia",
            () => Settings.wpLivePause, v => Settings.wpLivePause = v),
        sld("wallpaper", "picker", "wpColumns", ["Colunas da grade", "Grid columns"], "wallpaper colunas columns grade grid", 2, 8, 1, "", () => Settings.wpColumns, v => Settings.wpColumns = v),
        btn("wallpaper", "picker", "wpClear", ["Apagar prévias geradas", "Delete generated previews"], "wallpaper cache prévias thumbnails",
            () => { root.run([Config.wallpaperMenu, "--clear-cache"]); Wallpapers.images = []; Wallpapers.videos = [] }),

        // ── input ──
        { page: "input", cat: "keyboard", id: "kbLayout", type: "text", label: ["Layout do teclado", "Keyboard layout"], kw: "keyboard teclado layout us br",
          get: () => String(Sys.values.kbLayout || ""), set: v => Sys.setValue("kbLayout", v) },
        hsld("input", "keyboard", "repeatRate", ["Taxa de repetição", "Repeat rate"], "keyboard teclado", 5, 80, 1, "/s"),
        hsld("input", "keyboard", "repeatDelay", ["Atraso da repetição", "Repeat delay"], "keyboard teclado", 100, 1000, 50, "ms"),
        sld("input", "mouse", "sensitivity", ["Sensibilidade do mouse", "Mouse sensitivity"], "pointer cursor velocidade speed", -10, 10, 1, "", () => Math.round(root.sys("sensitivity") * 10), v => Sys.setValue("sensitivity", v / 10)),
        cho("input", "mouse", "followMouse", ["Foco segue o mouse", "Focus follows mouse"], "focus foco hover",
            [{ v: 0, l: "Off" }, { v: 1, l: "Always" }, { v: 2, l: "Click" }, { v: 3, l: "Loose" }], () => root.sys("followMouse"), v => Sys.setValue("followMouse", v)),
        htog("input", "mouse", "naturalMouse", ["Rolagem natural (mouse)", "Natural scroll (mouse)"], "scroll"),
        htog("input", "touchpad", "naturalTouchpad", ["Rolagem natural (touchpad)", "Natural scroll (touchpad)"], "scroll"),
        htog("input", "touchpad", "tapToClick", ["Toque para clicar", "Tap to click"], "touchpad"),
        tog("input", "touchpad", "tpEnabled", ["Touchpad ativado", "Touchpad enabled"], "touchpad desativar disable trackpad",
            () => Settings.touchpadEnabled, v => Sys.setTouchpad(v), { when: () => root.laptop }),
        htog("input", "touchpad", "tpDisableTyping", ["Desativar ao digitar", "Disable while typing"], "touchpad digitar typing palm"),
        hpct("input", "touchpad", "tpScrollFactor", ["Velocidade de rolagem", "Scroll speed"], "touchpad scroll rolagem", 10, 300),
        htog("input", "touchpad", "tpClickfinger", ["Clique com 2 / 3 dedos", "Two / three finger click"], "touchpad clickfinger botão direito right click"),
        htog("input", "touchpad", "tpMiddleEmulation", ["Clique do meio (dois botões juntos)", "Middle click (both buttons)"], "touchpad middle meio"),
        htog("input", "touchpad", "tpTapDrag", ["Tocar e arrastar", "Tap and drag"], "touchpad arrastar drag"),
        cho("input", "touchpad", "tpDragLock", ["Trava de arrasto", "Drag lock"], "touchpad drag lock arrastar",
            [{ v: 0, l: lbl("Desligada", "Off") }, { v: 1, l: lbl("Temporizada", "Timeout") }, { v: 2, l: lbl("Fixa", "Sticky") }], () => root.sys("tpDragLock"), v => Sys.setValue("tpDragLock", v))
    ]

    function text(e) { return Labels.pick(e.label) }
    function byPage(p) { return entries.filter(e => e.page === p && (!e.when || e.when())) }

    // multi-term AND over label + keywords + page name; at most 40 results
    function search(q) {
        const terms = q.toLowerCase().split(/\s+/).filter(x => x.length)
        if (!terms.length) return []
        const visible = pages.map(p => p.id)
        return entries.filter(e => {
            if ((e.when && !e.when()) || visible.indexOf(e.page) < 0) return false
            const hay = (e.label[0] + " " + e.label[1] + " " + (e.kw || "") + " " + e.page + " " + Labels.t("page_" + e.page) + " " + Labels.t("cat_" + e.cat)).toLowerCase()
            return terms.every(t => hay.indexOf(t) >= 0)
        }).slice(0, 40)
    }
}
