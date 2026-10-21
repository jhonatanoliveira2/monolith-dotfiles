import QtQuick
import Quickshell.Bluetooth
import "../core"
import "../components"

MenuButton {
    id: root
    menu: "bluetooth"
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool anyConnected: Bluetooth.devices.values.some(d => d.connected)
    visible: adapter !== null && adapter !== undefined
    onAlt: m => { if (m.button === Qt.MiddleButton && adapter) adapter.enabled = !adapter.enabled }
    Txt {
        font.pixelSize: 15
        text: !root.adapter || !root.adapter.enabled ? Theme.glyph.btOff : root.anyConnected ? Theme.glyph.btConn : Theme.glyph.btOn
        color: root.adapter && root.adapter.enabled ? Theme.grayLight : Theme.grayMid
    }
}
