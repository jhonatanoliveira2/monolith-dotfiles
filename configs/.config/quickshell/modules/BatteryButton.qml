import QtQuick
import "../core"
import "../services"
import "../components"

// Laptops only: hidden when there is no battery. Plugged in shows the bolt (charging or not).
// Nothing theme: the charge as LEDs (a row; a column of eight on a side bar), as in NIHIL Shell's battery gauge:
// red LEDs when low (the number stays white, never small red text) and a light scanning up while charging.
MenuButton {
    id: root
    menu: "power"
    visible: Battery.present
    alert: Battery.low
    readonly property bool dots: Theme.nothing

    BarTxt { visible: !root.dots; text: Battery.onAc ? Theme.glyph.bolt : Theme.glyph.battery[Math.min(4, Math.round(Battery.pct / 25))]; color: Battery.low ? BarTheme.white : BarTheme.grayLight; font.pixelSize: Theme.barIcon }
    DotMeter {
        id: meter
        visible: root.dots
        vertical: root.vertical
        count: root.vertical ? 8 : 5
        dot: 4; gap: 2
        value: Battery.pct / 100
        head: scan.pos
        litColor: Battery.low ? Theme.alert : BarTheme.white
        offColor: Qt.alpha(BarTheme.grayMid, 0.35)
        Timer {
            id: scan
            property int pos: -1
            running: root.dots && Battery.charging && !Battery.full
            interval: 160; repeat: true
            onTriggered: pos = pos >= meter.n - 1 ? meter.lit : pos + 1
            onRunningChanged: if (!running) pos = -1
        }
    }
    BarTxt { text: Math.round(Battery.pct) + (root.dots && root.vertical ? "" : "%"); color: Battery.low ? BarTheme.white : BarTheme.grayLight
             font.pixelSize: Settings.barVertical ? Theme.small : Theme.fontSize }
}
