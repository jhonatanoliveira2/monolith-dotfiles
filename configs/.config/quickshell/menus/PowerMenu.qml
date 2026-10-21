import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../core"
import "../services"
import "../components"

// Battery, power profile and screen brightness.
MenuWindow {
    menu: "power"
    panelWidth: 340

    Column {
        width: parent.width
        spacing: 4
        readonly property var dev: UPower.displayDevice
        readonly property bool hasBattery: dev !== null && dev !== undefined && dev.isPresent && dev.isLaptopBattery
        readonly property real pct: dev ? (dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0
        readonly property bool charging: dev && dev.state === UPowerDeviceState.Charging

        function span(s) {
            if (!s || s <= 0) return ""
            const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60)
            return (h > 0 ? h + "h " : "") + m + "min"
        }

        Item {
            visible: parent.hasBattery
            width: parent.width; height: 64
            Txt {
                id: big
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: Math.round(parent.parent.pct) + "%"; font.pixelSize: 30; color: Theme.foreground
            }
            Column {
                anchors { left: big.right; leftMargin: 14; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 4
                Txt {
                    width: parent.width; font.bold: false
                    text: parent.parent.parent.charging
                        ? Strings.t("charging") + (parent.parent.parent.dev.timeToFull > 0 ? "  ·  " + parent.parent.parent.span(parent.parent.parent.dev.timeToFull) : "")
                        : Strings.t("discharging") + (parent.parent.parent.dev.timeToEmpty > 0 ? "  ·  " + parent.parent.parent.span(parent.parent.parent.dev.timeToEmpty) : "")
                }
                Rectangle {
                    width: parent.width; height: 4; color: Theme.grayDark
                    Rectangle {
                        width: parent.width * Math.min(1, parent.parent.parent.parent.pct / 100); height: parent.height
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.grayMid } GradientStop { position: 1; color: Theme.white } }
                        Behavior on width { NumberAnimation { duration: Theme.dur(300) } }
                    }
                }
            }
        }

        Section { width: parent.width; text: Strings.t("profile") }
        Flow {
            width: parent.width; spacing: 4
            Btn { text: Strings.t("saver"); icon: Theme.glyph.saver; active: PowerProfiles.profile === PowerProfile.PowerSaver; onActivated: PowerProfiles.profile = PowerProfile.PowerSaver }
            Btn { text: Strings.t("balanced"); icon: Theme.glyph.balanced; active: PowerProfiles.profile === PowerProfile.Balanced; onActivated: PowerProfiles.profile = PowerProfile.Balanced }
            Btn { visible: PowerProfiles.hasPerformanceProfile; text: Strings.t("performance"); icon: Theme.glyph.perf; active: PowerProfiles.profile === PowerProfile.Performance; onActivated: PowerProfiles.profile = PowerProfile.Performance }
        }

        Section { width: parent.width; text: Strings.t("brightness"); visible: Brightness.available }
        Item {
            visible: Brightness.available
            width: parent.width; height: 30
            Txt { id: sun; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } text: Theme.glyph.backlight; font.pixelSize: 16 }
            ThinSlider {
                anchors { left: sun.right; leftMargin: 12; right: bp.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                value: Brightness.fraction
                onMoved: v => Brightness.set(v)
            }
            Txt { id: bp; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } width: 40; horizontalAlignment: Text.AlignRight; text: Math.round(Brightness.fraction * 100) + "%" }
        }
    }
}
