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
    readonly property int limit: Math.min(maxHeight, (screen ? screen.height : 1080) - Theme.barHeight - 30)
    default property Component contentComponent

    readonly property bool shown: Popups.current === menu && screen !== null && Popups.screenName === screen.name
    readonly property int pad: 8

    visible: shown || panel.opacity > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    margins {
        top: Theme.barHeight + Theme.gap
        left: Math.max(4, Math.min(Popups.anchorX - panelWidth / 2, (screen ? screen.width : 1920) - panelWidth - 4))
    }
    implicitWidth: panelWidth
    implicitHeight: panel.height

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-menu"

    HyprlandFocusGrab {
        windows: win.bar ? [win, win.bar] : [win]
        active: win.shown
    }
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
        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    Popups.cancelClose()
                else
                    Popups.scheduleClose()
            }
        }
        
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutCubic } }
        transform: Translate {
            y: win.shown ? 0 : -8
            Behavior on y { NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutCubic } }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: win.pad
            contentWidth: width
            contentHeight: loader.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Loader {
                id: loader
                width: parent.width
                active: win.visible
                sourceComponent: win.contentComponent
            }
        }
    }
}
