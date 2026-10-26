import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../core"
import "../services"
import "../components"

// Battery and power profile (brightness has its own menu: BrightnessMenu.qml).
MenuWindow {
    menu: "power"
    panelWidth: 340

    Column {
        width: parent.width
        spacing: 4

        Item {
            visible: Battery.present
            width: parent.width; height: 72
            Txt {
                id: big
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: Math.round(Battery.pct) + "%"; font.pixelSize: 30; color: Theme.foreground
            }
            Column {
                anchors { left: big.right; leftMargin: 14; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 4
                Txt { width: parent.width; font.bold: false; text: (Battery.onAc ? Theme.glyph.bolt + "  " : "") + Battery.stateText() }
                Rectangle {
                    width: parent.width; height: 4; color: Theme.grayDark
                    Rectangle {
                        width: parent.width * Math.min(1, Battery.pct / 100); height: parent.height
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.grayMid } GradientStop { position: 1; color: Theme.white } }
                        Behavior on width { NumberAnimation { duration: Theme.dur(300) } }
                    }
                }
                // time left (or until full) and the current draw / charge rate
                Txt { visible: text !== ""; width: parent.width; font.bold: false; font.pixelSize: Theme.small; color: Theme.grayMid; text: Battery.detailText() }
            }
        }

        Section { width: parent.width; text: Strings.t("profile") }
        Flow {
            width: parent.width; spacing: 4
            Btn { text: Strings.t("saver"); icon: Theme.glyph.saver; active: PowerProfiles.profile === PowerProfile.PowerSaver; onActivated: PowerProfiles.profile = PowerProfile.PowerSaver }
            Btn { text: Strings.t("balanced"); icon: Theme.glyph.balanced; active: PowerProfiles.profile === PowerProfile.Balanced; onActivated: PowerProfiles.profile = PowerProfile.Balanced }
            Btn { visible: PowerProfiles.hasPerformanceProfile; text: Strings.t("performance"); icon: Theme.glyph.perf; active: PowerProfiles.profile === PowerProfile.Performance; onActivated: PowerProfiles.profile = PowerProfile.Performance }
        }
        Item { width: 1; height: 4; visible: Battery.present }
        ToggleRow { visible: Battery.present; width: parent.width; icon: Theme.glyph.saver; label: Strings.t("batSaver"); checked: Settings.batterySaver; onToggled: c => Settings.batterySaver = c }
    }
}
