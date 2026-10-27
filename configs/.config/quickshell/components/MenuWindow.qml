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
    readonly property string screenName: bar ? bar.screenName : ""
    readonly property int screenW: bar && bar.screen ? bar.screen.width : 1920
    readonly property int screenH: bar && bar.screen ? bar.screen.height : 1080
    readonly property string edge: Settings.barPosition
    readonly property bool vertical: Settings.barVertical
    readonly property bool attached: Settings.menuStyle === "attached" || (Settings.menuStyle === "auto" && edge !== "top")
    readonly property int off: Theme.barSize + (attached ? 0 : Theme.gap)
    readonly property int limit: Math.min(maxHeight, screenH - (vertical ? 16 : Theme.barSize + 30))
    default property Component contentComponent

    // `entered` flips right after creation so the open animation runs (menus are created on demand)
    property bool entered: false
    Component.onCompleted: { entered = true; grab.active = shown }
    readonly property bool shown: entered && Popups.current === menu && screenName !== "" && Popups.screenName === screenName
    readonly property int pad: 8

    visible: shown || panel.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: edge !== "bottom"; bottom: edge === "bottom"; left: edge !== "right"; right: edge === "right" }
    margins {
        top: edge === "top" ? off : vertical ? Math.max(4, Math.min(Popups.anchorY - panel.height / 2, screenH - panel.height - 4)) : 0
        bottom: edge === "bottom" ? off : 0
        left: edge === "left" ? off : vertical ? 0 : Math.max(4, Math.min(Popups.anchorX - panelWidth / 2, screenW - panelWidth - 4))
        right: edge === "right" ? off : 0
    }
    implicitWidth: panelWidth
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
    onShownChanged: grab.active = shown
    Shortcut { sequence: "Escape"; enabled: win.shown; onActivated: Popups.close() }

    Rectangle {
        id: panel
        width: parent.width
        height: Math.min(loader.implicitHeight + win.pad * 2 + 2, win.limit)
        color: Theme.panelBg
        readonly property int r: Theme.menuRadius
        radius: r
        topLeftRadius: win.attached && (win.edge === "top" || win.edge === "left") ? 0 : r
        topRightRadius: win.attached && (win.edge === "top" || win.edge === "right") ? 0 : r
        bottomLeftRadius: win.attached && (win.edge === "bottom" || win.edge === "left") ? 0 : r
        bottomRightRadius: win.attached && (win.edge === "bottom" || win.edge === "right") ? 0 : r
        border.width: win.attached ? 0 : 1
        border.color: Theme.line
        clip: true

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
        Rectangle {   // scroll indicator, only for long menus
            visible: flick.interactive
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
