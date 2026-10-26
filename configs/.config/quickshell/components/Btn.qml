import QtQuick
import "../core"

// Square button used inside menus. `confirm: true` asks for a second click (destructive actions).
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool active: false
    property bool confirm: false
    property bool armed: false
    property bool compact: false
    signal activated()

    implicitWidth: label.implicitWidth + 20
    implicitHeight: compact ? 26 : 30
    radius: Theme.radius
    color: mouse.pressed ? Theme.pressed : active ? Theme.selected : mouse.containsMouse ? Theme.hover : "transparent"
    border.width: 1
    border.color: active ? Theme.accent : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.dur(100) } }
    Behavior on border.color { ColorAnimation { duration: Theme.dur(100) } }

    Text {
        id: label
        anchors.centerIn: parent
        text: (root.icon ? root.icon + "  " : "") + (root.armed ? "?" : root.text)
        color: root.active || root.armed ? Theme.white : Theme.grayLight
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: true
    }
    Timer { id: disarm; interval: 2500; onTriggered: root.armed = false }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (root.confirm && !root.armed) { root.armed = true; disarm.restart(); return }
            root.armed = false
            root.activated()
        }
    }
}
