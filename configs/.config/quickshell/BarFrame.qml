import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Effects
import "core"

// "Frame" bar style (Settings > Bar > style), as in Caelestia: an opaque border around the screen, the bar's
// background included, with rounded inner corners, so everything visible sits inside it. It is drawn on the top
// layer over the whole screen, so windows never cover it; the bar itself is on the overlay layer, above it.
// The shape is one Rectangle whose border is the frame: it is larger than the screen by B on every side, so only
// the inner, rounded edge of the border shows (inner radius = radius - B). With Settings > Bar > shadow, the
// whole shape casts one inner shadow. Three empty layer surfaces reserve the frame width on the
// other edges so windows are laid out inside it. Click-through (empty input mask); loaded only in frame style.
Scope {
    id: root
    required property var screen
    readonly property string edge: Settings.barPosition
    readonly property int f: Theme.frameWidth

    Variants {
        model: ["top", "bottom", "left", "right"].filter(e => e !== root.edge)
        delegate: PanelWindow {
            required property string modelData
            screen: root.screen
            anchors { top: modelData !== "bottom"; bottom: modelData !== "top"; left: modelData !== "right"; right: modelData !== "left" }
            implicitHeight: modelData === "top" || modelData === "bottom" ? root.f : 0
            implicitWidth: modelData === "left" || modelData === "right" ? root.f : 0
            exclusiveZone: root.f
            color: "transparent"
            mask: Region {}
            // overlay: Hyprland lays out the layers bottom to top, so on a lower layer these would shrink the bar
            // (top layer) by the frame width at both ends, leaving empty squares in its corners
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-frame-zone"
        }
    }

    PanelWindow {
        id: win
        screen: root.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-frame"

        readonly property int b: Theme.barThickness
        readonly property int big: Math.max(b, root.f) + 64
        // drawn once into a layer; the optional shadow falls inward, over the edges of the content
        Item {
            anchors.fill: parent
            layer.enabled: Settings.barShadow
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: Settings.barShadowStrength / 100
                shadowBlur: 1.0
                blurMax: 32
            }
            Rectangle {
                // the hole: the screen minus the bar strip and the frame width on the other edges
                readonly property real hx: root.edge === "left" ? win.b : root.f
                readonly property real hy: root.edge === "top" ? win.b : root.f
                readonly property real hw: win.width - hx - (root.edge === "right" ? win.b : root.f)
                readonly property real hh: win.height - hy - (root.edge === "bottom" ? win.b : root.f)
                x: hx - win.big; y: hy - win.big
                width: hw + 2 * win.big; height: hh + 2 * win.big
                radius: Theme.frameRadius + win.big
                color: "transparent"
                border.width: win.big
                border.color: Theme.barSolid
            }
            // Nothing theme: a 1 px line along the inner edge, as in NIHIL Shell's frame (black + hairline)
            Rectangle {
                visible: Theme.nothing
                x: root.edge === "left" ? win.b : root.f
                y: root.edge === "top" ? win.b : root.f
                width: win.width - x - (root.edge === "right" ? win.b : root.f)
                height: win.height - y - (root.edge === "bottom" ? win.b : root.f)
                radius: Theme.frameRadius
                color: "transparent"
                border.width: 1
                border.color: Nothing.line
            }
        }
    }
}
