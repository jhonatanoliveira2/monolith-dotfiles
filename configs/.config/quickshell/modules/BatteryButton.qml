import QtQuick
import "../core"
import "../services"
import "../components"

// Laptops only: hidden when there is no battery. Plugged in shows the bolt (charging or not).
MenuButton {
    id: root
    menu: "power"
    visible: Battery.present
    alert: Battery.low

    Txt { text: Battery.onAc ? Theme.glyph.bolt : Theme.glyph.battery[Math.min(4, Math.round(Battery.pct / 25))]; color: Battery.low ? Theme.white : Theme.grayLight }
    Txt { text: Math.round(Battery.pct) + "%"; color: Battery.low ? Theme.white : Theme.grayLight; font.pixelSize: Settings.barVertical ? Theme.small : Theme.fontSize }
}
