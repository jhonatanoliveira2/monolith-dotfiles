import QtQuick
import "../core"
import "../services"
import "../components"

MenuButton {
    id: root
    menu: "network"
    readonly property bool wifi: Net.kind === "wifi"
    readonly property string icon: Net.status === "disconnected" ? Theme.glyph.offline
        : Net.status === "online" ? (wifi ? Theme.glyph.wifi : Theme.glyph.wired)
        : (wifi ? Theme.glyph.wifiOff : Theme.glyph.wiredOff)
    readonly property string label: Net.status === "online" ? Strings.t("online")
        : Net.status === "nointernet" ? Strings.t("nointernet") : Strings.t("disconnected")
    readonly property color tone: Net.status === "online" ? Theme.grayLight : Theme.grayMid
    onAlt: m => { if (m.button === Qt.MiddleButton) Net.setWifi(!Net.wifiEnabled) }

    Txt { text: root.icon; color: root.tone }
    Txt { text: root.label; color: root.tone }
}
