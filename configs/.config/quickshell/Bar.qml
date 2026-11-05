import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
    // capsule shadow: the window grows by `pad` on the inner side to draw it; that strip reserves no space and
    // takes no clicks (exclusiveZone / mask stay the bar itself)
    readonly property bool shadow: Settings.barShadow && capsule
    readonly property int pad: shadow ? 20 : 0
    implicitHeight: vertical ? 0 : Theme.barThickness + pad
    implicitWidth: vertical ? Theme.barThickness + pad : 0
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barThickness
    mask: Region { x: strip.x; y: strip.y; width: strip.width; height: strip.height }
    color: "transparent"
    // frame style: above BarFrame (top layer), which draws this bar's background together with the border
    WlrLayershell.layer: Theme.barStyle === "frame" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "qs-bar"

    // "keep awake" switch of the settings menu
    IdleInhibitor { window: bar; enabled: Settings.keepAwake }

    // the bar's own strip of the window (the rest is the shadow pad)
    readonly property bool capsule: Theme.barStyle === "capsule"
    Item {
        id: strip
        x: bar.edge === "right" ? bar.pad : 0
        y: bar.edge === "bottom" ? bar.pad : 0
        width: bar.vertical ? Theme.barThickness : bar.width
        height: bar.vertical ? bar.height : Theme.barThickness
    }
    // background: the band shape (+ the capsule fillets), drawn once into a layer when it has a shadow, so the
    // blur is not redone when a module changes. Frame style: transparent (BarFrame draws it).
    Item {
        id: bg
        anchors.fill: parent
        layer.enabled: bar.shadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: Settings.barShadowStrength / 100
            shadowBlur: 1.0
            blurMax: 24
            shadowHorizontalOffset: bar.edge === "left" ? 2 : bar.edge === "right" ? -2 : 0
            shadowVerticalOffset: bar.edge === "top" ? 3 : bar.edge === "bottom" ? -3 : 0
        }
        Rectangle {
            x: band.x; y: band.y; width: band.width; height: band.height
            readonly property real r: bar.capsule ? Theme.barSize / 2 : 0
            topLeftRadius: bar.edge === "bottom" || bar.edge === "right" ? r : 0
            topRightRadius: bar.edge === "bottom" || bar.edge === "left" ? r : 0
            bottomLeftRadius: bar.edge === "top" || bar.edge === "right" ? r : 0
            bottomRightRadius: bar.edge === "top" || bar.edge === "left" ? r : 0
            color: Theme.barStyle === "frame" ? "transparent" : Theme.barBg
        }
    }
    // the band the modules live in: the whole strip (flat / frame) or the capsule (margin at both ends, rounded
    // only on the side away from the screen edge)
    Item {
        id: band
        x: strip.x + (bar.capsule && !bar.vertical ? Theme.barSideGap : 0)
        y: strip.y + (bar.capsule && bar.vertical ? Theme.barSideGap : 0)
        width: bar.vertical ? Theme.barSize : strip.width - (bar.capsule ? 2 * Theme.barSideGap : 0)
        height: bar.vertical ? strip.height - (bar.capsule ? 2 * Theme.barSideGap : 0) : Theme.barSize
    }
    // center menu: resting the pointer on the middle of the bar opens it (Settings > Bar > center menu).
    // Only a HoverHandler and a timer live here; the menu itself is created on demand (MenuSlot).
    Item {
        id: hot
        parent: band
        visible: Settings.centerMenu
        width: bar.vertical ? parent.width : Math.max(centerZone.width + 48, parent.width * 0.16)
        height: bar.vertical ? Math.max(centerZone.height + 48, parent.height * 0.16) : parent.height
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        HoverHandler {
            id: hotHover
            onHoveredChanged: {
                if (hovered) openSoon.restart()
                else { openSoon.stop(); Popups.leaveHover("center") }
            }
        }
        Timer { id: openSoon; interval: 280; onTriggered: Popups.hoverOpen("center", bar.screenName, hot) }
        Component.onCompleted: Popups.register(bar.screenName, "center", hot)   // IPC / shortcut open it centered
    }
    // capsule: concave fillets where the ends meet the screen edge. Each is a square with the border trick: a
    // transparent rounded "hole" whose corner sits on the square's filled corner, so only the area outside the
    // quarter circle gets the bar colour. `corner` is the filled one (touching the screen edge and the bar).
    component Fillet: Item {
        id: fl
        property string corner: "tr"
        readonly property int r: Theme.barFillet
        readonly property int big: 2000
        width: r; height: r
        clip: true
        Rectangle {
            readonly property bool atRight: fl.corner === "tr" || fl.corner === "br"
            readonly property bool atTop: fl.corner === "tl" || fl.corner === "tr"
            x: (atRight ? fl.r - fl.big : 0) - fl.big
            y: (atTop ? 0 : fl.r - fl.big) - fl.big
            width: fl.big * 3; height: fl.big * 3
            radius: fl.r + fl.big
            color: "transparent"
            border.width: fl.big
            border.color: Theme.barBg
        }
    }
    Fillet {
        parent: bg
        visible: bar.capsule
        corner: bar.vertical ? (bar.edge === "left" ? "bl" : "br") : (bar.edge === "top" ? "tr" : "br")
        x: bar.vertical ? (bar.edge === "left" ? 0 : bar.width - width) : band.x - width
        y: bar.vertical ? band.y - height : (bar.edge === "top" ? 0 : bar.height - height)
    }
    Fillet {
        parent: bg
        visible: bar.capsule
        corner: bar.vertical ? (bar.edge === "left" ? "tl" : "tr") : (bar.edge === "top" ? "tl" : "bl")
        x: bar.vertical ? (bar.edge === "left" ? 0 : bar.width - width) : band.x + band.width
        y: bar.vertical ? band.y + band.height : (bar.edge === "top" ? 0 : bar.height - height)
    }
    readonly property int endPad: capsule ? Math.round(Theme.barSize / 2) - 6 : 4   // keeps the end modules off the rounded ends

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
                        BarTxt { visible: !Settings.profileAsLogo; text: Theme.glyph.distro; color: BarTheme.white; font.pixelSize: Settings.barVertical ? 18 : 15 }
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
        parent: band
        win: bar
        name: "start"
        gap: Settings.barGapStart
        x: bar.vertical ? (parent.width - width) / 2 : bar.endPad
        y: bar.vertical ? bar.endPad + 2 : (parent.height - height) / 2
    }
    Zone {
        id: centerZone
        parent: band
        win: bar
        name: "center"
        gap: Settings.barGapCenter
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
    }
    Zone {
        parent: band
        win: bar
        name: "end"
        gap: Settings.barGapEnd
        x: bar.vertical ? (parent.width - width) / 2 : parent.width - width - bar.endPad
        y: bar.vertical ? parent.height - height - bar.endPad - 2 : (parent.height - height) / 2
    }
}
