import QtQuick
import "core"

// Night sky behind the login, in depth:
//   * far layer: many tiny, dim stars (star dust), drifting down very slowly, some twinkling;
//   * near layer: fewer, larger stars, drifting a bit faster (parallax), twinkling, a few with a glow;
//   * sparkles (Sparkle.qml): a star flares into a small four-point glint now and then;
//   * falling stars (Meteor.qml).
// Each drifting layer is two identical copies stacked vertically, so the loop is seamless. Everything is plain
// items and property animations, and stops entirely when `running` is false (animations off, session starting).
Item {
    id: sky
    property bool running: true
    property string branding: ""
    readonly property real area: width * height / 1000000          // megapixels (~2 on 1920 x 1080)
    clip: true

    // deterministic pseudo-random numbers: both copies of a layer place star i at the same spot
    function rand(i, k) {
        const v = Math.sin(i * 12.9898 + k * 78.233) * 43758.5453
        return v - Math.floor(v)
    }

    component Layer: Item {
        id: lyr
        property int count: 100
        property int seed: 0
        property int period: 240000            // ms for one screen height of drift
        property real sizeMin: 0.6
        property real sizeMax: 1.6
        property real dimMin: 0.15
        property real dimMax: 0.7
        property real twinkleShare: 0.5        // fraction of the stars that twinkle
        property real glowShare: 0             // fraction drawn with a soft glow
        width: sky.width
        height: sky.height * 2
        NumberAnimation on y {
            from: -sky.height; to: 0
            duration: lyr.period
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
                    model: lyr.count
                    delegate: Item {
                        id: star
                        required property int index
                        readonly property int k: index + lyr.seed * 1000
                        readonly property real base: lyr.dimMin + (lyr.dimMax - lyr.dimMin) * sky.rand(k, 3)
                        readonly property bool twinkles: sky.rand(k, 9) < lyr.twinkleShare
                        readonly property bool glows: sky.rand(k, 4) < lyr.glowShare
                        readonly property real size: lyr.sizeMin + (lyr.sizeMax - lyr.sizeMin) * sky.rand(k, 5)
                        x: sky.rand(k, 1) * sky.width
                        y: sky.rand(k, 2) * sky.height
                        opacity: base
                        Image {
                            visible: star.glows
                            anchors.centerIn: dot
                            width: 14; height: 14
                            source: sky.branding ? "file://" + sky.branding + "/star.png" : ""
                            opacity: 0.5
                            smooth: true
                        }
                        Rectangle {
                            id: dot
                            width: star.size; height: star.size; radius: star.size / 2
                            color: "white"
                        }
                        SequentialAnimation on opacity {
                            running: sky.running && star.twinkles
                            loops: Animation.Infinite
                            PauseAnimation { duration: Math.round(sky.rand(star.k, 6) * 4000) }
                            NumberAnimation { to: star.base * 0.15; duration: 1200 + Math.round(sky.rand(star.k, 7) * 2800); easing.type: Easing.InOutSine }
                            NumberAnimation { to: star.base; duration: 1200 + Math.round(sky.rand(star.k, 8) * 2800); easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }

    // far: star dust
    Layer {
        count: Math.round(260 * sky.area)
        seed: 1
        period: 420000
        sizeMin: 0.5; sizeMax: 1.1
        dimMin: 0.12; dimMax: 0.5
        twinkleShare: 0.35
    }
    // near: brighter stars, faster drift
    Layer {
        count: Math.round(70 * sky.area)
        seed: 2
        period: 200000
        sizeMin: 1.0; sizeMax: 2.2
        dimMin: 0.3; dimMax: 0.9
        twinkleShare: 0.8
        glowShare: 0.12
    }

    Repeater {
        model: 6
        delegate: Sparkle {
            required property int index
            area: sky
            glow: sky.branding ? "file://" + sky.branding + "/star.png" : ""
            firstDelay: 400 + index * 700
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
