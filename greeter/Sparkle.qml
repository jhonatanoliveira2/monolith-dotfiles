import QtQuick

// A star that flares now and then: a four-point glint (two thin fading rays and a tiny glow) appears at a random
// spot, turns a little while it brightens and fades, then waits 1-4 s for the next place.
Item {
    id: s
    required property Item area
    property string glow: ""
    property int firstDelay: 800
    property real size: 18
    property real level: 0
    opacity: level
    scale: 0.4 + 0.6 * level
    rotation: level * 25

    component Ray: Rectangle {
        width: s.size; height: 1.2
        radius: 0.6
        anchors.centerIn: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.95) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
    Image {
        anchors.centerIn: parent
        width: s.size * 0.8; height: s.size * 0.8
        source: s.glow
        opacity: 0.6
        smooth: true
    }
    Ray {}
    Ray { rotation: 90 }
    Rectangle { anchors.centerIn: parent; width: 2; height: 2; radius: 1; color: "white" }

    function place() {
        // never over the logo, the clock or the login column (the middle 36 % of the login's monitor)
        const c = area.clear, l = c.x + c.width * 0.32, r = c.x + c.width * 0.68
        const free = area.width - (r - l)
        const u = Math.random() * free
        x = u < l ? u : u + (r - l)
        y = Math.random() * area.height * 0.85
        size = 12 + Math.random() * 16
        anim.restart()
    }
    SequentialAnimation {
        id: anim
        NumberAnimation { target: s; property: "level"; from: 0; to: 1; duration: 380; easing.type: Easing.OutQuad }
        NumberAnimation { target: s; property: "level"; to: 0; duration: 700; easing.type: Easing.InQuad }
        ScriptAction { script: { wait.interval = 1000 + Math.random() * 3000; wait.restart() } }
    }
    Timer {
        id: wait
        interval: s.firstDelay
        running: s.area.running
        onTriggered: s.place()
    }
    Connections {
        target: s.area
        function onRunningChanged() { if (!s.area.running) { anim.stop(); s.level = 0 } }
    }
}
