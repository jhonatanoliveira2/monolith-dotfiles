import QtQuick
import "../core"

// A row (or column) of LEDs (Nothing theme): the LEDs from `from` to `value` (both 0..1) are lit. With `count`
// 0 it fits as many as the length allows. `head` lights one more LED (a scan, e.g. while charging). A column
// fills from the bottom. Used by the OSD, sliders, gauges, progress bars, the battery and the center menu.
Item {
    id: root
    property real value: 0                 // 0..1
    property real from: 0                  // 0..1: a range (the day's temperatures on the week's scale)
    property bool vertical: false
    property int count: 0                  // 0 = from the length
    property real dot: 5
    property real gap: Math.max(2, Math.round(dot * Nothing.ledSpacing / Math.max(1, Nothing.ledSize)))
    property int head: -1
    property color litColor: Theme.white
    property color offColor: Nothing.off
    readonly property real length: vertical ? height : width
    readonly property int n: count > 0 ? count : Math.max(1, Math.floor((length + gap) / (dot + gap)))
    readonly property int lo: Math.round(Math.max(0, Math.min(1, from)) * n)
    readonly property int lit: Math.max(lo + (value > from ? 1 : 0), Math.round(Math.max(0, Math.min(1, value)) * n))
    implicitWidth: vertical ? dot : (count > 0 ? count * dot + (count - 1) * gap : 120)
    implicitHeight: vertical ? (count > 0 ? count * dot + (count - 1) * gap : 120) : dot

    Grid {
        anchors.centerIn: parent
        columns: root.vertical ? 1 : root.n
        spacing: root.gap
        Repeater {
            model: root.n
            delegate: Led {
                required property int index
                readonly property int i: root.vertical ? root.n - 1 - index : index      // a column fills upwards
                width: root.dot; height: root.dot
                lit: (i >= root.lo && i < root.lit) || i === root.head
                litColor: root.litColor; offColor: root.offColor
            }
        }
    }
}
