import QtQuick
import QtQuick.Shapes
import "../core"

// Circular gauge: a track and an arc for `value` (0..1) that eases to new values. Children are centered.
Item {
    id: root
    property real value: 0
    property real thickness: 6
    property color color: Theme.accent
    property color trackColor: Theme.grayDark
    default property alias content: center.data
    implicitWidth: 64; implicitHeight: 64

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown { NumberAnimation { duration: Theme.dur(600); easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor; strokeWidth: root.thickness; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: (Math.min(root.width, root.height) - root.thickness) / 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.color; strokeWidth: root.thickness; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: (Math.min(root.width, root.height) - root.thickness) / 2; radiusY: radiusX; startAngle: -90; sweepAngle: 360 * root.shown }
        }
    }
    Item { id: center; anchors.fill: parent }
}
