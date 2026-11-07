import QtQuick
import "../core"

// A row of LEDs (Nothing theme): the first round(value * count) are lit. With `count` 0 it fits as many as
// the width allows. Used by the OSD, the sliders and the gauges when the theme is on.
Item {
    id: root
    property real value: 0                 // 0..1
    property int count: 0                  // 0 = from the width
    property int dot: 5
    property int gap: Math.max(2, Math.round(dot * Nothing.ledSpacing / Math.max(1, Nothing.ledSize)))
    property color litColor: Theme.white
    property color offColor: Nothing.off
    readonly property int n: count > 0 ? count : Math.max(1, Math.floor((width + gap) / (dot + gap)))
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * n)
    implicitWidth: count > 0 ? count * dot + (count - 1) * gap : 120
    implicitHeight: dot

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap
        Repeater {
            model: root.n
            delegate: Led {
                required property int index
                width: root.dot; height: root.dot
                lit: index < root.lit
                litColor: root.litColor; offColor: root.offColor
            }
        }
    }
}
