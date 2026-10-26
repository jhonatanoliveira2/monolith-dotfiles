import QtQuick
import "../core"
import "../services"
import "../components"

Column {
    id: root
    spacing: 6
    property string pending: ""          // ssid waiting for a password

    Component.onCompleted: { Net.scan(); Net.refreshInfo() }
    Timer { interval: 20000; repeat: true; running: true; onTriggered: Net.scan() }   // keep scanning while the page is open

    Rectangle {
        width: parent.width; height: 64; color: "transparent"; border.width: 1; border.color: Theme.line
        Column {
            x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 2
            Txt { color: Theme.white; text: Net.connected ? (Net.connection || Net.device) + "  ·  " + Strings.t(Net.status) : Strings.t("disconnected") }
            Txt { color: Theme.grayMid; font.pixelSize: Theme.small; visible: Net.ip !== ""; text: Labels.t("ip") + " " + Net.ip + "   " + Labels.t("gateway") + " " + Net.gateway }
            Txt { color: Theme.grayMid; font.pixelSize: Theme.small; visible: Net.dns !== "" || Net.available; text: (Net.dns !== "" ? "DNS " + Net.dns + "   " : "") + (Net.backend + (Net.resolved ? " + systemd-resolved" : "")) }
        }
        Btn { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } compact: true; visible: Net.connected; text: Labels.t("disconnect"); onActivated: Net.disconnect() }
    }
    EntryList { page: "network"; width: parent.width }

    Txt { visible: Net.message !== ""; x: 10; width: parent.width - 20; text: Net.message; color: Theme.foreground; wrapMode: Text.Wrap; elide: Text.ElideNone }
    Txt { visible: !Net.available; x: 10; text: Labels.t("nmMissing"); color: Theme.grayMid }
    Section { visible: Net.hasWifi && Net.wifiEnabled; width: parent.width; text: Labels.t("networks") }
    Txt { visible: Net.hasWifi && Net.wifiEnabled && Net.networks.length === 0; x: 10; text: Strings.t("scanning"); color: Theme.grayMid }
    Repeater {
        model: Net.hasWifi && Net.wifiEnabled ? Net.networks : []
        delegate: Column {
            id: nrow
            required property var modelData
            width: root.width
            ListRow {
                width: parent.width
                icon: modelData.secure ? Theme.glyph.lock : Theme.glyph.wifi
                title: modelData.ssid
                subtitle: modelData.busy || (Net.busy && Net.pendingSsid === modelData.ssid) ? Strings.t("connecting")
                    : modelData.active ? Strings.t("connected") : modelData.known ? Labels.t("saved") + "  ·  " + Labels.t("rightForget") : ""
                trailing: modelData.signal + "%"
                selected: modelData.active
                onClicked: m => {
                    if (m.button === Qt.RightButton) { if (modelData.known) Net.forget(modelData.ssid); return }
                    if (modelData.active || Net.busy) return
                    if (modelData.secure && !modelData.known) root.pending = modelData.ssid
                    else Net.connectTo(modelData.ssid, "")
                }
            }
            Rectangle {
                visible: root.pending === modelData.ssid
                width: parent.width; height: 32; color: "transparent"; border.width: 1; border.color: Theme.line
                TextInput {
                    id: pw
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password; color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize
                    onAccepted: { Net.connectTo(modelData.ssid, text); root.pending = ""; text = "" }
                    onVisibleChanged: if (visible) forceActiveFocus()
                    Txt { visible: pw.text === ""; anchors.fill: parent; text: Labels.t("password"); color: Theme.grayMid }
                }
            }
        }
    }
}
