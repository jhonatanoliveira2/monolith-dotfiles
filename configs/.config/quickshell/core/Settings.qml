pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Preferences saved in ~/.local/state/quickshell-monolith/settings.json.
// Hyprland values use -1 = "not touched from the menu" (your hyprland.lua stays in charge).
Singleton {
    id: root
    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias gapsIn: adapter.gapsIn
    property alias gapsOut: adapter.gapsOut
    property alias borderSize: adapter.borderSize
    property alias rounding: adapter.rounding
    property alias animations: adapter.animations
    property alias blur: adapter.blur
    property alias shadow: adapter.shadow
    // shell preferences (Settings app)
    property alias language: adapter.language
    property alias shellAnimations: adapter.shellAnimations
    property alias animationScale: adapter.animationScale
    property alias barOpacity: adapter.barOpacity
    property alias menuOpacity: adapter.menuOpacity
    property alias builtinNotifications: adapter.builtinNotifications
    property alias showPlayer: adapter.showPlayer
    property alias showEqualizer: adapter.showEqualizer
    property alias showSysmon: adapter.showSysmon
    property alias showWindowTitle: adapter.showWindowTitle
    property alias hoverMenus: adapter.hoverMenus
    property alias osd: adapter.osd
    property alias persistentWorkspaces: adapter.persistentWorkspaces
    property alias titleMin: adapter.titleMin
    property alias titleMax: adapter.titleMax
    property alias volumeStep: adapter.volumeStep
    property alias settingsMode: adapter.settingsMode
    property alias repoPath: adapter.repoPath
    property alias toastTimeout: adapter.toastTimeout
    property alias maxToasts: adapter.maxToasts
    property alias criticalSticky: adapter.criticalSticky
    property alias ytmPort: adapter.ytmPort
    property alias ytmToken: adapter.ytmToken
    property alias batteryAlerts: adapter.batteryAlerts
    property alias criticalAction: adapter.criticalAction
    property alias autoProfile: adapter.autoProfile
    property alias batterySaver: adapter.batterySaver
    property alias touchpadEnabled: adapter.touchpadEnabled
    property alias quickSections: adapter.quickSections
    property alias quickToggles: adapter.quickToggles
    property alias quickShortcuts: adapter.quickShortcuts
    property alias quickSession: adapter.quickSession
    property alias clock24: adapter.clock24
    property alias clockSeconds: adapter.clockSeconds
    property alias clockDate: adapter.clockDate
    property alias clockSep: adapter.clockSep
    property alias clockCustom: adapter.clockCustom
    property alias profileName: adapter.profileName
    property alias profileSubtitle: adapter.profileSubtitle
    property alias profileAvatar: adapter.profileAvatar
    property alias profileInMenu: adapter.profileInMenu
    property alias profileOnLock: adapter.profileOnLock
    property alias profileAsLogo: adapter.profileAsLogo
    property alias barPosition: adapter.barPosition
    property alias barModules: adapter.barModules
    property alias barGapStart: adapter.barGapStart
    property alias barGapCenter: adapter.barGapCenter
    property alias barGapEnd: adapter.barGapEnd
    property alias menuStyle: adapter.menuStyle
    property alias shellBlur: adapter.shellBlur
    property alias launcherIcons: adapter.launcherIcons
    property alias launcherComments: adapter.launcherComments
    property alias launcherSort: adapter.launcherSort
    property alias launcherMax: adapter.launcherMax
    property alias launcherUsage: adapter.launcherUsage
    property alias launcherCalc: adapter.launcherCalc
    property alias launcherCommands: adapter.launcherCommands
    property alias launcherTerminal: adapter.launcherTerminal
    property alias wpStaticDir: adapter.wpStaticDir
    property alias wpLiveDir: adapter.wpLiveDir
    property alias wpTransition: adapter.wpTransition
    property alias wpDuration: adapter.wpDuration
    property alias wpLiveAudio: adapter.wpLiveAudio
    property alias wpLivePause: adapter.wpLivePause
    property alias wpColumns: adapter.wpColumns
    property alias overrides: adapter.overrides     // other Hyprland options, by Sys key: { "kbLayout": "us" }

    readonly property bool barVertical: barPosition === "left" || barPosition === "right"
    // pattern of the bar clock (Qt.formatDateTime)
    readonly property string clockPattern: clockCustom.trim() !== "" ? clockCustom
        : (clock24 ? "HH:mm" : "h:mm") + (clockSeconds ? ":ss" : "") + (clock24 ? "" : " AP") + (clockDate ? clockSep + clockDate : "")
    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell-monolith"
    property bool ready: false
    property bool loaded: false          // true once settings.json was read (or created)
    signal loadedOnce()

    function markLoaded() { if (!loaded) { loaded = true; loadedOnce() } }

    Process {
        command: ["mkdir", "-p", root.dir]
        running: true
        onExited: root.ready = true
    }

    // Writes are batched (several changes in a row become one write) and the change notification caused by
    // our own write is ignored: reloading it would bring back a half-written state and drop later changes.
    // Edits made to the file by hand are still picked up.
    property double lastWrite: 0
    Timer { id: writeSoon; interval: 80; onTriggered: { root.lastWrite = Date.now(); file.writeAdapter() } }
    FileView {
        id: file
        path: root.ready ? root.dir + "/settings.json" : ""
        watchChanges: true
        onFileChanged: if (!writeSoon.running && Date.now() - root.lastWrite > 1000) reload()
        onLoaded: root.markLoaded()
        onAdapterUpdated: writeSoon.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter()
            root.markLoaded()
        }
        adapter: JsonAdapter {
            id: adapter
            property bool dnd: false
            property bool keepAwake: false
            property int gapsIn: -1
            property int gapsOut: -1
            property int borderSize: -1
            property int rounding: -1
            property int animations: -1
            property int blur: -1
            property int shadow: -1
            property string language: "pt"
            property bool shellAnimations: true
            property real animationScale: 1.0
            property real barOpacity: 0.5
            property real menuOpacity: 0.86
            property bool builtinNotifications: true
            property bool showPlayer: true
            property bool showEqualizer: true
            property bool showSysmon: true
            property bool showWindowTitle: false
            property bool hoverMenus: true
            property bool osd: true
            property int persistentWorkspaces: 0
            property int titleMin: 13
            property int titleMax: 30
            property int volumeStep: 2
            property string settingsMode: "window"
            property string repoPath: ""
            property int toastTimeout: 6000        // ms
            property int maxToasts: 4
            property bool criticalSticky: true
            property int ytmPort: 26538            // th-ch/youtube-music "API Server" plugin
            property string ytmToken: ""
            property bool batteryAlerts: true      // toasts at 20 / 10 / 5 %
            property string criticalAction: "none" // at 5 %: none | suspend | hibernate | poweroff
            property string autoProfile: "off"     // off | balanced | performance (profile on AC; saver on battery)
            property bool batterySaver: false      // blur, shadows and animations off on battery
            property bool touchpadEnabled: true
            // quick menu (Arch button): sections in order, quick switches, shortcuts and session buttons (services/QuickMenu.qml)
            property var quickSections: []        // [{ id, on }] — empty = defaults
            property var quickToggles: ["wifi", "dnd", "keepAwake", "darkMode"]
            property var quickShortcuts: null     // [{ k: "builtin" | "app" | "page", v, l }] — null = defaults
            property var quickSession: ["lock", "suspend", "logout", "reboot", "poweroff"]
            // bar clock: clockCustom (Qt date format) wins over the presets
            property bool clock24: true
            property bool clockSeconds: false
            property string clockDate: "dd/MM/yy"  // "" = no date
            property string clockSep: " ~ "
            property string clockCustom: ""
            // profile (services/Profile.qml)
            property string profileName: ""        // "" = real name from passwd, else the user name
            property string profileSubtitle: ""    // "" = user@host
            property string profileAvatar: ""      // copy kept in the state dir
            property bool profileInMenu: true
            property bool profileOnLock: true
            property bool profileAsLogo: false
            // bar: edge of the screen and the modules of each zone (services/BarLayout.qml)
            property string barPosition: "top"     // top | bottom | left | right
            property var barModules: null          // { start: [ids], center: [ids], end: [ids] } — null = defaults
            property int barGapStart: 6            // px between the modules of each zone
            property int barGapCenter: 6
            property int barGapEnd: 6
            property string menuStyle: "auto"      // auto (attached on the sides / bottom) | attached | floating
            property bool shellBlur: true          // compositor blur behind the bar, menus, toasts and OSD
            // app launcher (menus/Launcher.qml)
            property bool launcherIcons: true
            property bool launcherComments: true
            property string launcherSort: "usage"  // usage | name
            property int launcherMax: 8
            property var launcherUsage: ({})       // desktop entry id -> launches
            property bool launcherCalc: true       // "2+2" shows the result
            property bool launcherCommands: true   // "> cmd" runs a command
            property string launcherTerminal: "ghostty"   // for Terminal=true apps
            // wallpaper picker (menus/WallpaperPicker.qml -> ~/.local/bin/wallpaper-menu)
            property string wpStaticDir: ""        // "" = ~/Pictures/Wallpapers
            property string wpLiveDir: ""          // "" = ~/Videos/wallpaper-live
            property string wpTransition: "fade"   // awww transition type
            property real wpDuration: 0.7
            property bool wpLiveAudio: false
            property bool wpLivePause: true        // pause live wallpapers while covered
            property int wpColumns: 4
            property var overrides: ({})
        }
    }
}
