import QtQuick
import Quickshell.Hyprland
import "../core"
import "../components"

// Workspace indicator. The active workspace is a pill that moves elastically (its number shows for a few
// seconds after a switch or while hovered, then fades and the pill slims down): its leading
// edge runs ahead and the trailing one catches up, so it stretches toward the target and settles. Occupied
// workspaces are filled dots, empty (persistent) ones hollow rings, urgent ones pulse; hovering a slot shows
// its number. Click to go there, scroll to move between workspaces. Horizontal or vertical (side bars).
// Settings.persistentWorkspaces keeps slots 1..N visible even when empty.
Item {
    id: root
    property string screenName: ""
    readonly property var real: Hyprland.workspaces.values.filter(w => w.id > 0)
    readonly property var ids: {
        const s = {}
        for (let i = 1; i <= Settings.persistentWorkspaces; i++) s[i] = true
        for (const w of real) s[w.id] = true
        return Object.keys(s).map(Number).sort((a, b) => a - b)
    }
    readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    readonly property bool specialOpen: {
        const m = Hyprland.monitors.values.find(x => x.name === root.screenName)
        const o = m && m.lastIpcObject ? m.lastIpcObject.specialWorkspace : null
        return !!o && !!o.name
    }
    readonly property bool vertical: Settings.barVertical
    readonly property int cell: 22                // slot pitch along the bar
    readonly property int pill: 16                // thickness of the active pill
    readonly property int extent: ids.length * cell

    function go(id) { Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })") }
    function ws(id) { return real.find(w => w.id === id) || null }

    implicitWidth: vertical ? Theme.barSize : extent + (specialOpen ? 18 : 0)
    implicitHeight: vertical ? extent + (specialOpen ? 18 : 0) : Theme.barSize

    // ── elastic active pill: `a` / `b` are its two ends along the bar ──
    readonly property int idx: ids.indexOf(activeId)
    property int lastIdx: -1
    property bool forward: true
    property bool settled: false               // no animation for the first placement
    property real a: 0
    property real b: 0
    function place() {
        if (idx < 0) return
        forward = idx >= lastIdx
        lastIdx = idx
        a = idx * cell + 1                     // 20 px along the bar, 16 across: a pill, not a dot
        b = idx * cell + cell - 1
        flashNumber()
    }
    // the number shows for a moment after each switch (and while hovered), then fades and the pill slims down
    property bool showNumber: true
    property real thick: showNumber ? pill : 8
    Behavior on thick { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }
    function flashNumber() { showNumber = true; if (!hover.hovered) hideNumber.restart() }
    Timer { id: hideNumber; interval: 2500; onTriggered: root.showNumber = false }
    HoverHandler {
        id: hover
        onHoveredChanged: { if (hovered) { root.showNumber = true; hideNumber.stop() } else hideNumber.restart() }
    }
    onIdxChanged: place()
    onExtentChanged: place()
    Component.onCompleted: { place(); settled = true }
    Behavior on a { enabled: root.settled; NumberAnimation { duration: Theme.dur(root.forward ? 340 : 170); easing.type: Easing.OutCubic } }
    Behavior on b { enabled: root.settled; NumberAnimation { duration: Theme.dur(root.forward ? 170 : 340); easing.type: Easing.OutCubic } }

    Rectangle {
        visible: root.idx >= 0
        x: root.vertical ? (parent.width - root.thick) / 2 : root.a
        y: root.vertical ? root.a : (parent.height - root.thick) / 2
        width: root.vertical ? root.thick : root.b - root.a
        height: root.vertical ? root.b - root.a : root.thick
        radius: root.thick / 2
        color: Theme.foreground
        Text {
            anchors.centerIn: parent
            text: root.activeId
            color: Theme.onForeground
            opacity: root.showNumber ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }
            font.family: Theme.font; font.bold: true; font.pixelSize: 10
        }
    }

    Grid {
        id: slots
        columns: root.vertical ? 1 : 64
        Repeater {
            model: root.ids
            delegate: Item {
                id: slot
                required property int modelData
                readonly property var w: root.ws(modelData)
                readonly property bool active: modelData === root.activeId
                readonly property bool occupied: w !== null && (w.toplevels ? w.toplevels.values.length > 0 : true)
                readonly property bool urgent: w !== null && w.urgent === true
                width: root.vertical ? Theme.barSize : root.cell
                height: root.vertical ? root.cell : Theme.barSize

                // dot (occupied), ring (empty) or, while hovered, the number
                Rectangle {
                    anchors.centerIn: parent
                    visible: !slot.active
                    width: ma.containsMouse ? 14 : slot.occupied || slot.urgent ? 7 : 6
                    height: width; radius: width / 2
                    color: ma.containsMouse ? Theme.hover : slot.urgent ? Theme.white : slot.occupied ? Theme.grayLight : "transparent"
                    border.width: slot.occupied || slot.urgent || ma.containsMouse ? 0 : 1.5
                    border.color: Theme.grayMid
                    Behavior on width { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.dur(140) } }
                    property real pulse: 1
                    opacity: slot.urgent ? pulse : 1
                    SequentialAnimation on pulse {
                        running: slot.urgent && Config.animations
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: ma.containsMouse
                        text: slot.modelData
                        color: Theme.white
                        font.family: Theme.font; font.bold: true; font.pixelSize: 10
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.go(slot.modelData)
                }
            }
        }
    }

    // special workspace ("magic") indicator
    Txt {
        visible: root.specialOpen
        x: root.vertical ? (parent.width - width) / 2 : root.extent + 4
        y: root.vertical ? root.extent + 2 : (parent.height - height) / 2
        text: "✦"; color: Theme.white; font.pixelSize: 11
    }

    // the monitor's special workspace only arrives with a monitors refresh
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "activespecial") Hyprland.refreshMonitors() }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real acc: 0
        onWheel: e => {
            acc += e.angleDelta.y
            if (Math.abs(acc) < 120) return
            Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + (acc > 0 ? "e-1" : "e+1") + "\" })")
            acc = 0
        }
    }
}
