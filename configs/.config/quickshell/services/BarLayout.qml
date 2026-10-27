pragma Singleton
import QtQuick
import Quickshell
import "../core"

// Which bar modules show, in which zone and in what order (Settings > Bar, drag and drop).
// Zones: start (left / top), center, end (right / bottom). A module in no zone is hidden.
// The first run builds the layout from the older show* switches, so nothing the user turned off comes back.
Singleton {
    id: root

    readonly property var catalog: [
        { id: "logo", glyph: 0xf303 }, { id: "workspaces", glyph: 0xf24d }, { id: "player", glyph: 0xf001 },
        { id: "title", glyph: 0xf2d0 }, { id: "clock", glyph: 0xf017 }, { id: "tray", glyph: 0xf0ca },
        { id: "sysmon", glyph: 0xf2db }, { id: "network", glyph: 0xf1eb }, { id: "bluetooth", glyph: 0xf293 },
        { id: "battery", glyph: 0xf240 }, { id: "brightness", glyph: 0xf185 }, { id: "volume", glyph: 0xf028 },
        { id: "bell", glyph: 0xf0f3 }
    ]
    readonly property var ids: catalog.map(m => m.id)
    readonly property var zoneIds: ["start", "center", "end"]

    function defaults() {
        const keep = id => (id !== "player" || Settings.showPlayer) && (id !== "sysmon" || Settings.showSysmon) && (id !== "title" || Settings.showWindowTitle)
        return {
            start: ["logo", "workspaces", "player", "title"].filter(keep),
            center: ["clock"],
            end: ["tray", "sysmon", "network", "bluetooth", "battery", "brightness", "volume", "bell"].filter(keep)
        }
    }
    // saved layout, cleaned up: unknown ids dropped, each module in one zone at most
    readonly property var zones: {
        const saved = Settings.barModules, out = {}, seen = {}
        const src = saved !== null && saved !== undefined ? saved : defaults()
        for (const z of zoneIds) {
            out[z] = Array.from(src[z] || []).filter(id => ids.indexOf(id) >= 0 && !seen[id] && (seen[id] = true))
        }
        return out
    }
    readonly property var hidden: ids.filter(id => !zoneIds.some(z => zones[z].indexOf(id) >= 0))

    function info(id) { return catalog.find(m => m.id === id) || { id: id, glyph: 0xf128 } }

    // move a module to `zone` ("hidden" removes it) before `beforeId` ("" = at the end)
    function move(id, zone, beforeId) {
        if (id === beforeId) return
        const out = {}
        for (const z of zoneIds) out[z] = zones[z].filter(x => x !== id)
        if (zone !== "hidden") {
            const l = out[zone], i = beforeId ? l.indexOf(beforeId) : -1
            if (i >= 0) l.splice(i, 0, id); else l.push(id)
        }
        Settings.barModules = out
    }
    function reset() { Settings.barModules = null }
}
