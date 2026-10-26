import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

// Screen backlight: slider and quick presets (the power menu keeps battery and profiles).
MenuWindow {
    menu: "brightness"
    panelWidth: 320

    Column {
        width: parent.width
        spacing: 4

        Item {
            width: parent.width; height: 56
            Txt { id: big; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } text: Math.round(Brightness.fraction * 100) + "%"; font.pixelSize: 30; color: Theme.foreground }
            Txt { anchors { left: big.right; leftMargin: 14; verticalCenter: parent.verticalCenter } text: Strings.t("brightness"); color: Theme.grayMid; font.bold: false }
        }
        Item {
            width: parent.width; height: 30
            Txt { id: sun; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } text: Theme.glyph.backlight; font.pixelSize: 16 }
            ThinSlider {
                anchors { left: sun.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                value: Brightness.fraction
                onMoved: v => Brightness.set(v)
            }
        }
        Item { width: 1; height: 4 }
        Flow {
            width: parent.width; spacing: 4
            Repeater {
                model: [10, 25, 50, 75, 100]
                delegate: Btn {
                    required property int modelData
                    compact: true
                    text: modelData + "%"
                    active: Math.round(Brightness.fraction * 100) === modelData
                    onActivated: Brightness.set(modelData / 100)
                }
            }
        }
    }
}
