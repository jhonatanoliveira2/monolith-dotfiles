import QtQuick
import "../core"

// A hoverable module of the bar (the equivalent of a Waybar module box).
Item {
    id: root
    default property alias content: row.data
    property bool active: false
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
        radius: 3
        color: root.active ? Theme.selected
             : mouse.containsMouse ? Theme.hover
             : "transparent"
        Behavior on color {
            ColorAnimation { duration: Theme.dur(100) }
        }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
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
