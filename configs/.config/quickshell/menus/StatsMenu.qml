import QtQuick
import "../core"
import "../services"
import "../components"

// Details behind the bar's CPU / GPU / RAM readout.
MenuWindow {
    menu: "stats"
    panelWidth: 320

    Column {
        width: parent.width
        spacing: 6

        component Meter: Item {
            property string icon: ""
            property string name: ""
            property real fraction: 0
            property string value: ""
            width: parent.width; height: 34
            Txt { id: ic; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } width: 22; text: parent.icon; font.pixelSize: 16; color: Theme.grayMid }
            Txt { id: nm; anchors { left: ic.right; leftMargin: 4; verticalCenter: parent.verticalCenter } width: 44; text: parent.name; font.bold: false }
            Rectangle {
                anchors { left: nm.right; right: vl.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                height: 4; color: Theme.grayDark
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, parent.parent.fraction)); height: parent.height
                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.grayMid } GradientStop { position: 1; color: Theme.white } }
                    Behavior on width { NumberAnimation { duration: Theme.dur(400) } }
                }
            }
            Txt { id: vl; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } width: 116; horizontalAlignment: Text.AlignRight; text: parent.value; color: Theme.foreground }
        }

        Meter { icon: Theme.glyph.cpu; name: "CPU"; fraction: Stats.cpu / 100; value: (Stats.cpu >= 0 ? Stats.cpu + "%" : "-") + (Stats.cpuTemp >= 0 ? "  " + Stats.cpuTemp + "°C" : "") }
        Meter { visible: Stats.gpu >= 0 || Stats.gpuTemp >= 0; icon: Theme.glyph.gpu; name: "GPU"; fraction: Stats.gpu / 100; value: (Stats.gpu >= 0 ? Stats.gpu + "%" : "-") + (Stats.gpuTemp >= 0 ? "  " + Stats.gpuTemp + "°C" : "") }
        Meter { icon: Theme.glyph.ram; name: "RAM"; fraction: Stats.ramPct / 100; value: Stats.ramUsed + " / " + Stats.ramTotal + " G" }
    }
}
