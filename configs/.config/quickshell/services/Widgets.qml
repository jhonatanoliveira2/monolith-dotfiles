pragma Singleton
import QtQuick
import Quickshell
import "../core"

// Desktop widgets: the catalogue of widget types and the placed instances (Settings.widgets, kept across
// restarts). Drawn by WidgetLayer.qml on the desktop (bottom layer, under the windows) and, in edit mode, on an
// overlay where they are dragged, added and removed.
//
// Adding a widget type: create widgets/<Name>Widget.qml (an Item that fills its parent; see ClockWidget.qml)
// and add one line to `types` below with its id, name, glyph, size and file.
Singleton {
    id: root
    property bool editing: false
    readonly property int grid: 8            // positions snap to this

    readonly property var types: [
        { id: "clock", glyph: 0xf017, name: ["Relógio", "Clock"], desc: ["Hora e data", "Time and date"], w: 280, h: 128, file: "ClockWidget.qml" },
        { id: "system", glyph: 0xf4bc, name: ["Sistema", "System"], desc: ["CPU, RAM e GPU", "CPU, RAM and GPU"], w: 300, h: 128, file: "SystemWidget.qml" },
        { id: "weather", glyph: 0xf0590, name: ["Clima", "Weather"], desc: ["Tempo agora (wttr.in)", "Current weather (wttr.in)"], w: 240, h: 128, file: "WeatherWidget.qml" },
        { id: "media", glyph: 0xf0ea2, name: ["Mídia", "Media"], desc: ["Música tocando e controles", "Now playing and controls"], w: 340, h: 104, file: "MediaWidget.qml" }
    ]
    function type(id) { return types.find(t => t.id === id) || null }
    function name(t) { return t ? t.name[Settings.language === "en" ? 1 : 0] : "" }

    readonly property var list: (Settings.widgets || []).filter(w => w && type(w.type))
    // widgets of one monitor; those of a monitor that is not connected show on the first one
    function onScreen(screenName) {
        const names = Quickshell.screens.map(s => s.name)
        const first = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
        return list.filter(w => w.screen === screenName || (names.indexOf(w.screen) < 0 && screenName === first))
    }

    function add(typeId, screenName) {
        const t = type(typeId)
        const scr = Quickshell.screens.find(s => s.name === screenName) || Quickshell.screens[0]
        if (!t || !scr) return
        const spot = freeSpot(scr, t)
        const w = { uid: Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36), type: typeId, screen: scr.name, x: spot.x, y: spot.y }
        console.log("[widgets] add", typeId, "on", scr.name, "at", w.x + "," + w.y)
        Settings.widgets = list.concat([w])
    }
    // first place (left to right, top to bottom, 24 px margin) where a `t` widget overlaps no other one
    function freeSpot(scr, t) {
        const others = onScreen(scr.name).map(o => { const ot = type(o.type); return { x: o.x, y: o.y, w: ot.w, h: ot.h } })
        const m = 24, top = 128            // below the edit toolbar
        const free = (x, y) => others.every(o => x + t.w + m <= o.x || o.x + o.w + m <= x || y + t.h + m <= o.y || o.y + o.h + m <= y)
        for (let y = top; y + t.h <= scr.height - m; y += grid * 2)
            for (let x = m; x + t.w <= scr.width - m; x += grid * 2)
                if (free(x, y)) return { x: x, y: y }
        return { x: Math.round((scr.width - t.w) / 2 / grid) * grid, y: Math.round(scr.height / 3 / grid) * grid }
    }
    function remove(uid) { console.log("[widgets] remove", uid); Settings.widgets = list.filter(w => w.uid !== uid) }
    function move(uid, x, y) {
        const snap = v => Math.max(0, Math.round(v / grid) * grid)
        Settings.widgets = list.map(w => w.uid === uid ? Object.assign({}, w, { x: snap(x), y: snap(y) }) : w)
    }
    function edit(on) {
        editing = on
        console.log("[widgets] edit mode", on ? "on" : "off")
        if (on) { Popups.close(); Popups.closeApp() }
    }
}
