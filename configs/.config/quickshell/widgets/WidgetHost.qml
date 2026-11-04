import QtQuick
import "../core"
import "../services"
import "../components"

// One placed widget: the card, the widget's own file (Widgets.types[].file) and, in edit mode, the drag
// handling (snapped to Widgets.grid), a remove button and its name.
Item {
    id: host
    property var entry: null
    property bool editing: false
    readonly property var type: entry ? Widgets.type(entry.type) : null

    x: entry ? entry.x : 0
    y: entry ? entry.y : 0
    width: type ? type.w : 0
    height: type ? type.h : 0

    // appear
    opacity: 0; scale: 0.94
    Component.onCompleted: { opacity = 1; scale = 1 }
    Behavior on opacity { NumberAnimation { duration: Theme.dur(240) } }
    Behavior on scale { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutBack } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.menuRadius
        color: Theme.panelBg
        border.width: 1
        border.color: drag.drag.active ? Theme.accent : host.editing ? Theme.grayMid : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.dur(120) } }
    }
    Loader {
        anchors { fill: parent; margins: 12 }
        source: host.type ? Qt.resolvedUrl(host.type.file) : ""
        onStatusChanged: if (status === Loader.Error) console.warn("[widgets] cannot load", host.type ? host.type.file : "?")
    }

    // ── edit mode ──
    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: host.editing
        visible: host.editing
        cursorShape: drag.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: host
        drag.minimumX: 0; drag.minimumY: 0
        drag.maximumX: host.parent ? host.parent.width - host.width : 0
        drag.maximumY: host.parent ? host.parent.height - host.height : 0
        onReleased: if (host.entry) Widgets.move(host.entry.uid, host.x, host.y)
    }
    Rectangle {
        visible: host.editing
        anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
        width: tag.implicitWidth + 12; height: 20; radius: 4
        color: Theme.tint(0.12)
        Txt { id: tag; anchors.centerIn: parent; text: Widgets.name(host.type); font.pixelSize: 10; color: Theme.foreground }
    }
    Rectangle {
        visible: host.editing
        anchors { right: parent.right; top: parent.top; margins: -8 }
        width: 24; height: 24; radius: 12
        color: rm.containsMouse ? Theme.white : Theme.panelBg
        border.width: 1; border.color: Theme.grayMid
        Txt { anchors.centerIn: parent; text: Theme.glyph.close; font.pixelSize: 11; color: rm.containsMouse ? Theme.onForeground : Theme.foreground }
        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (host.entry) Widgets.remove(host.entry.uid) }
    }
}
