import QtQuick
import "../core"
import "../services"
import "../components"

// CPU / GPU temperature (hottest sensor) and RAM, like the old custom/sysmon module.
// On a side bar only the glyphs show (larger); the colour and the alert background still flag heat.
MenuButton {
    id: root
    menu: "stats"
    spacing: 10
    alert: Stats.level === "critical"
    readonly property color tone: Stats.level === "normal" ? BarTheme.grayLight : BarTheme.foreground

    component Stat: Grid {
        property string glyph: ""
        property string value: ""
        property color tone: BarTheme.grayLight     // passed in: inline components do not see this file's ids
        columns: Settings.barVertical ? 1 : 2
        columnSpacing: 4
        horizontalItemAlignment: Grid.AlignHCenter
        BarTxt { text: parent.glyph; color: parent.tone; font.pixelSize: Theme.barIcon }
        BarTxt { visible: !Settings.barVertical; text: parent.value; color: parent.tone }
    }
    Stat { visible: Stats.cpuTemp >= 0; glyph: Theme.glyph.cpu; value: Stats.cpuTemp + "°"; tone: root.tone }
    Stat { visible: Stats.gpuTemp >= 0; glyph: Theme.glyph.gpu; value: Stats.gpuTemp + "°"; tone: root.tone }
    Stat { glyph: Theme.glyph.ram; value: Stats.ramPct + "%"; tone: root.tone }
}
