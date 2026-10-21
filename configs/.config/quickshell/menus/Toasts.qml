import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../core"
import "../services"
import "../components"

// Floating notifications (top right, under the bar). Only exists on the focused monitor and only while there is something to show.
PanelWindow {
    id: win
    readonly property bool mine: Hyprland.focusedMonitor === null || screen === null || Hyprland.focusedMonitor.name === screen.name
    readonly property int total: Notifs.popups.length + Notifs.internal.length

    visible: mine && total > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + Theme.gap; right: 6 }
    implicitWidth: 360
    implicitHeight: stack.implicitHeight
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-toasts"

    Column {
        id: stack
        width: parent.width
        spacing: 6

        Repeater {
            model: Notifs.internal
            delegate: Rectangle {
                required property var modelData
                width: parent.width; height: 52
                color: Theme.panelBg; border.width: 1; border.color: Theme.line
                NumberAnimation on opacity { from: 0; to: 1; duration: Theme.dur(160) }
                Column {
                    anchors { fill: parent; margins: 8 }
                    Txt { width: parent.width; text: modelData.title; color: Theme.foreground }
                    Txt { width: parent.width; text: modelData.body; font.bold: false; font.pixelSize: 12 }
                }
            }
        }

        Repeater {
            model: Notifs.popups
            delegate: Rectangle {
                required property var modelData
                width: parent.width
                implicitHeight: col.implicitHeight + 16
                color: Theme.panelBg
                border.width: 1
                border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.white : Theme.line
                NumberAnimation on opacity { from: 0; to: 1; duration: Theme.dur(160) }
                Column {
                    id: col
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 3
                    Txt { width: parent.width; text: modelData.appName; color: Theme.grayMid; font.pixelSize: Theme.small }
                    Txt { width: parent.width; text: modelData.summary; color: Theme.foreground }
                    Txt {
                        visible: modelData.body !== ""
                        width: parent.width; text: modelData.body; font.bold: false; font.pixelSize: 12
                        textFormat: Text.StyledText; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => { if (m.button === Qt.RightButton) Notifs.dismiss(modelData); else Notifs.hidePopup(modelData) }
                }
            }
        }
    }
}
