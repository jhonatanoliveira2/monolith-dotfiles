import QtQuick
import "../core"

// A single LED that breathes while `active` (search fields of the Nothing theme: the input is "listening").
Led {
    id: led
    property bool active: false
    width: 7; height: 7
    lit: true
    litColor: Theme.white
    opacity: 0.35
    SequentialAnimation on opacity {
        running: led.active && Config.animations
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.35; duration: 520; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) led.opacity = led.active ? 1 : 0.35
    }
}
