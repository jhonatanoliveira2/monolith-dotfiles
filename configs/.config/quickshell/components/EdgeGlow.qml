import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"

// Nothing theme, "edge glow" (Settings > Themes > Nothing): a segment of light runs once around the inside of
// the screen edge when the shell starts (login, restart) and when a notification arrives, twice and red when it
// is critical, like the light strips on
// the back of a Nothing phone (the idea of NIHIL Shell's GlyphLight, MIT, redrawn here). The window exists
// only while the light runs, ignores the pointer and reserves no space.
Scope {
    id: scope
    property var screen: null
    property real progress: 0
    property bool critical: false
    property int laps: 1

    function start(crit) {
        if (!Nothing.edgeGlow || !Config.animations) return
        critical = crit
        laps = crit ? 2 : 1
        run.restart()
    }
    // the shell starting (login, or a restart of the shell): one lap of light, once the settings and the
    // theme are known (up to ~15 s after start)
    Timer {
        interval: 1200; repeat: true; running: true
        property int tries: 0
        onTriggered: {
            if (Settings.loaded && Nothing.available) { stop(); scope.start(false) }
            else if (++tries > 12) stop()
        }
    }
    Connections {
        target: Notifs
        function onArrived(crit) { scope.start(crit) }
    }
    NumberAnimation {
        id: run
        target: scope; property: "progress"; from: 0; to: scope.laps
        duration: Math.round(1500 * scope.laps * Math.max(0.5, Config.animationScale))
        easing.type: Easing.InOutSine
    }

    LazyLoader {
        active: run.running
        PanelWindow {
            screen: scope.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-edge-glow"

            Shape {
                id: ring
                anchors.fill: parent
                readonly property real inset: 3 + Theme.frameEdge
                readonly property real rad: Theme.frameEdge > 0 ? Theme.frameRadius : 14
                readonly property real w: width - 2 * inset
                readonly property real h: height - 2 * inset
                readonly property real perimeter: 2 * (w + h) - 8 * rad + 2 * Math.PI * rad
                readonly property real segment: Math.min(320, perimeter / 6)
                readonly property real head: (scope.progress % 1) * perimeter
                // clockwise from the middle of the top edge
                readonly property string path: {
                    const i = inset, r = rad, x1 = i + w, y1 = i + h, cx = i + w / 2
                    return `M ${cx} ${i} L ${x1 - r} ${i} A ${r} ${r} 0 0 1 ${x1} ${i + r} L ${x1} ${y1 - r} `
                         + `A ${r} ${r} 0 0 1 ${x1 - r} ${y1} L ${i + r} ${y1} A ${r} ${r} 0 0 1 ${i} ${y1 - r} `
                         + `L ${i} ${i + r} A ${r} ${r} 0 0 1 ${i + r} ${i} Z`
                }
                readonly property color tint: scope.critical ? Nothing.alert : Nothing.ink
                // the segment ends at the head; dash units are multiples of the stroke width
                function dashes(sw) { return [segment / sw, perimeter / sw] }
                function offset(sw) { return (segment - head) / sw }
                // fade in and out at the ends of the run
                opacity: Math.min(1, scope.progress * 6, (scope.laps - scope.progress) * 6)
                preferredRendererType: Shape.CurveRenderer

                ShapePath {           // bloom
                    fillColor: "transparent"
                    strokeColor: Qt.rgba(ring.tint.r, ring.tint.g, ring.tint.b, 0.18)
                    strokeWidth: 12; capStyle: ShapePath.RoundCap
                    strokeStyle: ShapePath.DashLine
                    dashPattern: ring.dashes(12); dashOffset: ring.offset(12)
                    PathSvg { path: ring.path }
                }
                ShapePath {           // core
                    fillColor: "transparent"
                    strokeColor: ring.tint
                    strokeWidth: 3; capStyle: ShapePath.RoundCap
                    strokeStyle: ShapePath.DashLine
                    dashPattern: ring.dashes(3); dashOffset: ring.offset(3)
                    PathSvg { path: ring.path }
                }
            }
        }
    }
}
