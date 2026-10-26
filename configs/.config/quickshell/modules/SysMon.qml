import QtQuick
import "../core"
import "../services"
import "../components"

// CPU / GPU temperature (hottest sensor) and RAM, like the old custom/sysmon module.
MenuButton {
    id: root
    menu: "stats"
    visible: Config.showSysmon
    spacing: 10
    alert: Stats.level === "critical"
    readonly property color tone: Stats.level === "normal" ? Theme.grayLight : Theme.foreground

    Txt { visible: Stats.cpuTemp >= 0; text: Theme.glyph.cpu + " " + Stats.cpuTemp + "°"; color: root.tone }
    Txt { visible: Stats.gpuTemp >= 0; text: Theme.glyph.gpu + " " + Stats.gpuTemp + "°"; color: root.tone }
    Txt { text: Theme.glyph.ram + " " + Stats.ramPct + "%"; color: root.tone }
}
