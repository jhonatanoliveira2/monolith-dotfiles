import QtQuick
import QtQuick.Layouts
import Qt.labs.qmlmodels
import Quickshell
import Quickshell.Wayland
import "core"
import "services"
import "components"
import "modules"

// The bar, on any edge of the screen (Settings > Bar > position). Its modules come from services/BarLayout.qml
// in three zones: start (left / top), center and end (right / bottom); on a vertical bar each zone is a column.
PanelWindow {
    id: bar
    required property var modelData
    readonly property string screenName: modelData.name
    readonly property string edge: Settings.barPosition
    readonly property bool vertical: Settings.barVertical

    screen: modelData
    anchors { top: edge !== "bottom"; bottom: edge !== "top"; left: edge !== "right"; right: edge !== "left" }
    implicitHeight: vertical ? 0 : Theme.barSize
    implicitWidth: vertical ? Theme.barSize : 0
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"

    // "keep awake" switch of the settings menu
    IdleInhibitor { window: bar; enabled: Settings.keepAwake }

    Rectangle { anchors.fill: parent; color: Theme.barBg }

    // one zone: its modules in order (a hidden module, e.g. no battery on a desktop, takes no room)
    component Zone: GridLayout {
        id: zone
        property var win: null                // the bar (inline components do not see this file's ids)
        property string name: ""
        flow: zone.win.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        property int gap: 6                   // Settings > Bar > spacing (a vertical bar uses 2/3 of it)
        rowSpacing: Math.round(gap * 2 / 3)
        columnSpacing: gap
        Repeater {
            model: BarLayout.zones[zone.name]
            delegate: DelegateChooser {
                role: "modelData"
                DelegateChoice {
                    roleValue: "logo"
                    MenuButton {
                        Layout.alignment: Qt.AlignCenter
                        menu: "settings"; screenName: zone.win.screenName; pad: 8
                        // the profile picture can replace the Arch logo (Settings > Profile)
                        Txt { visible: !Settings.profileAsLogo; text: Theme.glyph.arch; color: Theme.white; font.pixelSize: Settings.barVertical ? 18 : 15 }
                        Avatar { visible: Settings.profileAsLogo; width: 20; height: 20; source: Profile.avatar; initial: Profile.initial }
                    }
                }
                DelegateChoice { roleValue: "workspaces"; Workspaces { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
                DelegateChoice { roleValue: "player"; Player { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
                DelegateChoice { roleValue: "title"; WindowTitle { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
                DelegateChoice { roleValue: "clock"; Clock { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
                DelegateChoice { roleValue: "tray"; Tray { Layout.alignment: Qt.AlignCenter; window: zone.win } }
                DelegateChoice { roleValue: "sysmon"; SysMon { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
                DelegateChoice { roleValue: "network"; NetworkButton { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
                DelegateChoice { roleValue: "bluetooth"; BluetoothButton { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
                DelegateChoice { roleValue: "battery"; BatteryButton { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
                DelegateChoice { roleValue: "brightness"; BrightnessButton { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
                DelegateChoice { roleValue: "volume"; VolumeButton { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
                DelegateChoice { roleValue: "bell"; BellButton { Layout.alignment: Qt.AlignCenter; screenName: zone.win.screenName } }
            }
        }
    }

    // zones are placed by x / y, not by anchors: switching anchors at runtime (horizontal <-> vertical) can leave
    // a stale one set (e.g. horizontalCenter + right), which Qt silently ignores and the zone ends up off-screen
    Zone {
        win: bar
        name: "start"
        gap: Settings.barGapStart
        x: bar.vertical ? (parent.width - width) / 2 : 4
        y: bar.vertical ? 6 : (parent.height - height) / 2
    }
    Zone {
        win: bar
        name: "center"
        gap: Settings.barGapCenter
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
    }
    Zone {
        win: bar
        name: "end"
        gap: Settings.barGapEnd
        x: bar.vertical ? (parent.width - width) / 2 : parent.width - width - 4
        y: bar.vertical ? parent.height - height - 6 : (parent.height - height) / 2
    }
}
