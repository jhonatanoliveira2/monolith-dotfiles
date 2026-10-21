import QtQuick
import Quickshell.Hyprland
import "../core"
import "../components"

Row {
    readonly property var list: Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
    Repeater {
        model: parent.list
        delegate: Item {
            required property var modelData
            width: 22
            height: parent.height
            Rectangle {
                anchors.centerIn: parent
                width: 18; height: 18; radius: 9
                color: modelData.urgent === true ? Theme.grayDark : "transparent"
            }
            Txt {
                anchors.centerIn: parent
                text: Theme.glyph.dot
                color: modelData.active ? Theme.foreground : ma.containsMouse ? Theme.grayLight : Theme.grayMid
                Behavior on color { ColorAnimation { duration: Theme.dur(100) } }
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                onClicked: modelData.activate()
            }
        }
    }
}
