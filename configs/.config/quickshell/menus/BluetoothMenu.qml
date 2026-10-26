import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

MenuWindow {
    menu: "bluetooth"
    panelWidth: 360
    maxHeight: 520

    Column {
        width: parent.width
        spacing: 2

        ToggleRow {
            width: parent.width; icon: Theme.glyph.btOn; label: "Bluetooth"
            checked: Bt.enabled
            onToggled: c => Bt.setEnabled(c)
        }
        Txt { visible: Bt.blocked; width: parent.width; leftPadding: 10; text: Strings.t("btBlocked"); color: Theme.grayMid; font.pixelSize: Theme.small }
        Item {
            visible: Bt.enabled
            width: parent.width; height: 34
            Btn {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                compact: true
                icon: Theme.glyph.refresh
                text: Bt.discovering ? Strings.t("stopScan") : Strings.t("scanDevices")
                active: Bt.discovering
                onActivated: Bt.scan(!Bt.discovering)
            }
        }
        Txt { visible: Bt.message !== ""; width: parent.width; leftPadding: 10; text: Bt.message; color: Theme.foreground; font.pixelSize: Theme.small; wrapMode: Text.Wrap; elide: Text.ElideNone }

        Section { width: parent.width; text: Strings.t("devices"); visible: Bt.enabled && Bt.devices.length > 0 }
        Repeater {
            model: Bt.enabled ? Bt.devices : []
            delegate: ListRow {
                required property var modelData
                width: parent.width
                icon: modelData.connected ? Theme.glyph.btConn : Theme.glyph.btOn
                title: String(modelData.name || modelData.address)
                subtitle: Bt.status(modelData)
                dim: Bt.busy(modelData)
                selected: modelData.connected
                onClicked: m => { if (m.button === Qt.RightButton) Bt.forget(modelData); else Bt.activate(modelData) }
            }
        }
        Item { width: 1; height: 6 }
        Btn { text: Strings.t("manager"); onActivated: { Popups.close(); Quickshell.execDetached(["blueman-manager"]) } }
    }
}
