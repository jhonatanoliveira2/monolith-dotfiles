pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// "Nothing" theme: dot-matrix / LED identity (inspired by NIHIL Shell, MIT; not affiliated with Nothing
// Technology Limited). Its design tokens and defaults are written to ~/.config/monolith/nothing.json by Nix
// on NixOS (monolith.nothingTheme, nix/modules/home-nothing.nix) and by scripts/nothing-theme.sh on Arch
// Linux / CachyOS, from the same tokens (nix/nothing/tokens.json); without that file (theme off) `available`
// is false and the shell looks exactly as before. Runtime changes (Settings > Themes > Nothing) are stored as
// overrides in Settings.nothing; reset() returns to the defaults of that file.
// wallpaper-menu reads the same two files, so a wallpaper chosen from rofi follows the same look.
Singleton {
    id: root

    readonly property var data: {
        const t = cfgFile.text()
        if (!t) return ({})
        try { return JSON.parse(t) } catch (e) { console.warn("[nothing] nothing.json:", e); return ({}) }
    }
    readonly property bool available: !!data.defaults
    readonly property var defaults: data.defaults || ({})
    readonly property var overrides: Settings.nothing || ({})
    readonly property var effective: Object.assign({}, defaults, overrides)
    function get(k) { return overrides[k] !== undefined ? overrides[k] : defaults[k] }
    // defaults the shell has when nothing.json does not set them
    readonly property var fallbacks: ({ widgetOpacity: 0.85 })
    function set(k, v) {
        const o = Object.assign({}, overrides)
        if (v === (defaults[k] !== undefined ? defaults[k] : fallbacks[k])) delete o[k]; else o[k] = v
        Settings.nothing = o
        if (wallpaperKeys.indexOf(k) >= 0) wallpaperSoon.restart()
    }
    // wallpaper contrast and brightness back to the Nix defaults (Settings > Themes > Nothing)
    function resetTone() {
        const o = Object.assign({}, overrides)
        delete o.contrast; delete o.brightness
        Settings.nothing = o
        wallpaperSoon.restart()
    }
    readonly property bool toneChanged: overrides.contrast !== undefined || overrides.brightness !== undefined
    function reset() { Settings.nothing = ({}); wallpaperSoon.restart() }
    readonly property bool customised: Object.keys(overrides).length > 0

    // ── effective values ──
    readonly property bool active: available && get("enabled") === true
    readonly property bool monochrome: active && get("monochrome") !== false
    readonly property bool edgeGlow: active && get("edgeGlow") === true
    readonly property string ledShape: get("ledShape") || "circle"
    readonly property int ledSize: Math.max(1, Number(get("ledSize")) || 6)
    readonly property int ledSpacing: Math.max(0, Number(get("ledSpacing")) || 0)
    readonly property string wallpaperStyle: get("wallpaperStyle") || "original"
    // desktop widget cards: a light glass of their own (85 %), apart from Settings.widgetOpacity, which stays
    // the default theme's; Settings > Widgets edits this one while the theme is on (an override, see set())
    readonly property real widgetOpacity: {
        const v = Number(get("widgetOpacity"))
        return get("widgetOpacity") === undefined || isNaN(v) ? fallbacks.widgetOpacity : Math.max(0, Math.min(1, v))
    }

    // wallpaper look changed: services/Wallpapers.qml re-applies the current still wallpaper
    readonly property var wallpaperKeys: ["enabled", "monochrome", "ledShape", "ledSize", "ledSpacing", "wallpaperStyle", "dither", "levels", "invert", "contrast", "brightness"]
    signal wallpaperChanged()
    Timer { id: wallpaperSoon; interval: 700; onTriggered: root.wallpaperChanged() }

    // ── tokens (Nix), with the original values as fallbacks ──
    readonly property var pal: data.palette || ({})
    function c(k, fb) { return pal[k] || fb }
    readonly property string ink: c("ink", "#f2f2f2")
    readonly property string dim: c("dim", "#a3a3a3")
    readonly property string muted: c("muted", "#7a7a7a")
    readonly property string off: c("off", "#333333")
    readonly property string line: c("line", "#2a2a2a")
    readonly property string raised: c("raised", "#1a1a1a")
    readonly property string surface: c("surface", "#0e0e0e")
    readonly property string alert: c("alert", "#d71921")      // critical alerts only, never decoration
    // the same token set as core/Palettes.qml, so Theme can use it in place of a colour theme
    readonly property var palette: ({
        id: "nothing", background: c("surface", "#0e0e0e"), foreground: c("ink", "#f2f2f2"), white: "#ffffff",
        grayLight: "#d4d4d4", grayMid: c("muted", "#7a7a7a"), grayDark: c("off", "#333333"), accent: "#ffffff",
        line: "#a8a8a8", bar: c("void", "#000000"), panel: c("void", "#000000"), tint: "#ffffff",
        onAccent: "#000000", onForeground: "#000000", ansi: null
    })

    // fonts: Doto (dot matrix, display sizes only), Space Grotesk, Space Mono; each falls back when missing
    readonly property var fonts: data.fonts || ({})
    readonly property var families: Qt.fontFamilies()
    // (Qt adds the foundry when two files of a family differ in it: "Space Mono [CF  ]")
    function has(f) { return !!f && families.some(x => x === f || x.indexOf(f + " [") === 0) }
    readonly property string fontMono: has(fonts.mono) ? fonts.mono : "JetBrainsMono Nerd Font"
    readonly property string fontSans: has(fonts.sans) ? fonts.sans : fontMono
    readonly property string fontDot: has(fonts.dot) ? fonts.dot : fontMono
    readonly property bool hasDot: has(fonts.dot)

    // build-time wallpapers (rebuild): monitors rendered by Nix
    readonly property var builtOutputs: (data.wallpapers && data.wallpapers.outputs) || []

    // The first time the theme is active its bar look is applied (on the left, in frame style - NIHIL Shell's
    // layout); after that Settings > Bar is in charge, with or without the theme. Without the theme the shell
    // keeps its own defaults (top, capsule).
    function applyLookOnce() {
        if (!Settings.loaded || !active || Settings.nothingLookDone) return
        Settings.barPosition = "left"
        Settings.barStyle = "frame"
        Settings.nothingLookDone = true
    }
    onActiveChanged: applyLookOnce()
    Connections { target: Settings; function onLoadedOnce() { root.applyLookOnce() } }
    Component.onCompleted: applyLookOnce()

    // nothing.json written or removed while the shell runs (a rebuild, scripts/nothing-theme.sh on / off): the
    // current wallpaper follows. Not on the first read at startup, which only restores what is already shown.
    property bool settled: false
    onAvailableChanged: if (settled) wallpaperSoon.restart()
    Timer { id: settle; interval: 0; onTriggered: root.settled = true }
    // a file that does not exist is not watched: look for it again now and then until it appears
    Timer { interval: 4000; repeat: true; running: !root.available; onTriggered: cfgFile.reload() }

    FileView {
        id: cfgFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/monolith/nothing.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: if (!root.settled) settle.start()
        onLoadFailed: if (!root.settled) settle.start()
    }
}
