import QtQuick
import "../core"
import "../services"
import "../components"

// System widget: CPU / RAM / GPU gauges. Keeps the Stats sampler running while it exists.
Item {
    id: root
    property real k: 1                  // size factor (WidgetHost: small / medium / large)
    Component.onCompleted: Stats.demand++
    Component.onDestruction: Stats.demand--
    component Gauge: Column {
        property string label: ""
        property real value: 0
        property string detail: ""
        spacing: 4
        Ring {
            width: Math.round(70 * root.k); height: width; value: parent.value; thickness: Math.round(7 * root.k)
            color: parent.value >= 0.85 ? Theme.white : Theme.accent
            Txt { anchors.centerIn: parent; text: Math.round(parent.parent.value * 100) + "%"; font.pixelSize: Math.round(14 * root.k); color: Theme.white }
        }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: parent.label + (parent.detail ? "  " + parent.detail : ""); color: Theme.grayMid; font.pixelSize: Math.round(10 * root.k); font.bold: false }
    }
    Row {
        anchors.centerIn: parent
        spacing: Math.round(18 * root.k)
        Gauge { label: "CPU"; value: Math.max(0, Stats.cpu) / 100; detail: Stats.cpuTemp >= 0 ? Stats.cpuTemp + "°" : "" }
        Gauge { label: "RAM"; value: Stats.ramPct / 100; detail: Stats.ramUsed + "G" }
        Gauge { visible: Stats.gpu >= 0; label: "GPU"; value: Math.max(0, Stats.gpu) / 100; detail: Stats.gpuTemp >= 0 ? Stats.gpuTemp + "°" : "" }
    }
}
