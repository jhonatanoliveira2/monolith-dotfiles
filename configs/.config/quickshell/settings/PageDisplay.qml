import QtQuick
import "../core"
import "../services"
import "../components"

// Monitor manager: drag the monitors to arrange them (edges snap), pick resolution, refresh rate, scale,
// orientation and the primary monitor, then apply. Changes revert after 15 s unless kept (see Displays.qml).
Column {
    id: root
    spacing: 8
    property var draft: []                // working copy of Displays.monitors
    property string draftPrimary: ""
    property string sel: ""
    property bool dirty: false
    readonly property var cur: draft.find(m => m.name === sel) || null

    Component.onCompleted: Displays.refresh()
    Connections {
        target: Displays
        function onMonitorsChanged() { if (!root.dirty) root.reset() }
        function onPrimaryChanged() { if (!root.dirty) root.draftPrimary = Displays.primary }
    }
    function reset() {
        draft = Displays.monitors.map(m => Object.assign({}, m))
        draftPrimary = Displays.primary
        dirty = false
        if (!draft.find(m => m.name === sel)) sel = draft.length ? (draft.find(m => m.focused) || draft[0]).name : ""
    }
    function edit(name, change) {
        draft = draft.map(m => m.name === name ? Object.assign({}, m, change) : m)
        dirty = true
    }
    function uniq(a) { return a.filter((x, i) => a.indexOf(x) === i) }
    readonly property var resolutions: cur ? uniq(cur.modes.map(m => m.w + "x" + m.h)) : []
    readonly property var rates: cur ? uniq(cur.modes.filter(m => m.w === cur.width && m.h === cur.height).map(m => m.r)).sort((a, b) => b - a) : []

    // ── arrangement ──────────────────────────────────────────────────
    Rectangle {
        id: stage
        width: parent.width; height: 210
        color: Qt.rgba(0, 0, 0, 0.25); border.width: 1; border.color: Theme.line; radius: Theme.radius
        readonly property var on: root.draft.filter(m => !m.disabled)
        readonly property real minX: on.length ? Math.min.apply(null, on.map(m => m.x)) : 0
        readonly property real minY: on.length ? Math.min.apply(null, on.map(m => m.y)) : 0
        readonly property real bw: on.length ? Math.max.apply(null, on.map(m => m.x + Displays.logical(m).w)) - minX : 1
        readonly property real bh: on.length ? Math.max.apply(null, on.map(m => m.y + Displays.logical(m).h)) - minY : 1
        readonly property real k: Math.min((width - 60) / bw, (height - 50) / bh)
        readonly property real ox: (width - bw * k) / 2
        readonly property real oy: (height - bh * k) / 2

        Txt { visible: root.draft.length === 0; anchors.centerIn: parent; text: Labels.t("monNone"); color: Theme.grayMid }
        Txt { anchors { right: parent.right; bottom: parent.bottom; margins: 6 } text: Labels.t("monDragHint"); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }

        Repeater {
            model: stage.on
            delegate: Rectangle {
                id: mon
                required property var modelData
                readonly property var lg: Displays.logical(modelData)
                property real dx: 0
                property real dy: 0
                x: stage.ox + (modelData.x - stage.minX) * stage.k + dx
                y: stage.oy + (modelData.y - stage.minY) * stage.k + dy
                width: lg.w * stage.k; height: lg.h * stage.k
                z: drag.pressed ? 2 : 1
                radius: 4
                color: modelData.name === root.sel ? Theme.tint(0.16) : Theme.tint(0.06)
                border.width: modelData.name === root.sel ? 2 : 1
                border.color: modelData.name === root.sel ? Theme.white : Theme.grayMid
                Behavior on x { enabled: !drag.pressed; NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !drag.pressed; NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutCubic } }
                Column {
                    anchors.centerIn: parent
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: (modelData.name === root.draftPrimary ? "★ " : "") + modelData.name; color: Theme.white }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.width + "×" + modelData.height + " @" + Math.round(modelData.refresh); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                }
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    preventStealing: true          // the page Flickable must not scroll while a monitor is dragged
                    property point start
                    onCanceled: { mon.dx = 0; mon.dy = 0 }
                    onPressed: m => { root.sel = mon.modelData.name; start = mapToItem(stage, m.x, m.y) }
                    onPositionChanged: m => { if (pressed) { const p = mapToItem(stage, m.x, m.y); mon.dx = p.x - start.x; mon.dy = p.y - start.y } }
                    onReleased: {
                        if (Math.abs(mon.dx) < 3 && Math.abs(mon.dy) < 3) { mon.dx = 0; mon.dy = 0; return }
                        const m = mon.modelData
                        let nx = m.x + mon.dx / stage.k, ny = m.y + mon.dy / stage.k
                        // snap to the edges of the other monitors (threshold: 80 logical px)
                        const th = 80, w = mon.lg.w, h = mon.lg.h
                        let bx = th, by = th, sx = nx, sy = ny
                        for (const o of stage.on) {
                            if (o.name === m.name) continue
                            const l = Displays.logical(o)
                            for (const c of [o.x + l.w, o.x - w, o.x, o.x + l.w - w]) if (Math.abs(nx - c) < bx) { bx = Math.abs(nx - c); sx = c }
                            for (const c of [o.y, o.y + l.h, o.y - h, o.y + l.h - h]) if (Math.abs(ny - c) < by) { by = Math.abs(ny - c); sy = c }
                        }
                        mon.dx = 0; mon.dy = 0
                        root.edit(m.name, { x: Math.round(sx), y: Math.round(sy) })
                    }
                }
            }
        }
    }

    // ── selected monitor ─────────────────────────────────────────────
    component Field: Item {
        property string label: ""
        default property alias content: box.data
        width: root.width; height: Math.max(30, box.childrenRect.height + 6)
        Txt { width: 160; x: 10; height: 30; text: parent.label; color: Theme.grayLight }
        Item { id: box; x: 170; width: parent.width - 180; height: childrenRect.height; y: 3 }
    }
    Section { visible: root.cur !== null; width: parent.width; text: root.cur ? root.cur.name + "  ·  " + root.cur.desc : "" }
    Field {
        visible: root.cur !== null; label: Labels.t("monRes")
        Flow {
            width: parent.width; spacing: 4
            Repeater {
                model: root.resolutions
                delegate: Btn {
                    required property string modelData
                    compact: true; text: modelData
                    active: root.cur && modelData === root.cur.width + "x" + root.cur.height
                    onActivated: {
                        const p = modelData.split("x").map(Number)
                        const best = root.cur.modes.filter(m => m.w === p[0] && m.h === p[1]).sort((a, b) => b.r - a.r)[0]
                        root.edit(root.sel, { width: p[0], height: p[1], refresh: best ? best.r : root.cur.refresh })
                    }
                }
            }
        }
    }
    Field {
        visible: root.cur !== null; label: Labels.t("monRate")
        Flow {
            width: parent.width; spacing: 4
            Repeater {
                model: root.rates
                delegate: Btn { required property var modelData; compact: true; text: Math.round(modelData * 100) / 100 + " Hz"
                    active: root.cur && Math.abs(modelData - root.cur.refresh) < 0.05; onActivated: root.edit(root.sel, { refresh: modelData }) }
            }
        }
    }
    Field {
        visible: root.cur !== null; label: Labels.t("monScale")
        Flow {
            width: parent.width; spacing: 4
            Repeater {
                model: [1, 1.25, 1.333333, 1.5, 1.666667, 2]
                delegate: Btn { required property var modelData; compact: true; text: Math.round(modelData * 100) + "%"
                    active: root.cur && Math.abs(modelData - root.cur.scale) < 0.01; onActivated: root.edit(root.sel, { scale: modelData }) }
            }
        }
    }
    Field {
        visible: root.cur !== null; label: Labels.t("monRotate")
        Flow {
            width: parent.width; spacing: 4
            Repeater {
                model: [{ t: 0, l: "0°" }, { t: 1, l: "90°" }, { t: 2, l: "180°" }, { t: 3, l: "270°" }, { t: 4, l: Labels.t("monFlip") }]
                delegate: Btn { required property var modelData; compact: true; text: modelData.l
                    active: root.cur && root.cur.transform === modelData.t; onActivated: root.edit(root.sel, { transform: modelData.t }) }
            }
        }
    }
    Field {
        visible: root.cur !== null; label: Labels.t("monPrimary")
        Row {
            spacing: 10
            Btn { compact: true; text: root.cur && root.draftPrimary === root.cur.name ? "★ " + Labels.t("monIsPrimary") : Labels.t("monMakePrimary")
                  active: root.cur && root.draftPrimary === root.cur.name; onActivated: { root.draftPrimary = root.sel; root.dirty = true } }
            Txt { height: 26; text: root.cur ? Labels.t("monPos") + " " + root.cur.x + " × " + root.cur.y : ""; color: Theme.grayMid; font.bold: false }
        }
    }

    // ── apply / confirm ──────────────────────────────────────────────
    Row {
        spacing: 6
        visible: !Displays.pending
        Btn { icon: Theme.glyph.check; text: Labels.t("apply"); active: root.dirty; onActivated: if (Displays.apply(root.draft, root.draftPrimary)) root.dirty = false }
        Btn { text: Labels.t("discard"); visible: root.dirty; onActivated: root.reset() }
        Btn { icon: Theme.glyph.refresh; text: Labels.t("reread"); onActivated: { root.dirty = false; Displays.refresh() } }
    }
    Rectangle {
        visible: Displays.pending
        width: parent.width; height: 44; color: Theme.selected; border.width: 1; border.color: Theme.white; radius: Theme.radius
        Txt { x: 12; height: parent.height; text: Labels.t("monKeep").replace("%1", Displays.countdown); color: Theme.white }
        Row {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 6
            Btn { compact: true; text: Labels.t("keep"); active: true; onActivated: Displays.keep() }
            Btn { compact: true; text: Labels.t("revert"); onActivated: Displays.revert() }
        }
    }
    Txt { visible: Displays.error !== ""; x: 10; width: parent.width - 20; text: Displays.error; color: Theme.foreground; wrapMode: Text.Wrap; elide: Text.ElideNone }

    EntryList { page: "display"; width: parent.width }
}
