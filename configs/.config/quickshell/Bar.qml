import QtQuick
import Quickshell
import Quickshell.Wayland
import "core"
import "services"
import "components"
import "modules"

// The bar: same proportions, border, transparency and typography as the former Waybar.
PanelWindow {
    id: bar
    required property var modelData
    readonly property string screenName: modelData.name

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"

    // "keep awake" switch of the settings menu
    IdleInhibitor { window: bar; enabled: Settings.keepAwake }

    Rectangle {
        anchors { fill: parent; leftMargin: 1; rightMargin: 1; topMargin: 1 }
        color: Theme.barBg
        radius: 1
        border.width: 1
        border.color: Theme.line

        // ── left: logo, workspaces, player ────────────────────────────
        Row {
            id: left
            anchors.left: parent.left
            anchors.leftMargin: 4
            height: parent.height
            MenuButton {
                menu: "settings"
                screenName: bar.screenName
                pad: 8
                Txt { text: Theme.glyph.arch; color: Theme.white; font.pixelSize: 15 }
            }
            Workspaces { height: parent.height; screenName: bar.screenName }
            Item { width: 8; height: 1 }
            Player { height: parent.height; screenName: bar.screenName }
            WindowTitle { height: parent.height; screenName: bar.screenName }
        }

        // ── center: clock ─────────────────────────────────────────────
        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            screenName: bar.screenName
        }

        // ── right: tray and status modules ────────────────────────────
        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: 4
            height: parent.height
            spacing: 6
            Tray { height: parent.height; window: bar }
            SysMon { screenName: bar.screenName }
            NetworkButton { screenName: bar.screenName }
            BluetoothButton { screenName: bar.screenName }
            BatteryButton { screenName: bar.screenName }
            BrightnessButton { screenName: bar.screenName }
            VolumeButton { screenName: bar.screenName }
            BellButton { screenName: bar.screenName }
        }
    }
}
