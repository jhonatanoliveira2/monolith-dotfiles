import QtQuick
import "../core"

// Circular gauge drawn with LEDs (Nothing theme): `count` dots around a circle, the first value * count lit,
// starting at the top, clockwise. Same interface as Ring's value / color / trackColor.
Item {
    id: root
    property real value: 0
    property int count: 24
    property real dot: Math.max(3, width / 13)
    property color litColor: Theme.white
    property color offColor: Nothing.off
    readonly property real r: (Math.min(width, height) - dot) / 2
    readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * count)
    Repeater {
        model: root.count
        delegate: Led {
            required property int index
            readonly property real a: -Math.PI / 2 + index * 2 * Math.PI / root.count
            width: root.dot; height: root.dot
            x: root.width / 2 + root.r * Math.cos(a) - width / 2
            y: root.height / 2 + root.r * Math.sin(a) - height / 2
            lit: index < root.lit
            litColor: root.litColor; offColor: root.offColor
        }
    }
}
