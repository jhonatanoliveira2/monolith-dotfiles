import QtQuick
import "../core"

// One LED of the Nothing theme, in the shape chosen in Settings > Themes > Nothing (circle, square, rounded).
Rectangle {
    property bool lit: false
    property color litColor: Theme.white
    property color offColor: Nothing.off
    implicitWidth: 6; implicitHeight: 6
    radius: Nothing.ledShape === "circle" ? width / 2 : Nothing.ledShape === "rounded" ? width * 0.3 : 0
    color: lit ? litColor : offColor
    Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
}
