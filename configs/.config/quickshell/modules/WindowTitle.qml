import QtQuick
import Quickshell.Hyprland
import "../core"
import "../components"

// Title of the focused window on this monitor (a module of Settings > Bar). Middle click closes it.
BarItem {
    id: root
    property string screenName: ""
    readonly property var win: Hyprland.activeToplevel
    readonly property bool here: win !== null && win.workspace !== null && win.workspace.monitor !== null && win.workspace.monitor.name === screenName
    visible: !vertical && here && label.text !== ""     // no room on a vertical bar
    onClicked: m => { if (m.button === Qt.MiddleButton) Hyprland.dispatch("hl.dsp.window.close()") }

    Txt { text: Theme.glyph.window; color: Theme.grayMid; font.pixelSize: 12 }
    Txt {
        id: label
        width: Math.min(implicitWidth, 260)
        text: root.win ? String(root.win.title || "") : ""
        color: Theme.grayMid
        font.bold: false
    }
}
