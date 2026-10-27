import QtQuick
import Quickshell.Hyprland
import "../core"
import "../components"

// Workspace dots: the active one stretches into a pill (animated), occupied ones are brighter, urgent ones pulse.
// Scroll to move between workspaces. Settings.persistentWorkspaces keeps slots 1..N visible even when empty.
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
    readonly property int cell: 20
    readonly property bool vertical: Settings.barVertical

    function go(id) { Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })") }
    function ws(id) { return real.find(w => w.id === id) || null }

    implicitWidth: vertical ? Theme.barSize : row.width + (specialOpen ? 18 : 0)
    implicitHeight: vertical ? row.height + (specialOpen ? 18 : 0) : Theme.barSize

    // active pill, slides between slots
    Rectangle {
        readonly property int idx: root.ids.indexOf(root.activeId)
        visible: idx >= 0
        x: root.vertical ? (parent.width - width) / 2 : idx * root.cell + 2
        y: root.vertical ? idx * root.cell + 2 : (parent.height - height) / 2
        width: root.vertical ? 8 : root.cell - 4; height: root.vertical ? root.cell - 4 : 8; radius: 4
        color: Theme.foreground
        Behavior on x { enabled: !root.vertical; NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }
        Behavior on y { enabled: root.vertical; NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }
    }

    Grid {
        id: row
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

                Rectangle {
                    anchors.centerIn: parent
                    visible: !slot.active
                    width: ma.containsMouse ? 8 : 6; height: width; radius: width / 2
                    color: slot.urgent ? Theme.white : ma.containsMouse ? Theme.grayLight : slot.occupied ? Theme.grayLight : Theme.grayDark
                    Behavior on width { NumberAnimation { duration: Theme.dur(120) } }
                    Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                    property real pulse: 1
                    opacity: slot.urgent ? pulse : 1
                    SequentialAnimation on pulse {
                        running: slot.urgent && Config.animations
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.go(slot.modelData)
                }
            }
        }
    }

    // special workspace ("magic") indicator
    Txt {
        visible: root.specialOpen
        x: root.vertical ? (parent.width - width) / 2 : row.width + 4
        y: root.vertical ? row.height + 2 : (parent.height - height) / 2
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
