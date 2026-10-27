import QtQuick
import "../core"
import "../services"
import "../components"

// Wi-Fi: four waves showing the signal (dimmed without internet); wired / offline: the font glyph.
// On a side bar only the icon shows, a bit larger.
MenuButton {
    id: root
    menu: "network"
    readonly property bool wifi: Net.kind === "wifi"
    readonly property string icon: Net.status === "disconnected" ? Theme.glyph.offline
        : Net.status === "online" ? Theme.glyph.wired : Theme.glyph.wiredOff
    readonly property string label: Net.status === "online" ? Strings.t("online")
        : Net.status === "nointernet" ? Strings.t("nointernet") : Strings.t("disconnected")
    readonly property color tone: Net.status === "online" ? Theme.grayLight : Theme.grayMid
    onAlt: m => { if (m.button === Qt.MiddleButton) Net.setWifi(!Net.wifiEnabled) }

    WifiIcon { visible: root.wifi; size: root.vertical ? 18 : 15; level: Net.signalLevel; color: root.tone; dimColor: Theme.tint(0.16) }
    Txt { visible: !root.wifi; text: root.icon; color: root.tone; font.pixelSize: Theme.barIcon }
    Txt { visible: !root.vertical; text: root.label; color: root.tone }
}
