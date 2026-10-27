import QtQuick
import "../core"
import "../services"
import "../components"

// CPU / GPU temperature (hottest sensor) and RAM, like the old custom/sysmon module.
// On a vertical bar each stat stacks its glyph over a smaller value.
MenuButton {
    id: root
    menu: "stats"
    spacing: 10
    alert: Stats.level === "critical"
    readonly property color tone: Stats.level === "normal" ? Theme.grayLight : Theme.foreground

    component Stat: Grid {
        property string glyph: ""
        property string value: ""
        property color tone: Theme.grayLight     // passed in: inline components do not see this file's ids
        columns: Settings.barVertical ? 1 : 2
        columnSpacing: 4
        horizontalItemAlignment: Grid.AlignHCenter
        Txt { text: parent.glyph; color: parent.tone }
        Txt { text: parent.value; color: parent.tone; font.pixelSize: Settings.barVertical ? Theme.small : Theme.fontSize }
    }
    Stat { visible: Stats.cpuTemp >= 0; glyph: Theme.glyph.cpu; value: Stats.cpuTemp + "°"; tone: root.tone }
    Stat { visible: Stats.gpuTemp >= 0; glyph: Theme.glyph.gpu; value: Stats.gpuTemp + "°"; tone: root.tone }
    Stat { glyph: Theme.glyph.ram; value: Stats.ramPct + "%"; tone: root.tone }
}
