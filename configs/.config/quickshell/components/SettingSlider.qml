import QtQuick
import "../core"

// "label ──────── value" row with an integer range; commits when the drag ends.
Item {
    id: root
    property string label: ""
    property int from: 0
    property int to: 10
    property int value: 0
    property string suffix: ""
    signal commit(int value)
    property int shown: value
    onValueChanged: shown = value
    implicitHeight: 28

    Txt { id: l; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } width: 120; text: root.label; font.bold: false }
    ThinSlider {
        anchors { left: l.right; right: v.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        value: (root.shown - root.from) / (root.to - root.from)
        onMoved: x => root.shown = Math.round(root.from + x * (root.to - root.from))
        onReleased: x => root.commit(root.shown)
    }
    Txt { id: v; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } width: 34; horizontalAlignment: Text.AlignRight; text: root.shown + root.suffix; color: Theme.grayMid }
}
