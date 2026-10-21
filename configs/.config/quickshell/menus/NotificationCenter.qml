import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../core"
import "../services"
import "../components"

MenuWindow {
    menu: "notifications"
    panelWidth: 380
    maxHeight: 620

    Column {
        width: parent.width
        spacing: 4

        Item {
            width: parent.width; height: 34
            Txt { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } text: Strings.t("notifications"); color: Theme.foreground; font.pixelSize: 15 }
            Btn { anchors { right: parent.right; verticalCenter: parent.verticalCenter } compact: true; visible: Notifs.count > 0; text: Strings.t("clearAll"); onActivated: Notifs.clearAll() }
        }
        ToggleRow { width: parent.width; icon: Theme.glyph.bellOff; label: Strings.t("dnd"); checked: Settings.dnd; onToggled: c => Settings.dnd = c }

        Txt { visible: Notifs.count === 0; width: parent.width; topPadding: 22; bottomPadding: 22; horizontalAlignment: Text.AlignHCenter; text: Strings.t("noNotifications"); color: Theme.grayMid; font.bold: false }

        Repeater {
            model: Notifs.history.slice().reverse()
            delegate: Rectangle {
                required property var modelData
                width: parent.width
                implicitHeight: body.implicitHeight + 16
                color: "transparent"
                border.width: 1
                border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.white : Theme.line

                Column {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 3
                    Txt { width: parent.width - 24; text: modelData.appName; color: Theme.grayMid; font.pixelSize: Theme.small }
                    Txt { width: parent.width - 24; text: modelData.summary; color: Theme.foreground }
                    Txt {
                        visible: modelData.body !== ""
                        width: parent.width - 24; text: modelData.body; font.bold: false; font.pixelSize: 12
                        textFormat: Text.StyledText; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
                    }
                    Flow {
                        width: parent.width; spacing: 4
                        visible: modelData.actions.length > 0
                        Repeater {
                            model: modelData.actions
                            delegate: Btn { required property var modelData; compact: true; text: modelData.text; onActivated: modelData.invoke() }
                        }
                    }
                }
                Txt {
                    anchors { right: parent.right; top: parent.top; rightMargin: 8; topMargin: 6 }
                    text: Theme.glyph.close; color: x.containsMouse ? Theme.white : Theme.grayMid
                    MouseArea { id: x; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: Notifs.dismiss(modelData) }
                }
            }
        }
    }
}
