import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// A full-screen overlay (app launcher, wallpaper picker): dimmed backdrop (a click outside closes it),
// keyboard focus while open, Esc closes, and a centered card that rises, scales and fades in (and back out:
// OverlaySlot keeps it alive for the close animation). The card's height animates when its content changes.
PanelWindow {
    id: win
    property string name: ""
    property int cardWidth: 640
    property int cardHeight: 480
    default property alias content: card.data
    readonly property bool shown: entered && Popups.overlay === name
    property bool entered: false
    Component.onCompleted: entered = true

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-" + name
    mask: shown ? null : empty              // while closing, clicks already go to the windows below
    Region { id: empty }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; enabled: win.shown; onClicked: Popups.closeOverlay() }
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(win.cardWidth, parent.width - 40)
        height: Math.min(win.cardHeight, parent.height - 40)
        Behavior on height { enabled: win.entered; NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutCubic } }
        radius: Theme.menuRadius
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.line
        clip: true
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.dur(win.shown ? 220 : 160); easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.dur(win.shown ? 300 : 180); easing.type: win.shown ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.1 } }
        transform: Translate {
            y: win.shown ? 0 : 26
            Behavior on y { NumberAnimation { duration: Theme.dur(win.shown ? 300 : 180); easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent }        // clicks inside the card never reach the backdrop
    }
    Shortcut { sequence: "Escape"; enabled: win.shown; onActivated: Popups.closeOverlay() }
}
