import QtQuick
import "../core"

// Thin track, gray -> white fill (the gradient allowed by the visual identity). Wheel and touchpad friendly.
Item {
    id: root
    property real value: 0                 // 0..1
    property real step: 0.02
    signal moved(real value)               // while dragging / scrolling
    signal released(real value)            // when the drag ends (commit expensive changes here)
    implicitHeight: 20
    implicitWidth: 160

    function setFrom(x) {
        const v = Math.max(0, Math.min(1, x / width))
        root.moved(v)
    }

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 4
        color: Theme.grayDark
        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.grayMid }
                GradientStop { position: 1; color: Theme.white }
            }
        }
    }
    Rectangle {
        visible: mouse.containsMouse || mouse.pressed
        width: 6; height: 12
        x: track.width * Math.max(0, Math.min(1, root.value)) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.foreground
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onPressed: m => root.setFrom(m.x)
        onPositionChanged: m => { if (pressed) root.setFrom(m.x) }
        onReleased: root.released(root.value)
        onWheel: w => {
            const v = Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 1 : -1) * root.step))
            root.moved(v)
            root.released(v)
        }
    }
}
