import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"

// Hover strip that opens a menu pinned to the middle of a screen edge, as NIHIL Shell's dashboard comes out of
// the top of its frame; the menu closes a moment after the pointer leaves both.
//  - edge "top" (side bar): the center menu, from the middle of the top edge
//  - edge "right": the session menu (menus/SessionMenu.qml), from the middle of the right edge
// A thin invisible strip on the overlay layer; in frame style it lies on the frame's edge. When the bar is on that
// edge the strip is only its outermost pixels, so the bar's own buttons there stay clickable.
PanelWindow {
    id: zone
    property string menu: "center"
    property string edge: "top"
    property int length: 360                // along the edge
    readonly property bool sideways: edge === "right"
    readonly property int depth: Settings.barPosition === edge ? 3 : Math.max(4, Theme.frameEdge)
    property string screenName: screen ? screen.name : ""
    anchors { top: edge === "top"; right: edge === "right" }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: sideways ? depth : length
    implicitHeight: sideways ? length : depth
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-" + menu + "-hot"
    // not over a fullscreen video / app
    readonly property var hyprMonitor: screen ? Hyprland.monitorFor(screen) : null
    visible: !(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)

    Item {
        id: hot
        anchors.fill: parent
        HoverHandler {
            onHoveredChanged: {
                if (hovered) openSoon.restart()
                else { openSoon.stop(); Popups.leaveHover(zone.menu) }
            }
        }
        Timer { id: openSoon; interval: 200; onTriggered: Popups.hoverOpen(zone.menu, zone.screenName, hot) }
    }
}
