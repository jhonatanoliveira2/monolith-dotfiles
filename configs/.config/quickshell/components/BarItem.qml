import QtQuick
import "../core"

// A hoverable module of the bar (the equivalent of a Waybar module box).
Item {
    id: root
    default property alias content: row.data
    property bool active: false
    property bool alert: false           // highlighted background (low battery, hot CPU, …)
    property int pad: 3
    property alias hovered: mouse.containsMouse
    property alias spacing: row.spacing
    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitWidth: row.implicitWidth + pad * 2
    implicitHeight: parent ? parent.height : Theme.barHeight

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        radius: 4
        color: mouse.pressed ? Theme.pressed
             : root.active ? Theme.selected
             : mouse.containsMouse ? Theme.hover
             : root.alert ? Theme.critical
             : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        scale: mouse.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: Theme.dur(90); easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w)
    }
}
