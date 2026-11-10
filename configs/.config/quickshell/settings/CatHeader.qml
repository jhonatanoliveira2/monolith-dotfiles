import QtQuick
import "../core"
import "../components"

// Category heading of a Settings page: larger than the menus' Section, with an accent bar and room above
// it so each group of rows reads as its own block.
Item {
    id: root
    property string text: ""
    property bool first: false
    implicitHeight: (first ? 2 : 18) + 34

    Rectangle {
        id: accent
        anchors { left: parent.left; bottom: line.top; bottomMargin: 8 }
        width: 3; height: 18; radius: 1
        color: Theme.white
        visible: !Theme.nothing
    }
    Column {                      // Nothing theme: three LEDs instead of the bar
        visible: Theme.nothing
        anchors { horizontalCenter: accent.horizontalCenter; verticalCenter: accent.verticalCenter }
        spacing: 2
        Repeater { model: 3; delegate: Led { required property int index; width: 4; height: 4; lit: index > 0 } }
    }
    Text {
        anchors { left: accent.right; leftMargin: 10; verticalCenter: accent.verticalCenter }
        text: root.text
        color: Theme.white
        font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 4; font.bold: true
        font.letterSpacing: Theme.nothing ? 0.5 : 0
    }
    Rectangle {
        id: line
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.line
    }
}
