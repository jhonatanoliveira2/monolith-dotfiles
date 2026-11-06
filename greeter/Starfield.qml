import QtQuick
import "core"

// Night sky behind the login: twinkling stars drifting slowly down (two identical layers, so the loop is
// seamless) and a few falling stars (Meteor.qml). Everything is plain items and property animations: cheap
// for the GPU, and it stops entirely when `running` is false (animations off, or the session is starting).
Item {
    id: sky
    property bool running: true
    property int count: Math.round(width * height / 9000)   // ~230 stars on 1920 x 1080
    property string branding: ""
    clip: true

    // deterministic pseudo-random numbers: both layers place star i at the same spot
    function rand(i, k) {
        const v = Math.sin(i * 12.9898 + k * 78.233) * 43758.5453
        return v - Math.floor(v)
    }

    Item {
        id: drift
        width: sky.width
        height: sky.height * 2
        NumberAnimation on y {
            from: -sky.height; to: 0
            duration: 240000
            loops: Animation.Infinite
            running: sky.running
        }
        Repeater {
            model: 2
            delegate: Item {
                required property int index
                y: index * sky.height
                width: sky.width
                height: sky.height
                Repeater {
                    model: sky.count
                    delegate: Item {
                        id: star
                        required property int index
                        readonly property real base: 0.25 + 0.65 * sky.rand(index, 3)
                        readonly property bool bright: sky.rand(index, 4) > 0.94
                        readonly property real size: bright ? 2.4 : 0.8 + 1.4 * sky.rand(index, 5)
                        x: sky.rand(index, 1) * sky.width
                        y: sky.rand(index, 2) * sky.height
                        opacity: base
                        Image {
                            visible: star.bright
                            anchors.centerIn: dot
                            width: 16; height: 16
                            source: sky.branding ? "file://" + sky.branding + "/star.png" : ""
                            opacity: 0.55
                            smooth: true
                        }
                        Rectangle {
                            id: dot
                            width: star.size; height: star.size; radius: star.size / 2
                            color: "white"
                        }
                        SequentialAnimation on opacity {
                            running: sky.running
                            loops: Animation.Infinite
                            PauseAnimation { duration: Math.round(sky.rand(star.index, 6) * 3000) }
                            NumberAnimation { to: star.base * 0.2; duration: 1400 + Math.round(sky.rand(star.index, 7) * 2600); easing.type: Easing.InOutSine }
                            NumberAnimation { to: star.base; duration: 1400 + Math.round(sky.rand(star.index, 8) * 2600); easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }

    Repeater {
        model: 7
        delegate: Meteor {
            required property int index
            area: sky
            head: sky.branding ? "file://" + sky.branding + "/star.png" : ""
            firstDelay: 600 + index * 850
        }
    }
}
