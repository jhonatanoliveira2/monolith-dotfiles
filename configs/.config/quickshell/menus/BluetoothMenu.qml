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

        // pairing agent request (confirm a code, type a PIN / passkey, or show one to type on the device)
        Rectangle {
            id: req
            readonly property var r: Bt.request
            readonly property bool typed: r !== null && (r.kind === "pin" || r.kind === "passkey")
            visible: r !== null
            width: parent.width; height: visible ? reqCol.implicitHeight + 16 : 0
            color: "transparent"; border.width: 1; border.color: Theme.accent
            onRChanged: { code.text = ""; if (typed) code.forceActiveFocus() }
            Column {
                id: reqCol
                x: 10; y: 8; width: parent.width - 20; spacing: 6
                Txt { width: parent.width; text: req.r ? req.r.device || "Bluetooth" : ""; color: Theme.foreground }
                Txt { width: parent.width; text: req.r ? Strings.t("bt_" + req.r.kind) : ""; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false; wrapMode: Text.Wrap; elide: Text.ElideNone }
                Txt { visible: req.r !== null && req.r.code !== "" && req.r.kind !== "service"; text: req.r ? req.r.code : ""; font.pixelSize: 26; color: Theme.white }
                Rectangle {
                    visible: req.typed
                    width: parent.width; height: 32
                    color: "transparent"; border.width: 1; border.color: Theme.line
                    TextInput {
                        id: code
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.white; selectionColor: Theme.grayMid
                        font.family: Theme.font; font.pixelSize: Theme.fontSize
                        inputMethodHints: req.r && req.r.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
                        maximumLength: 16
                        Keys.onReturnPressed: Bt.reply(true, text)
                    }
                }
                Flow {
                    width: parent.width; spacing: 4
                    Btn { visible: req.r !== null && req.r.kind !== "display"; compact: true; text: Strings.t("accept"); onActivated: Bt.reply(true, code.text) }
                    Btn { compact: true; text: Strings.t(req.r && req.r.kind === "display" ? "cancel" : "reject"); onActivated: Bt.reply(false) }
                }
            }
        }

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
