import QtQuick
import "../core"

// One selectable row: glyph, title, optional subtitle and a trailing text.
Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool selected: false
    property bool dim: false
    signal clicked(var mouse)

    implicitHeight: subtitle ? 40 : 32
    radius: Theme.radius
    color: mouse.pressed ? Theme.pressed : mouse.containsMouse ? Theme.hover : "transparent"
    border.width: 1
    border.color: selected ? Theme.selectedBorder : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur(100) } }

    Text {
        id: ic
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        width: 20
        text: root.icon
        color: root.selected ? Theme.white : Theme.grayMid
        font.family: Theme.font
        font.pixelSize: 15
    }
    Column {
        anchors { left: ic.right; leftMargin: 8; right: tr.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        Text {
            width: parent.width
            text: root.title
            color: root.dim ? Theme.grayMid : root.selected ? Theme.white : Theme.grayLight
            font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
            elide: Text.ElideRight
        }
        Text {
            visible: root.subtitle !== ""
            width: parent.width
            text: root.subtitle
            color: Theme.grayMid
            font.family: Theme.font; font.pixelSize: Theme.small
            elide: Text.ElideRight
        }
    }
    Text {
        id: tr
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: root.trailing
        color: Theme.grayMid
        font.family: Theme.font; font.pixelSize: Theme.small
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => root.clicked(m)
    }
}
