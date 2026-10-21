import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../core"

Row {
    id: root
    property var window: null
    spacing: 6
    Repeater {
        model: SystemTray.items
        delegate: Item {
            required property var modelData
            width: 18
            height: parent.height
            opacity: ma.containsMouse ? 1 : 0.85
            Behavior on opacity { NumberAnimation { duration: Theme.dur(100) } }
            IconImage { anchors.centerIn: parent; implicitSize: 16; source: modelData.icon }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: m => {
                    if (m.button === Qt.LeftButton) modelData.activate()
                    else if (m.button === Qt.MiddleButton) modelData.secondaryActivate()
                    else if (modelData.hasMenu && root.window) {
                        const p = parent.mapToItem(null, 0, parent.height)
                        modelData.display(root.window, p.x, p.y)
                    }
                }
                onWheel: w => modelData.scroll(w.angleDelta.y, false)
            }
        }
    }
}
