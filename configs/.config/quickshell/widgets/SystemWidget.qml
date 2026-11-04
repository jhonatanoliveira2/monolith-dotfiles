import QtQuick
import "../core"
import "../services"
import "../components"

// System widget: CPU / RAM / GPU gauges. Keeps the Stats sampler running while it exists.
Item {
    Component.onCompleted: Stats.demand++
    Component.onDestruction: Stats.demand--
    component Gauge: Column {
        property string label: ""
        property real value: 0
        property string detail: ""
        spacing: 4
        Ring {
            width: 70; height: 70; value: parent.value; thickness: 7
            color: parent.value >= 0.85 ? Theme.white : Theme.accent
            Txt { anchors.centerIn: parent; text: Math.round(parent.parent.value * 100) + "%"; font.pixelSize: 14; color: Theme.white }
        }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: parent.label + (parent.detail ? "  " + parent.detail : ""); color: Theme.grayMid; font.pixelSize: 10; font.bold: false }
    }
    Row {
        anchors.centerIn: parent
        spacing: 18
        Gauge { label: "CPU"; value: Math.max(0, Stats.cpu) / 100; detail: Stats.cpuTemp >= 0 ? Stats.cpuTemp + "°" : "" }
        Gauge { label: "RAM"; value: Stats.ramPct / 100; detail: Stats.ramUsed + "G" }
        Gauge { visible: Stats.gpu >= 0; label: "GPU"; value: Math.max(0, Stats.gpu) / 100; detail: Stats.gpuTemp >= 0 ? Stats.gpuTemp + "°" : "" }
    }
}
