import QtQuick
import "../core"

// Scrollbar for a Flickable / ListView / GridView: hidden until the pointer is over the view (or it is
// scrolling), then fades in and fades out again shortly after the pointer leaves. The thumb widens under
// the pointer and can be dragged; clicking the track jumps there. Place it as a sibling of the view.
Item {
    id: bar
    required property Flickable flick
    readonly property bool needed: flick.contentHeight > flick.height + 1
    readonly property bool hot: barHover.hovered || area.pressed
    readonly property bool active: needed && (viewHover.hovered || hot || flick.moving)
    // `shown` follows `active` but drops only after a short delay, so a momentary hover gap
    // (pointer crossing from the view onto the bar, a re-layout) never hides the bar
    property bool shown: false
    onActiveChanged: if (active) { hideTimer.stop(); shown = true } else hideTimer.restart()
    Timer { id: hideTimer; interval: 500; onTriggered: bar.shown = bar.active }
    // scroll progress 0..1, independent of originY (ListView / GridView can start above 0)
    readonly property real span: Math.max(1, flick.contentHeight - flick.height)
    readonly property real progress: Math.max(0, Math.min(1, (flick.contentY - flick.originY) / span))

    width: 10
    anchors { top: flick.top; bottom: flick.bottom; right: flick.right }
    // stays in the scene while faded out, so the strip keeps receiving hover and never loses track of the pointer
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.dur(bar.shown ? 120 : 260); easing.type: Easing.OutCubic } }

    HoverHandler { id: viewHover; parent: bar.flick }
    HoverHandler { id: barHover; enabled: bar.needed }

    Rectangle {
        id: thumb
        anchors.right: parent.right
        width: bar.hot ? 6 : 3
        radius: width / 2
        height: Math.max(24, flick.visibleArea.heightRatio * bar.height)
        y: bar.progress * (bar.height - height)
        color: bar.hot ? Theme.grayLight : Theme.grayMid
        opacity: area.pressed ? 1 : bar.hot ? 0.9 : 0.6
        Behavior on width { NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: bar.needed
        preventStealing: true          // the view must not flick while the thumb is dragged
        property real grab: 0
        function seek(my) {
            const p = (my - grab) / Math.max(1, bar.height - thumb.height)
            bar.flick.contentY = bar.flick.originY + Math.max(0, Math.min(1, p)) * bar.span
        }
        onPressed: m => {
            // grab the thumb where it was pressed; a press on the track centres the thumb there
            grab = m.y >= thumb.y && m.y <= thumb.y + thumb.height ? m.y - thumb.y : thumb.height / 2
            seek(m.y)
        }
        onPositionChanged: m => { if (pressed) seek(m.y) }
        onWheel: w => w.accepted = false   // let the wheel reach the view underneath
    }
}
