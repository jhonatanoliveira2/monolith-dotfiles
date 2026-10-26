import QtQuick
import "../core"

Item {
    id: root
    property string label: ""
    property string icon: ""
    property bool checked: false
    signal toggled(bool checked)
    implicitHeight: 30

    Rectangle { anchors.fill: parent; color: hov.hovered ? Theme.hover : "transparent" }
    HoverHandler { id: hov }
    Txt { id: ic; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } width: 20; text: root.icon; color: Theme.grayMid; font.pixelSize: 15 }
    Txt { anchors { left: ic.right; leftMargin: 8; verticalCenter: parent.verticalCenter } text: root.label }
    Toggle { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } checked: root.checked; interactive: false }
    TapHandler { onTapped: root.toggled(!root.checked) }
}
