import QtQuick
import QtQuick.Shapes
import "../core"

// Wi-Fi signal as four growing waves: `level` 1..4 of them are lit (4 = strong, 1 = weak), the rest dimmed.
// Drawn (not a font glyph) so the waves are separate arcs at any size.
Item {
    id: root
    property int size: 16
    property int level: 4                     // 0..4
    property color color: Theme.grayLight
    property color dimColor: Theme.grayDark
    implicitWidth: size
    implicitHeight: size

    // one wave (values passed in: inline components do not see this file's ids)
    component Wave: ShapePath {
        property int i: 0
        property real s: 16
        readonly property real r: s * (0.16 + i * 0.185)
        readonly property real cy: s * 0.86
        strokeWidth: Math.max(1.5, s * 0.105)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: s / 2 - r * Math.SQRT1_2
        startY: cy - r * Math.SQRT1_2
        PathAngleArc { centerX: s / 2; centerY: cy; radiusX: r; radiusY: r; startAngle: -135; sweepAngle: 90 }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        Wave { i: 0; s: root.size; strokeColor: root.level > 0 ? root.color : root.dimColor }
        Wave { i: 1; s: root.size; strokeColor: root.level > 1 ? root.color : root.dimColor }
        Wave { i: 2; s: root.size; strokeColor: root.level > 2 ? root.color : root.dimColor }
        Wave { i: 3; s: root.size; strokeColor: root.level > 3 ? root.color : root.dimColor }
    }
}
