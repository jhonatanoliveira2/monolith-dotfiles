import QtQuick

// One falling star: a glowing head with a fading tail, crossing the sky diagonally (top right -> bottom left),
// then waiting a random 1-4.5 s before the next one from another place.
Item {
    id: m
    required property Item area
    property string head: ""
    property int firstDelay: 1500
    readonly property real angle: 32                     // degrees below the horizontal
    readonly property real dx: -Math.cos(angle * Math.PI / 180)
    readonly property real dy: Math.sin(angle * Math.PI / 180)
    property real len: 180
    property real startX: 0
    property real startY: 0
    property real dist: 600
    property real progress: 0
    // bloom: strongest when the star appears, fading as it crosses the sky
    readonly property real bloom: 1 - progress
    x: startX + dx * dist * progress
    y: startY + dy * dist * progress
    opacity: 0

    // the tail points back along the path (up and to the right)
    Item {
        rotation: -m.angle
        transformOrigin: Item.TopLeft
        Rectangle {
            x: 0; y: -1
            width: m.len; height: 2
            radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.95) }
                GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, 0.35) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
        // soft glow along the start of the tail, fading with the bloom
        Rectangle {
            x: 0; y: -5
            width: m.len * (0.35 + 0.3 * m.bloom); height: 10
            radius: 5
            opacity: 0.35 + 0.65 * m.bloom
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.3) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }
    // wide bloom around the head: large and bright at first, shrinking and dimming along the way
    Image {
        readonly property real size: 110 * (0.45 + 0.55 * m.bloom)
        x: -size / 2; y: -size / 2
        width: size; height: size
        source: m.head
        smooth: true
        opacity: 0.8 * m.bloom
    }
    Image {
        x: -14; y: -14
        width: 28; height: 28
        source: m.head
        smooth: true
    }

    function launch() {
        const w = area.width, h = area.height
        startX = w * (0.35 + Math.random() * 0.75)
        startY = -h * 0.05 + Math.random() * h * 0.35
        dist = h * (0.45 + Math.random() * 0.4)
        len = 120 + Math.random() * 160
        fly.duration = 900 + Math.random() * 900
        progress = 0
        anim.restart()
    }

    SequentialAnimation {
        id: anim
        ParallelAnimation {
            NumberAnimation { id: fly; target: m; property: "progress"; from: 0; to: 1; easing.type: Easing.InQuad }
            SequentialAnimation {
                NumberAnimation { target: m; property: "opacity"; from: 0; to: 1; duration: Math.round(fly.duration * 0.15) }
                PauseAnimation { duration: Math.round(fly.duration * 0.45) }
                NumberAnimation { target: m; property: "opacity"; to: 0; duration: Math.round(fly.duration * 0.4) }
            }
        }
        ScriptAction { script: { wait.interval = 1000 + Math.random() * 3500; wait.restart() } }
    }
    Timer {
        id: wait
        interval: m.firstDelay
        running: m.area.running
        onTriggered: m.launch()
    }
    Connections {
        target: m.area
        function onRunningChanged() { if (!m.area.running) { anim.stop(); m.opacity = 0 } }
    }
}
