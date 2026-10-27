import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../core"

// Tray icons: a row, or a column on a vertical bar.
Grid {
    id: root
    property var window: null
    readonly property bool vertical: Settings.barVertical
    columns: vertical ? 1 : 64
    spacing: 6
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    Repeater {
        model: SystemTray.items
        delegate: Item {
            required property var modelData
            width: root.vertical ? Theme.barSize : 18
            height: root.vertical ? 22 : Theme.barSize
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
                        const p = root.vertical ? parent.mapToItem(null, Settings.barPosition === "left" ? parent.width : 0, 0)
                                                : parent.mapToItem(null, 0, Settings.barPosition === "bottom" ? 0 : parent.height)
                        modelData.display(root.window, p.x, p.y)
                    }
                }
                onWheel: w => modelData.scroll(w.angleDelta.y, false)
            }
        }
    }
}
