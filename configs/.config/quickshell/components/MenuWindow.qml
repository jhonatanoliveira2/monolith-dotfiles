import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"

// A popup menu: a layer-shell window next to the bar (any edge), closes on Esc or outside click.
// Floating: a rounded card a few px from the bar that fades / slides in. Attached (default on side and bottom
// bars, Settings > Bar > menu style): flush with the bar, square corners on the bar side, and it slides out
// from behind the bar. Its content is only instantiated while the menu is visible.
PanelWindow {
    id: win
    property string menu: ""
    property var bar: null
    property int panelWidth: 340
    property int maxHeight: 640
    property bool hoverScroll: false   // full scrollbar that shows on hover instead of the thin indicator
    property bool hoverKeep: false     // opened by hovering (center menu): stays while hovered, closes on leave
    readonly property string screenName: bar ? bar.screenName : ""
    readonly property int screenW: bar && bar.screen ? bar.screen.width : 1920
    readonly property int screenH: bar && bar.screen ? bar.screen.height : 1080
    // topCenter (the center menu with a side bar): opens at the top centre whatever the bar's edge; in frame
    // style it is a drawer of the frame, as in NIHIL Shell: same opaque colour, joined to the top edge by concave
    // fillets, the frame's inner line running around it
    property bool topCenter: false
    readonly property bool drawer: topCenter && Theme.barStyle === "frame"
    readonly property int fillet: drawer ? 14 : 0
    readonly property string edge: topCenter ? "top" : Settings.barPosition
    readonly property bool vertical: !topCenter && Settings.barVertical
    readonly property bool attached: topCenter ? drawer : Settings.menuStyle === "attached" || (Settings.menuStyle === "auto" && edge !== "top")
    readonly property int off: topCenter ? (drawer ? Theme.frameEdge : Theme.frameEdge + 8) : Theme.barThickness + (attached ? 0 : Theme.gap)
    readonly property int limit: Math.min(maxHeight, screenH - (vertical ? 16 : Theme.barThickness + 30))
    default property Component contentComponent

    // `entered` flips right after creation so the open animation runs (menus are created on demand)
    property bool entered: false
    Component.onCompleted: { entered = true; grab.active = shown && (!hoverKeep || Popups.pinned) }
    readonly property bool shown: entered && Popups.current === menu && screenName !== "" && Popups.screenName === screenName
    readonly property int pad: 8

    visible: shown || panel.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: edge !== "bottom"; bottom: edge === "bottom"; left: !topCenter && edge !== "right"; right: !topCenter && edge === "right" }
    margins {
        top: edge === "top" ? off : vertical ? Math.max(4, Math.min(Popups.anchorY - panel.height / 2, screenH - panel.height - 4)) : 0
        bottom: edge === "bottom" ? off : 0
        left: topCenter ? 0 : edge === "left" ? off : vertical ? 0 : Math.max(4, Math.min(Popups.anchorX - panelWidth / 2, screenW - panelWidth - 4))
        right: edge === "right" ? off : 0
    }
    implicitWidth: panelWidth + 2 * fillet
    implicitHeight: panel.height

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-menu"

    // The grab sets `active` to false by itself when the user clicks elsewhere, so drive it imperatively
    // (a binding would be broken by that write) and close the menu when it is cleared.
    HyprlandFocusGrab {
        id: grab
        windows: win.bar ? [win, win.bar] : [win]
        onCleared: if (win.shown) Popups.close()
    }
    // a menu opened by hovering does not grab focus (it closes when the pointer leaves); clicked ones do
    onShownChanged: grab.active = shown && (!hoverKeep || Popups.pinned)
    // ...and grabs once something pins it (typing in the center menu's command line)
    Connections { target: Popups; function onPinnedChanged() { grab.active = win.shown && (!win.hoverKeep || Popups.pinned) } }
    Shortcut { sequence: "Escape"; enabled: win.shown; onActivated: Popups.close() }

    // drawer: concave joints with the frame's top edge (outside the quarter circle: frame colour; its arc: the line)
    component Joint: Item {
        id: jt
        property bool atRight: false
        readonly property int r: win.fillet
        readonly property int big: 2000
        visible: win.drawer
        x: atRight ? panel.x + panel.width : panel.x - r
        width: r; height: r
        clip: true
        opacity: panel.opacity
        // a ring whose hole is the circle of radius r centred on the joint's outer bottom corner: the ring fills
        // the square outside the quarter circle
        Rectangle {
            x: (jt.atRight ? jt.r : 0) - jt.r - jt.big; y: -jt.big
            width: 2 * (jt.r + jt.big); height: width
            radius: jt.r + jt.big
            color: "transparent"
            border.width: jt.big
            border.color: Theme.barSolid
        }
        Rectangle {          // the frame's line along the arc (Nothing theme)
            visible: Theme.nothing
            x: jt.atRight ? 0 : -jt.r
            width: 2 * jt.r; height: width
            radius: jt.r
            color: "transparent"
            border.width: 1
            border.color: Nothing.line
        }
    }
    Joint {}
    Joint { atRight: true }

    Rectangle {
        id: panel
        x: win.fillet
        width: win.panelWidth
        height: Math.min(loader.implicitHeight + win.pad * 2 + 2, win.limit)
        color: win.drawer ? Theme.barSolid : Theme.panelBg
        readonly property int r: Theme.menuRadius
        radius: r
        topLeftRadius: win.attached && (win.edge === "top" || win.edge === "left") ? 0 : r
        topRightRadius: win.attached && (win.edge === "top" || win.edge === "right") ? 0 : r
        bottomLeftRadius: win.attached && (win.edge === "bottom" || win.edge === "left") ? 0 : r
        bottomRightRadius: win.attached && (win.edge === "bottom" || win.edge === "right") ? 0 : r
        border.width: win.attached ? 0 : 1
        border.color: Theme.line
        clip: true
        // drawer (Nothing theme): the frame's inner line continues around the drawer (not along its top edge)
        Rectangle {
            visible: win.drawer && Theme.nothing
            x: 0; y: -panel.r - 2
            width: parent.width; height: parent.height + panel.r + 2
            radius: panel.r
            color: "transparent"
            border.width: 1
            border.color: Nothing.line
            z: 10
        }

        // direction away from the bar: attached menus come out from behind it, floating ones nudge in
        readonly property real dx: win.edge === "left" ? -1 : win.edge === "right" ? 1 : 0
        readonly property real dy: win.edge === "top" ? -1 : win.edge === "bottom" ? 1 : 0
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(win.attached ? 200 : 140); easing.type: Easing.OutCubic } }
        transform: [
            Translate {
                x: win.shown ? 0 : panel.dx * (win.attached ? panel.width : 8)
                y: win.shown ? 0 : panel.dy * (win.attached ? panel.height : 8)
                Behavior on x { NumberAnimation { duration: Theme.dur(win.attached ? 240 : 180); easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: Theme.dur(win.attached ? 240 : 180); easing.type: Easing.OutCubic } }
            },
            Scale {
                origin.x: panel.width / 2
                xScale: win.shown || win.attached ? 1 : 0.97; yScale: xScale
                Behavior on xScale { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutCubic } }
            }
        ]

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: win.pad
            contentWidth: width
            contentHeight: loader.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            clip: true
            Loader {
                id: loader
                width: parent.width
                sourceComponent: win.contentComponent
            }
        }
        HoverHandler {
            enabled: win.hoverKeep
            onHoveredChanged: hovered ? Popups.cancelClose() : Popups.leaveHover(win.menu)
        }
        HoverScrollBar {   // sits in the panel padding, not over the content
            visible: win.hoverScroll
            flick: flick
            anchors.right: parent.right
            anchors.rightMargin: 1
        }
        Rectangle {   // scroll indicator, only for long menus
            visible: !win.hoverScroll && flick.interactive
            anchors.right: parent.right
            anchors.rightMargin: 3
            y: win.pad + flick.visibleArea.yPosition * flick.height
            width: 2; radius: 1
            height: flick.visibleArea.heightRatio * flick.height
            color: Theme.grayMid
            opacity: flick.moving ? 0.9 : 0.35
            Behavior on opacity { NumberAnimation { duration: Theme.dur(200) } }
        }
    }
}
