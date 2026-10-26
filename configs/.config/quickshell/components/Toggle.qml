import QtQuick
import "../core"

// Square switch (same look as the swaync "Do Not Disturb" switch).
Item {
    id: root
    property bool checked: false
    property bool interactive: true      // false when a parent row already handles the click
    signal toggled(bool checked)
    implicitWidth: 36
    implicitHeight: 18

    Rectangle {
        anchors.fill: parent
        color: root.checked ? Theme.grayMid : Theme.grayDark
        border.width: 1
        border.color: Theme.line
        Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
    }
    Rectangle {
        y: 2
        width: 14; height: 14
        x: root.checked ? parent.width - width - 2 : 2
        color: Theme.foreground
        Behavior on x { NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; enabled: root.interactive; onClicked: root.toggled(!root.checked) }
}


