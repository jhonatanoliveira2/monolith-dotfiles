pragma Singleton
import QtQuick
import Quickshell
import "../core"

// Catalog and saved layout of the quick menu (Arch button, menus/SettingsMenu.qml), edited in
// Settings > Appearance. Sections keep the saved order (new sections from later versions are appended);
// shortcuts are built-ins, apps (a shell command) or Settings pages.
Singleton {
    id: root

    readonly property var sectionIds: ["header", "settings", "toggles", "sliders", "hyprland", "shortcuts", "session"]
    readonly property var sections: {
        const saved = Array.from(Settings.quickSections || []).filter(s => s && sectionIds.indexOf(s.id) >= 0)
        return saved.concat(sectionIds.filter(id => !saved.some(s => s.id === id)).map(id => ({ id: id, on: true })))
    }

    readonly property var toggleCatalog: [
        { id: "wifi", icon: Theme.glyph.wifi, label: () => "Wi-Fi", when: () => Net.hasWifi, get: () => Net.wifiEnabled, set: c => Net.setWifi(c) },
        { id: "bluetooth", icon: Theme.glyph.btOn, label: () => "Bluetooth", when: () => Bt.present, get: () => Bt.enabled, set: c => Bt.setEnabled(c) },
        { id: "dnd", icon: Theme.glyph.bellOff, label: () => Strings.t("dnd"), get: () => Settings.dnd, set: c => Settings.dnd = c },
        { id: "keepAwake", icon: Theme.glyph.power, label: () => Strings.t("keepAwake"), get: () => Settings.keepAwake, set: c => Settings.keepAwake = c },
        { id: "darkMode", icon: Theme.glyph.moon, label: () => Strings.t("darkMode"), get: () => Sys.darkMode, set: c => Sys.setDark(c) },
        { id: "batterySaver", icon: Theme.glyph.saver, label: () => Strings.t("batSaver"), when: () => Battery.present, get: () => Settings.batterySaver, set: c => Settings.batterySaver = c },
        { id: "touchpad", icon: Theme.g(0xf245), label: () => "Touchpad", when: () => Battery.present, get: () => Settings.touchpadEnabled, set: c => Sys.setTouchpad(c) }
    ]
    readonly property var toggles: toggleCatalog.filter(t => Array.from(Settings.quickToggles || []).indexOf(t.id) >= 0)

    readonly property var builtins: [
        { id: "wallpaper", icon: Theme.g(0xf03e), label: "wallpaper", run: () => Popups.toggleOverlay("wallpaper") },
        { id: "mixer", icon: Theme.glyph.vol, label: "mixer", run: () => launch(["pavucontrol"]) },
        { id: "network", icon: Theme.glyph.wifi, label: "network", run: () => { Popups.close(); Net.advanced() } },
        { id: "bluetooth", icon: Theme.glyph.btOn, label: "bluetooth", run: () => launch(["blueman-manager"]) },
        { id: "gtkTheme", icon: Theme.g(0xf1fc), label: "gtkTheme", run: () => launch(["nwg-look"]) },
        { id: "launcher", icon: Theme.g(0xf135), label: "launcher", run: () => Popups.toggleOverlay("launcher") },
        { id: "reloadHypr", icon: Theme.glyph.refresh, label: "reloadHypr", run: () => Sys.reloadHyprland() },
        { id: "reloadShell", icon: Theme.glyph.refresh, label: "reloadShell", run: () => Quickshell.reload(true) }
    ]
    readonly property var shortcuts: {
        const saved = Settings.quickShortcuts
        // null = defaults (a list loaded from settings.json is not a plain JS array: copy it)
        return saved !== null && saved !== undefined ? Array.from(saved) : builtins.map(b => ({ k: "builtin", v: b.id }))
    }

    readonly property var sessionCatalog: [
        { id: "lock", icon: Theme.glyph.lock, run: () => { Popups.close(); Sys.lock() } },
        { id: "suspend", icon: Theme.glyph.sleep, run: () => { Popups.close(); Sys.suspend() } },
        { id: "hibernate", icon: Theme.glyph.sleep, confirm: true, run: () => { Popups.close(); Quickshell.execDetached(["systemctl", "hibernate"]) } },
        { id: "logout", icon: Theme.glyph.out, confirm: true, run: () => Sys.logout() },
        { id: "reboot", icon: Theme.glyph.reboot, confirm: true, run: () => Sys.reboot() },
        { id: "poweroff", icon: Theme.glyph.power, confirm: true, run: () => Sys.poweroff() }
    ]
    readonly property var session: sessionCatalog.filter(s => Array.from(Settings.quickSession || []).indexOf(s.id) >= 0)

    function launch(cmd) { Popups.close(); Quickshell.execDetached(cmd) }
    function builtin(id) { return builtins.find(b => b.id === id) || null }
    function label(s) {
        if (s.k === "builtin") { const b = builtin(s.v); return b ? (b.label === "bluetooth" ? "Bluetooth" : Strings.t(b.label)) : s.v }
        return s.l || s.v
    }
    function icon(s) {
        if (s.k === "builtin") { const b = builtin(s.v); return b ? b.icon : "" }
        return s.k === "page" ? Theme.glyph.cog : Theme.g(0xf135)
    }
    function run(s) {
        if (s.k === "builtin") { const b = builtin(s.v); if (b) b.run() }
        else if (s.k === "page") Popups.openApp(s.v)
        else if (s.k === "app") launch(["sh", "-c", s.v])
    }

    // ── editing (Settings > Appearance); every change stores a new array so the adapter saves it ──
    function moved(list, i, dir) {
        const j = i + dir, l = list.slice()
        if (j < 0 || j >= l.length) return l
        const t = l[i]; l[i] = l[j]; l[j] = t
        return l
    }
    function setSection(id, on) { Settings.quickSections = sections.map(s => ({ id: s.id, on: s.id === id ? on : s.on })) }
    function moveSection(i, dir) { Settings.quickSections = moved(sections.map(s => ({ id: s.id, on: s.on })), i, dir) }
    function flip(key, id) {
        const l = Array.from(Settings[key] || []), i = l.indexOf(id)
        if (i >= 0) l.splice(i, 1); else l.push(id)
        Settings[key] = l
    }
    function addShortcut(k, v, l) {
        v = String(v || "").trim()
        if (!v) return
        Settings.quickShortcuts = shortcuts.concat([{ k: k, v: v, l: String(l || "").trim() }])
    }
    function removeShortcut(i) { const l = shortcuts.slice(); l.splice(i, 1); Settings.quickShortcuts = l }
    function moveShortcut(i, dir) { Settings.quickShortcuts = moved(shortcuts, i, dir) }
    function reset() {
        Settings.quickSections = []
        Settings.quickToggles = ["wifi", "dnd", "keepAwake", "darkMode"]
        Settings.quickShortcuts = null
        Settings.quickSession = ["lock", "suspend", "logout", "reboot", "poweroff"]
    }
}
