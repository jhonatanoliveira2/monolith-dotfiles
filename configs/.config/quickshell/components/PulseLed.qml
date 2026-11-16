import QtQuick
import "../core"

// A single LED that breathes while `active` (search fields of the Nothing theme: the input is "listening"): a few
// breaths when it lights up, then it stays lit. Not endlessly: it sits in full-screen overlays (launcher, wallpaper
// picker), where a running animation made Qt draw the whole window again, and Hyprland blur it again, on every
// frame for as long as the overlay stayed open.
Led {
    id: led
    property bool active: false
    property int breaths: 3
    width: 7; height: 7
    lit: true
    litColor: Theme.white
    opacity: 0.35
    function update() {
        breathe.stop()
        if (active && Config.animations) breathe.start()
        else opacity = active ? 1 : 0.35
    }
    onActiveChanged: update()
    Component.onCompleted: update()
    Connections { target: Config; function onAnimationsChanged() { led.update() } }
    SequentialAnimation {
        id: breathe
        SequentialAnimation {
            loops: led.breaths
            NumberAnimation { target: led; property: "opacity"; to: 1; duration: 520; easing.type: Easing.InOutSine }
            NumberAnimation { target: led; property: "opacity"; to: 0.35; duration: 520; easing.type: Easing.InOutSine }
        }
        NumberAnimation { target: led; property: "opacity"; to: 1; duration: 520; easing.type: Easing.InOutSine }
    }
}
