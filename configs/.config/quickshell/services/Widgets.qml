pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core"

// Desktop widgets: the catalogue of widget types and the placed instances (Settings.widgets, kept across
// restarts). Drawn by WidgetLayer.qml on the desktop (bottom layer, under the windows) and, in edit mode, on an
// overlay where they are dragged, resized, added and removed.
//
// Sizes: every widget comes in small / medium / large (entry.size 0..2, medium when missing). All widgets of a
// size have the same width (`width` x `scales[size]`, so they line up in columns); the height is the type's `h`
// at that scale, and the widget's file gets the factor as `k` to scale its contents.
//
// Workspaces: every widget belongs to the workspace it was added on (entry.workspace, a Hyprland workspace id)
// and shows only there. Saved widgets keep it across restarts; ones saved before this existed are given the
// workspace their monitor shows when the shell starts (once).
//
// Temporary widgets (Widgets.addTemp, from the widget editor, Super+B): kept only in memory, so they are gone when the
// shell restarts, like a program's window; they also ignore "hide when a program is open".
//
// Adding a widget type: create widgets/<Name>Widget.qml (an Item that fills its parent and declares
// `property real k: 1`; see ClockWidget.qml) and add one line to `types` below with its id, name, glyph,
// medium height and file.
Singleton {
    id: root
    property bool editing: false
    readonly property int grid: 8            // positions snap to this
    readonly property var scales: [0.8, 1, 1.3]
    readonly property int width: 320            // every widget, medium size (small 256, large 416)
    readonly property var sizeNames: [["P", "S"], ["M", "M"], ["G", "L"]]

    readonly property var types: [
        { id: "clock", glyph: 0xf017, name: ["Relógio", "Clock"], desc: ["Hora e data", "Time and date"], h: 128, file: "ClockWidget.qml" },
        { id: "system", glyph: 0xf4bc, name: ["Sistema", "System"], desc: ["CPU, RAM e GPU", "CPU, RAM and GPU"], h: 128, file: "SystemWidget.qml" },
        { id: "weather", glyph: 0xf0590, name: ["Clima", "Weather"], desc: ["Tempo agora (Open-Meteo)", "Current weather (Open-Meteo)"], h: 128, file: "WeatherWidget.qml" },
        { id: "media", glyph: 0xf0ea2, name: ["Mídia", "Media"], desc: ["Música tocando e controles", "Now playing and controls"], h: 104, file: "MediaWidget.qml" },
        { id: "lyrics", glyph: 0xf0c9, name: ["Letra", "Lyrics"], desc: ["Letra karaokê da música tocando", "Karaoke lyrics of the playing song"], h: 200, file: "LyricsWidget.qml" }
    ]
    function type(id) { return types.find(t => t.id === id) || null }
    function name(t) { return t ? t.name[Settings.language === "en" ? 1 : 0] : "" }
    function sizeOf(w) { const s = w ? w.size : 1; return s === 0 || s === 2 ? s : 1 }
    function sizeName(s) { return sizeNames[s][Settings.language === "en" ? 1 : 0] }
    // card size of a placed widget (or of a type at a size)
    function dims(w, size) {
        const t = type(w.type || w.id), k = scales[size !== undefined ? size : sizeOf(w)]
        return t ? { w: Math.round(root.width * k / grid) * grid, h: Math.round(t.h * k / grid) * grid, k: k } : { w: 0, h: 0, k: 1 }
    }

    readonly property var list: (Settings.widgets || []).filter(w => w && type(w.type))
    // widgets of one monitor; those of a monitor that is not connected show on the first one
    function onScreen(screenName) {
        const names = Quickshell.screens.map(s => s.name)
        const first = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
        return list.filter(w => w.screen === screenName || (names.indexOf(w.screen) < 0 && screenName === first))
    }

    // the saved widgets of one monitor on one workspace
    function onWorkspace(screenName, workspaceId) { return onScreen(screenName).filter(w => w.workspace === undefined || w.workspace === workspaceId) }
    function activeWorkspaceOf(screenName) {
        const mon = Hyprland.monitors.values.find(m => m.name === screenName) || Hyprland.focusedMonitor
        return mon && mon.activeWorkspace ? mon.activeWorkspace.id : undefined
    }
    // widgets saved before workspaces existed: put each on the workspace its monitor shows now (once)
    function migrate() {
        if (!Settings.loaded || !(Settings.widgets || []).some(w => w && w.workspace === undefined)) return true
        if (!Hyprland.focusedMonitor || !Hyprland.focusedMonitor.activeWorkspace) return false
        Settings.widgets = (Settings.widgets || []).map(w => !w || w.workspace !== undefined ? w
            : Object.assign({}, w, { workspace: activeWorkspaceOf(w.screen) !== undefined ? activeWorkspaceOf(w.screen) : 1 }))
        console.log("[widgets] saved widgets assigned to their monitor's current workspace")
        return true
    }
    Timer { id: migrateSoon; interval: 500; repeat: true; running: true; property int tries: 0
            onTriggered: if (root.migrate() || ++tries > 40) stop() }

    property var temps: []               // [{ uid, type, screen, workspace, x, y, size, temp: true }]
    function tempsOn(workspaceId) { return temps.filter(w => w.workspace === workspaceId) }

    function newUid() { return Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36) }
    function add(typeId, screenName) {
        const t = type(typeId)
        const scr = Quickshell.screens.find(s => s.name === screenName) || Quickshell.screens[0]
        if (!t || !scr) return
        const ws = activeWorkspaceOf(scr.name)
        const spot = freeSpot(scr, dims(t, 1), "", [], ws)
        const w = { uid: newUid(), type: typeId, screen: scr.name, workspace: ws !== undefined ? ws : 1, x: spot.x, y: spot.y, size: 1 }
        console.log("[widgets] add", typeId, "on", scr.name, "at", w.x + "," + w.y)
        Settings.widgets = list.concat([w])
    }
    // a temporary widget on the current workspace of a monitor (default: the focused one)
    function addTemp(typeId, screenName) {
        const t = type(typeId)
        const mon = screenName ? Hyprland.monitors.values.find(m => m.name === screenName) || null : Hyprland.focusedMonitor
        const scr = mon ? Quickshell.screens.find(s => s.name === mon.name) : Quickshell.screens[0]
        if (!t || !scr || !mon || !mon.activeWorkspace) return
        const ws = mon.activeWorkspace.id
        const spot = freeSpot(scr, dims(t, 1), "", tempsOn(ws), ws)
        console.log("[widgets] temporary", typeId, "on workspace", ws)
        temps = temps.concat([{ uid: newUid(), type: typeId, screen: scr.name, workspace: ws, x: spot.x, y: spot.y, size: 1, temp: true }])
    }
    // first place (left to right, top to bottom, 24 px margin) where a `d`-sized widget overlaps no other one
    // (of the same workspace, when given)
    function freeSpot(scr, d, skipUid, extra, ws) {
        const others = (ws === undefined ? onScreen(scr.name) : onWorkspace(scr.name, ws)).concat(extra || []).filter(o => o.uid !== skipUid).map(o => Object.assign({ x: o.x, y: o.y }, dims(o)))
        const m = 24, top = 128            // below the edit toolbar
        const free = (x, y) => others.every(o => x + d.w + m <= o.x || o.x + o.w + m <= x || y + d.h + m <= o.y || o.y + o.h + m <= y)
        for (let y = top; y + d.h <= scr.height - m; y += grid * 2)
            for (let x = m; x + d.w <= scr.width - m; x += grid * 2)
                if (free(x, y)) return { x: x, y: y }
        return { x: Math.round((scr.width - d.w) / 2 / grid) * grid, y: Math.round(scr.height / 3 / grid) * grid }
    }
    // changes go to the list that holds the widget: Settings (saved) or `temps` (memory only)
    function change(uid, f) {
        if (temps.some(w => w.uid === uid)) temps = temps.map(w => w.uid === uid ? f(w) : w).filter(w => w)
        else Settings.widgets = list.map(w => w.uid === uid ? f(w) : w).filter(w => w)
    }
    function remove(uid) { console.log("[widgets] remove", uid); change(uid, w => null) }
    function move(uid, x, y) {
        const snap = v => Math.max(0, Math.round(v / grid) * grid)
        change(uid, w => Object.assign({}, w, { x: snap(x), y: snap(y) }))
    }
    // new size, kept on screen: a widget that would run past the edge is pulled back in
    function resize(uid, size) {
        change(uid, w => {
            const scr = Quickshell.screens.find(s => s.name === w.screen) || Quickshell.screens[0]
            const d = dims(w, size)
            const x = scr ? Math.max(0, Math.min(w.x, scr.width - d.w)) : w.x
            const y = scr ? Math.max(0, Math.min(w.y, scr.height - d.h)) : w.y
            return Object.assign({}, w, { size: size, x: x, y: y })
        })
    }
    function edit(on) {
        editing = on
        console.log("[widgets] edit mode", on ? "on" : "off")
        if (on) { Popups.close(); Popups.closeApp() }
    }
}
