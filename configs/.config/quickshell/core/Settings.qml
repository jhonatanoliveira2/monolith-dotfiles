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
    property alias overrides: adapter.overrides     // other Hyprland options, by Sys key: { "kbLayout": "us" }

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

    FileView {
        path: root.ready ? root.dir + "/settings.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.markLoaded()
        onAdapterUpdated: writeAdapter()
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
            property var overrides: ({})
        }
    }
}
