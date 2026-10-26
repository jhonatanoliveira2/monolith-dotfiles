import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

MenuWindow {
    id: win
    menu: "network"
    panelWidth: 380
    maxHeight: 560

    Column {
        id: col
        width: parent.width
        spacing: 2
        property string pending: ""
        Component.onCompleted: Net.scan()
        // keep the scanner alive while the menu is open (it stops by itself 30 s after closing)
        Timer { interval: 20000; repeat: true; running: true; onTriggered: Net.scan() }

        ToggleRow { visible: Net.hasWifi; width: parent.width; icon: Theme.glyph.wifi; label: "Wi-Fi"; checked: Net.wifiEnabled; onToggled: c => Net.setWifi(c) }
        Txt { visible: Net.hasWifi && Net.wifiEnabled && !Net.wifiHardware; width: parent.width; leftPadding: 10; text: Strings.t("wifiHwOff"); color: Theme.grayMid; font.pixelSize: Theme.small }

        // current connection
        Rectangle {
            width: parent.width; height: 48
            color: "transparent"; border.width: 1; border.color: Theme.line
            Txt {
                id: st
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                font.pixelSize: 18
                text: Net.status === "disconnected" ? Theme.glyph.offline : Net.status === "online" ? (Net.kind === "wifi" ? Theme.glyph.wifi : Theme.glyph.wired) : Theme.glyph.wifiOff
                color: Net.status === "online" ? Theme.foreground : Theme.grayMid
            }
            Column {
                anchors { left: st.right; leftMargin: 10; right: dis.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                Txt { width: parent.width; text: Net.connection || Strings.t("disconnected"); color: Theme.foreground }
                Txt { width: parent.width; font.pixelSize: Theme.small; font.bold: false; color: Theme.grayMid
                    text: (Net.status === "online" ? Strings.t("online") : Net.status === "nointernet" ? Strings.t("nointernet") : Strings.t("disconnected")) + (Net.device ? "  ·  " + Net.device : "") }
            }
            Btn { id: dis; visible: Net.connected; compact: true; anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } text: Strings.t("disconnect"); onActivated: Net.disconnect() }
        }
        Txt { visible: Net.message !== ""; width: parent.width; leftPadding: 10; text: Net.message; color: Theme.foreground; font.pixelSize: Theme.small; wrapMode: Text.Wrap; elide: Text.ElideNone }

        Section { width: parent.width; text: Strings.t("networks"); visible: Net.hasWifi && Net.wifiEnabled }
        Txt { visible: Net.scanning && Net.networks.length === 0; leftPadding: 10; text: Strings.t("scanning"); color: Theme.grayMid; font.bold: false }
        Repeater {
            model: Net.wifiEnabled ? Net.networks : []
            delegate: Column {
                required property var modelData
                width: parent.width
                ListRow {
                    width: parent.width
                    icon: modelData.secure ? Theme.g(0xf023) : Theme.glyph.wifi
                    title: modelData.ssid
                    subtitle: modelData.busy || (Net.busy && Net.pendingSsid === modelData.ssid) ? Strings.t("connecting")
                        : modelData.active ? Strings.t("online") : modelData.known ? Strings.t("saved") : modelData.secure ? Strings.t("secured") : Strings.t("open")
                    trailing: modelData.signal + "%"
                    selected: modelData.active
                    onClicked: m => {
                        if (m.button === Qt.RightButton) { if (modelData.known) Net.forget(modelData.ssid); return }
                        if (modelData.active || Net.busy) return
                        if (modelData.known || !modelData.secure) Net.connectTo(modelData.ssid, "")
                        else { col.pending = col.pending === modelData.ssid ? "" : modelData.ssid; pw.text = ""; pw.forceActiveFocus() }
                    }
                }
                Rectangle {
                    visible: col.pending === modelData.ssid
                    width: parent.width; height: 34
                    color: "transparent"; border.width: 1; border.color: Theme.accent
                    TextInput {
                        id: pw
                        anchors { left: parent.left; leftMargin: 10; right: go.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        echoMode: TextInput.Password
                        color: Theme.white; selectionColor: Theme.grayMid
                        font.family: Theme.font; font.pixelSize: Theme.fontSize
                        Keys.onReturnPressed: go.activated()
                        Txt { visible: pw.text === ""; text: Strings.t("password"); color: Theme.grayMid; font.bold: false }
                    }
                    Btn { id: go; compact: true; anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter } text: Strings.t("connect")
                        onActivated: { Net.connectTo(modelData.ssid, pw.text); col.pending = "" } }
                }
            }
        }

        Item { width: 1; height: 6 }
        Flow {
            width: parent.width; spacing: 4
            Btn { visible: Net.hasWifi; text: Strings.t("rescan"); icon: Theme.glyph.refresh; active: Net.scanning; onActivated: Net.scan(true) }
            Btn { text: Strings.t("advanced"); onActivated: { Popups.close(); Quickshell.execDetached(["nm-connection-editor"]) } }
        }
    }
}
