import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"

// Side bar: resting the pointer on the middle of the screen's top edge opens the center menu there (as NIHIL
// Shell's dashboard comes out of the top of its frame); it closes a moment after the pointer leaves both.
// A thin invisible strip on the overlay layer; in frame style it lies on the frame's top edge.
PanelWindow {
    id: zone
    property string screenName: screen ? screen.name : ""
    anchors.top: true
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 360
    implicitHeight: Math.max(4, Theme.frameEdge)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-center-hot"
    // not over a fullscreen video / app
    readonly property var hyprMonitor: screen ? Hyprland.monitorFor(screen) : null
    visible: !(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)

    Item {
        id: hot
        anchors.fill: parent
        HoverHandler {
            onHoveredChanged: {
                if (hovered) openSoon.restart()
                else { openSoon.stop(); Popups.leaveHover("center") }
            }
        }
        Timer { id: openSoon; interval: 200; onTriggered: Popups.hoverOpen("center", zone.screenName, hot) }
    }
}
