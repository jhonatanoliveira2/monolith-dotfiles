import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../core"
import "../components"

MenuWindow {
    menu: "bluetooth"
    panelWidth: 360
    maxHeight: 520

    Column {
        width: parent.width
        spacing: 2
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property var devices: Bluetooth.devices.values.slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || String(a.name).localeCompare(String(b.name)))

        ToggleRow {
            width: parent.width; icon: Theme.glyph.btOn; label: "Bluetooth"
            checked: parent.adapter ? parent.adapter.enabled : false
            onToggled: c => { if (parent.adapter) parent.adapter.enabled = c }
        }
        Item {
            visible: parent.adapter !== null && parent.adapter !== undefined && parent.adapter.enabled
            width: parent.width; height: 34
            Btn {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                compact: true
                icon: Theme.glyph.refresh
                text: parent.parent.adapter && parent.parent.adapter.discovering ? Strings.t("stopScan") : Strings.t("scanDevices")
                active: parent.parent.adapter ? parent.parent.adapter.discovering : false
                onActivated: parent.parent.adapter.discovering = !parent.parent.adapter.discovering
            }
        }

        Section { width: parent.width; text: Strings.t("devices"); visible: parent.devices.length > 0 }
        Repeater {
            model: parent.devices
            delegate: ListRow {
                required property var modelData
                width: parent.width
                icon: modelData.connected ? Theme.glyph.btConn : Theme.glyph.btOn
                title: String(modelData.name || modelData.address)
                subtitle: modelData.connected ? Strings.t("connected") + (modelData.batteryAvailable ? "  ·  " + Math.round(modelData.battery * 100) + "%" : "")
                                              : modelData.paired ? Strings.t("paired") : Strings.t("new")
                selected: modelData.connected
                onClicked: m => {
                    if (m.button === Qt.RightButton) { if (modelData.paired) modelData.forget(); return }
                    if (modelData.paired) modelData.connected = !modelData.connected
                    else modelData.pair()
                }
            }
        }
        Item { width: 1; height: 6 }
        Btn { text: Strings.t("manager"); onActivated: { Popups.close(); Quickshell.execDetached(["blueman-manager"]) } }
    }
}
