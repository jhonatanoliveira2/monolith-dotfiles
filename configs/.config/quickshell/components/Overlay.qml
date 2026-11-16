import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// A full-screen overlay (app launcher, wallpaper picker): dimmed backdrop (a click outside closes it),
// keyboard focus while open, Esc closes, and a card (OverlaySlot keeps it alive for the close animation). The
// card's height animates when its content changes (not when the window gets its size).
//  - flat / capsule bar: the card is centred, and rises, scales and fades in (and back out)
//  - frame bar: the card is a drawer of the frame at the bottom centre, as the center menu is at the top: same
//    opaque colour, joined to the bottom edge (or to the bar, on a bottom bar) by concave fillets, the frame's
//    inner line running around it in the Nothing theme, and it slides up from behind the edge. Only the area
//    inside the frame is dimmed, so the frame and the drawer keep one colour.
PanelWindow {
    id: win
    property string name: ""
    property int cardWidth: 640
    property int cardHeight: 480
    default property alias content: card.data
    readonly property bool shown: entered && Popups.overlay === name
    property bool entered: false
    Component.onCompleted: entered = true

    readonly property bool drawer: Theme.barStyle === "frame"
    readonly property int fillet: drawer ? 14 : 0
    // the frame's inner edges (the hole the windows live in): the bar's thickness on its edge, the frame width elsewhere
    function inset(e) { return !drawer ? 0 : Settings.barPosition === e ? Theme.barThickness : Theme.frameEdge }
    readonly property int bottomOff: inset("bottom")

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-" + name
    mask: shown ? null : empty              // while closing, clicks already go to the windows below
    Region { id: empty }

    // backdrop: the whole screen, or (frame) the frame's hole with its rounded corners; a click on it closes
    MouseArea { anchors.fill: parent; enabled: win.shown; onClicked: Popups.closeOverlay() }
    Rectangle {
        x: win.inset("left"); y: win.inset("top")
        width: parent.width - x - win.inset("right"); height: parent.height - y - win.bottomOff
        radius: win.drawer ? Theme.frameRadius : 0
        color: Qt.rgba(0, 0, 0, 0.35)
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }
    }

    // drawer: concave joints with the bottom edge, left and right of the card (outside the quarter circle: frame
    // colour; its arc: the line in the Nothing theme). The hole is centred on the joint's top outer corner.
    component Joint: Item {
        id: jt
        property bool atRight: false
        readonly property int r: win.fillet
        readonly property int big: 2000
        readonly property int cx: atRight ? r : 0
        visible: win.drawer
        x: atRight ? card.x + card.width : card.x - r
        y: win.height - win.bottomOff - r
        width: r; height: r
        clip: true
        opacity: card.opacity
        Rectangle {
            x: jt.cx - jt.r - jt.big; y: -jt.r - jt.big
            width: 2 * (jt.r + jt.big); height: width
            radius: jt.r + jt.big
            color: "transparent"
            border.width: jt.big
            border.color: Theme.barSolid
        }
        Rectangle {
            visible: Theme.nothing
            x: jt.cx - jt.r; y: -jt.r
            width: 2 * jt.r; height: width
            radius: jt.r
            color: "transparent"
            border.width: 1
            border.color: Nothing.line
        }
    }
    Joint {}
    Joint { atRight: true }

    // drawer: the card slides up from behind the bottom edge, so it is clipped there (it never covers the frame / bar)
    Item {
        id: stage
        anchors { fill: parent; bottomMargin: win.bottomOff }
        clip: win.drawer
        Rectangle {
            id: card
            // drawer: centred in the frame's hole, leaving room for each joint plus the hole's rounded corner, so
            // the fillet never runs into that corner
            readonly property int holeX: win.inset("left")
            readonly property int holeW: win.width - holeX - win.inset("right")
            width: Math.min(win.cardWidth, win.drawer ? holeW - 2 * (win.fillet + Theme.frameRadius + 4) : win.width - 40)
            // only a change of content (cardHeight: the launcher's rows) animates. The room is applied at once: the
            // layer surface starts at height 0 and gets the screen's from the compositor just after it is created,
            // and animating that grew the card from nothing on every opening, laying out its content (the
            // picker's grid, the launcher's list) again on each frame of the open animation.
            property int wantedHeight: win.cardHeight
            Behavior on wantedHeight { enabled: win.entered; NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutCubic } }
            height: Math.max(0, Math.min(wantedHeight, win.height - 40 - (win.drawer ? win.inset("top") + win.bottomOff : 0)))
            x: win.drawer ? holeX + Math.round((holeW - width) / 2) : Math.round((stage.width - width) / 2)
            y: win.drawer ? stage.height - height : Math.round((stage.height - height) / 2)
            readonly property int r: Theme.nothing ? 20 : Theme.menuRadius
            radius: r
            bottomLeftRadius: win.drawer ? 0 : r
            bottomRightRadius: win.drawer ? 0 : r
            color: win.drawer ? Theme.barSolid : Theme.panelBg
            border.width: win.drawer ? 0 : 1
            border.color: Theme.nothing ? Nothing.line : Theme.line
            clip: true
            DotGrid { anchors.fill: parent; anchors.margins: 10; strength: 0.05; z: -1 }
            // drawer (Nothing theme): the frame's inner line around the top and the sides, ending where the joints'
            // arcs end (one fillet above the bottom edge)
            Item {
                visible: win.drawer && Theme.nothing
                width: parent.width; height: parent.height - win.fillet
                clip: true
                z: 10
                Rectangle {
                    width: parent.width; height: parent.height + card.r + win.fillet + 2
                    radius: card.r
                    color: "transparent"
                    border.width: 1
                    border.color: Nothing.line
                }
            }
            opacity: win.shown ? 1 : 0
            scale: win.shown || win.drawer ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: Theme.dur(win.shown ? 220 : 160); easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.dur(win.shown ? 300 : 180); easing.type: win.shown ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.1 } }
            transform: Translate {
                y: win.shown ? 0 : win.drawer ? card.height : 26
                Behavior on y { NumberAnimation { duration: Theme.dur(win.drawer ? 240 : win.shown ? 300 : 180); easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent }        // clicks inside the card never reach the backdrop
        }
    }
    Shortcut { sequence: "Escape"; enabled: win.shown; onActivated: Popups.closeOverlay() }
}
