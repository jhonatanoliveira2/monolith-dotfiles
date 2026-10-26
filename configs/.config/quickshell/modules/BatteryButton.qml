import QtQuick
import Quickshell.Services.UPower
import "../core"
import "../components"

// Laptops only: hidden when there is no battery.
MenuButton {
    id: root
    menu: "power"
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev !== undefined && dev.isPresent && dev.isLaptopBattery
    readonly property real pct: dev ? (dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0
    readonly property bool charging: dev && dev.state === UPowerDeviceState.Charging
    readonly property bool low: pct <= 20 && !charging
    visible: present
    alert: low

    Txt { text: root.charging ? Theme.glyph.bolt : Theme.glyph.battery[Math.min(4, Math.round(root.pct / 25))]; color: root.low ? Theme.white : Theme.grayLight }
    Txt { text: Math.round(root.pct) + "%"; color: root.low ? Theme.white : Theme.grayLight }
}
