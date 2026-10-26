import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

Column {
    id: root
    spacing: 6

    EntryList { page: "bluetooth"; width: parent.width }
    Txt { visible: !Bt.present; x: 10; text: Labels.t("noAdapter"); color: Theme.grayMid }
    Txt { visible: Bt.present && !Bt.enabled; x: 10; text: Bt.blocked ? Strings.t("btBlocked") : Labels.t("adapterOff"); color: Theme.grayMid }
    Btn {
        visible: Bt.enabled
        compact: true; icon: Theme.glyph.refresh
        text: Bt.discovering ? Labels.t("stopScan") : Labels.t("scan")
        active: Bt.discovering
        onActivated: Bt.scan(!Bt.discovering)
    }
    Txt { visible: Bt.message !== ""; x: 10; width: parent.width - 20; text: Bt.message; color: Theme.foreground; wrapMode: Text.Wrap; elide: Text.ElideNone }
    Section { visible: Bt.enabled && Bt.devices.length > 0; width: parent.width; text: Strings.t("devices") }
    Repeater {
        model: Bt.enabled ? Bt.devices : []
        delegate: ListRow {
            required property var modelData
            width: root.width
            icon: modelData.connected ? Theme.glyph.btConn : Theme.glyph.btOn
            title: String(modelData.name || modelData.address)
            subtitle: Bt.status(modelData) + "  ·  " + modelData.address
            trailing: modelData.paired ? Labels.t("rightForget") : ""
            dim: Bt.busy(modelData)
            selected: modelData.connected
            onClicked: m => { if (m.button === Qt.RightButton) Bt.forget(modelData); else Bt.activate(modelData) }
        }
    }
    Btn { text: Strings.t("manager"); onActivated: Quickshell.execDetached(["blueman-manager"]) }
}
