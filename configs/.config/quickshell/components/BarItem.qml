import QtQuick
import "../core"

// A hoverable module of the bar (the equivalent of a Waybar module box). On a vertical bar (left / right)
// its content stacks into a column and the box spans the bar's width.
Item {
    id: root
    default property alias content: row.data
    property bool active: false
    property bool alert: false           // highlighted background (low battery, hot CPU, …)
    property int pad: 3
    // A menu opened by a click grabs the pointer (HyprlandFocusGrab): while it is open the bar gets no leave
    // event, so containsMouse can stay true after the pointer left and the menu closed. Any menu change marks the
    // hover as stale until the pointer really moves over the item again.
    property bool stale: false
    readonly property bool hovered: mouse.containsMouse && !stale
    property alias spacing: row.columnSpacing
    readonly property bool vertical: Settings.barVertical
    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitWidth: vertical ? Theme.barSize : row.implicitWidth + pad * 2
    implicitHeight: vertical ? row.implicitHeight + pad * 2 + 6 : Theme.barSize

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.vertical ? 0 : 5
        anchors.bottomMargin: root.vertical ? 0 : 5
        anchors.leftMargin: root.vertical ? 5 : 0
        anchors.rightMargin: root.vertical ? 5 : 0
        radius: 4
        color: mouse.pressed ? BarTheme.pressed
             : root.active ? BarTheme.selected
             : root.hovered ? BarTheme.hover
             : root.alert ? BarTheme.critical
             : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
    }
    // a row on horizontal bars, a centered column on vertical ones
    Grid {
        id: row
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 64
        columnSpacing: 4
        rowSpacing: 2
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        scale: mouse.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: Theme.dur(90); easing.type: Easing.OutCubic } }
    }
    Connections {
        target: Popups
        function onCurrentChanged() { if (mouse.containsMouse) root.stale = true }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onPositionChanged: root.stale = false
        onEntered: root.stale = false
        onWheel: w => root.scrolled(w)
    }
}
