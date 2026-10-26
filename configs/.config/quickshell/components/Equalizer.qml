import QtQuick
import "../core"

// Small animated equalizer. Bar heights follow `level` (0..1, the real output peak from Media.level) with a
// per-bar phase so they don't move in lockstep; with no measurable level they just bounce. Ticks only while
// `running`; at rest the bars lie flat.
Item {
    id: root
    property bool running: false
    property real level: 0
    property int bars: 4
    property int barWidth: 2
    property color color: Theme.grayLight
    implicitWidth: bars * barWidth + (bars - 1) * 2
    implicitHeight: 12

    property real t: 0
    Timer {
        interval: 90
        repeat: true
        running: root.running && root.visible && Config.animations
        onTriggered: root.t += 1
    }

    Row {
        anchors.bottom: parent.bottom
        spacing: 2
        Repeater {
            model: root.bars
            delegate: Rectangle {
                required property int index
                readonly property real wobble: 0.55 + 0.45 * Math.abs(Math.sin(root.t * (0.9 + index * 0.37) + index * 1.7))
                readonly property real lvl: root.running ? Math.max(0.18, root.level > 0.02 ? root.level * wobble : 0.2 + 0.6 * wobble) : 0.15
                width: root.barWidth
                radius: 1
                height: Math.max(2, root.height * Math.min(1, lvl))
                anchors.bottom: parent.bottom
                color: root.color
                Behavior on height { NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutQuad } }
            }
        }
    }
}
