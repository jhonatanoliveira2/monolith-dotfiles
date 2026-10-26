import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"

// A popup menu: a layer-shell window that hangs below the bar, fades/slides in, closes on Esc or outside click.
// Its content is only instantiated while the menu is visible (nothing runs for closed menus).
PanelWindow {
    id: win
    property string menu: ""
    property var bar: null
    property int panelWidth: 340
    property int maxHeight: 640
    readonly property string screenName: bar ? bar.screenName : ""
    readonly property int screenW: bar ? bar.width : 1920
    readonly property int limit: Math.min(maxHeight, (bar && bar.screen ? bar.screen.height : 1080) - Theme.barHeight - 30)
    default property Component contentComponent

    // `entered` flips right after creation so the open animation runs (menus are created on demand)
    property bool entered: false
    Component.onCompleted: { entered = true; grab.active = shown }
    readonly property bool shown: entered && Popups.current === menu && screenName !== "" && Popups.screenName === screenName
    readonly property int pad: 8

    visible: shown || panel.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    margins {
        top: Theme.barHeight + Theme.gap
        left: Math.max(4, Math.min(Popups.anchorX - panelWidth / 2, screenW - panelWidth - 4))
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
        radius: Theme.menuRadius
        border.width: 1
        border.color: Theme.line
        clip: true

        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutCubic } }
        transform: [
            Translate {
                y: win.shown ? 0 : -8
                Behavior on y { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutCubic } }
            },
            Scale {
                origin.x: panel.width / 2
                xScale: win.shown ? 1 : 0.97; yScale: xScale
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
