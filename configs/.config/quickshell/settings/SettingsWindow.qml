import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Opens the Settings app. "window": a real floating window (add a Hyprland float rule for the title
// "Monolith Settings"). "overlay": a layer-shell surface over everything (never tiled).
Scope {
    LazyLoader {
        active: Popups.appOpen && Config.settingsMode === "window"
        FloatingWindow {
            title: "Monolith Settings"
            implicitWidth: 1000
            implicitHeight: 660
            color: "transparent"
            visible: true
            onVisibleChanged: if (!visible) Popups.closeApp()
            SettingsApp { anchors.fill: parent }
        }
    }
    LazyLoader {
        active: Popups.appOpen && Config.settingsMode === "overlay"
        PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: Qt.rgba(0, 0, 0, 0.45)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            MouseArea { anchors.fill: parent; onClicked: Popups.closeApp() }
            SettingsApp { width: Math.min(1000, parent.width - 80); height: Math.min(660, parent.height - 80); anchors.centerIn: parent }
        }
    }
}
