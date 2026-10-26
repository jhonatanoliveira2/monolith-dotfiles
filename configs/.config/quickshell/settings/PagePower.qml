import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../core"
import "../services"
import "../components"

// Laptops only (the page is hidden without a battery): battery state and health, power profiles
// (power-profiles-daemon, when installed) and the power options of the Registry (services/Battery.qml).
Column {
    id: root
    spacing: 8
    property bool hasProfiles: false

    Process {
        running: true
        command: ["sh", "-c", "busctl --system list --no-legend 2>/dev/null | grep -qE 'net.hadess.PowerProfiles|org.freedesktop.UPower.PowerProfiles' && echo p"]
        stdout: StdioCollector {
            onStreamFinished: root.hasProfiles = text.split("\n").indexOf("p") >= 0
        }
    }

    Rectangle {
        width: parent.width; height: 92; color: "transparent"; border.width: 1; border.color: Theme.line; radius: Theme.radius
        Txt { id: big; x: 16; height: parent.height; text: Math.round(Battery.pct) + "%"; font.pixelSize: 32; color: Theme.white }
        Column {
            anchors { left: big.right; leftMargin: 18; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 5
            Txt { width: parent.width; text: Battery.stateText() + (Battery.detailText() ? "  ·  " + Battery.detailText() : ""); color: Theme.foreground }
            Rectangle {
                width: parent.width; height: 4; color: Theme.grayDark
                Rectangle { width: parent.width * Math.min(1, Battery.pct / 100); height: parent.height
                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.grayMid } GradientStop { position: 1; color: Theme.white } } }
            }
            Txt {
                width: parent.width; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
                readonly property var bat: Battery.bat
                text: bat ? [
                    bat.energyCapacity > 0 ? Labels.t("pwEnergy") + " " + bat.energy.toFixed(1) + " / " + bat.energyCapacity.toFixed(1) + " Wh" : "",
                    bat.healthSupported ? Labels.t("pwHealth") + " " + Math.round(bat.healthPercentage) + "%" : "",
                    Battery.limit > 0 && Battery.limit < 100 ? Labels.t("pwLimit") + " " + Battery.limit + "%" : "",
                    UPower.onBattery ? "" : Labels.t("pwAc")
                ].filter(x => x).join("  ·  ") : ""
            }
        }
    }

    Section { visible: root.hasProfiles; width: parent.width; text: Strings.t("profile") }
    Flow {
        visible: root.hasProfiles
        width: parent.width; spacing: 4
        Btn { text: Strings.t("saver"); icon: Theme.glyph.saver; active: PowerProfiles.profile === PowerProfile.PowerSaver; onActivated: PowerProfiles.profile = PowerProfile.PowerSaver }
        Btn { text: Strings.t("balanced"); icon: Theme.glyph.balanced; active: PowerProfiles.profile === PowerProfile.Balanced; onActivated: PowerProfiles.profile = PowerProfile.Balanced }
        Btn { visible: PowerProfiles.hasPerformanceProfile; text: Strings.t("performance"); icon: Theme.glyph.perf; active: PowerProfiles.profile === PowerProfile.Performance; onActivated: PowerProfiles.profile = PowerProfile.Performance }
    }
    Txt { visible: root.hasProfiles && PowerProfiles.degradationReason !== PerformanceDegradationReason.None; x: 10; color: Theme.grayMid; font.pixelSize: Theme.small
          text: Labels.t("pwDegraded") + ": " + PerformanceDegradationReason.toString(PowerProfiles.degradationReason) }
    Txt { visible: !root.hasProfiles; x: 10; width: parent.width - 20; wrapMode: Text.Wrap; elide: Text.ElideNone; color: Theme.grayMid; font.pixelSize: Theme.small; text: Labels.t("pwNoProfiles") }

    EntryList { page: "power"; width: parent.width }

    // other batteries (mouse, headset, …) reported by UPower
    readonly property var others: UPower.devices.values.filter(d => !d.isLaptopBattery && d.isPresent && d.type !== UPowerDeviceType.LinePower && d.percentage > 0)
    Section { visible: root.others.length > 0; width: parent.width; text: Labels.t("pwDevices") }
    Repeater {
        model: root.others
        delegate: ListRow { required property var modelData; width: root.width; icon: Theme.glyph.battery[2]
            title: String(modelData.model || UPowerDeviceType.toString(modelData.type)); trailing: Math.round(modelData.percentage > 1 ? modelData.percentage : modelData.percentage * 100) + "%" }
    }
}
