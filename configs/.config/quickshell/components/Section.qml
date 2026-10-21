import QtQuick
import "../core"

// Small uppercase heading + hairline, used to group rows inside a menu.
Item {
    property string text: ""
    implicitHeight: 26
    Text {
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        text: parent.text.toUpperCase()
        color: Theme.grayMid
        font.family: Theme.font; font.pixelSize: Theme.small; font.bold: true
        font.letterSpacing: 1
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.line
    }
}
