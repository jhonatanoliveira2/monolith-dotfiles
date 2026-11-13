import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../core"
import "../services"
import "../components"

// Outputs, the output equalizer / effects (services/AudioFx.qml) and per-application volume
// (the microphone has its own page).
Column {
    id: root
    spacing: 8
    readonly property var extras: Registry.byPage("audio").filter(e => e.cat === "audioExtra")

    PwNodePeakMonitor { id: peak; node: Audio.sink; enabled: Settings.audioFx && Audio.sink !== null }
    EntryList { page: "audio"; width: parent.width; except: ["audioExtra"] }
    EqCard {
        fx: AudioFx
        width: parent.width
        level: peak.peak
        visible: opacity > 0
        opacity: Settings.audioFx ? 1 : 0
        scale: Settings.audioFx ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.dur(200) } }
        Behavior on scale { NumberAnimation { duration: Theme.dur(200); easing.type: Easing.OutCubic } }
    }
    // bass / volume boost, virtualizer and 8D stay in a drawer so the page is not crowded
    Drawer {
        visible: Settings.audioFx
        width: parent.width
        title: Labels.t("audioMore")
        summary: [Settings.audioBass > 0 ? Labels.pick(["Grave", "Bass"]) + " +" + Settings.audioBass + " dB" : "",
                  Settings.audioBoost > 0 ? Labels.pick(["Volume", "Volume"]) + " +" + Settings.audioBoost + " dB" : "",
                  Settings.audioVirt > 0 ? Labels.pick(["Virtualizador", "Virtualizer"]) + " " + Settings.audioVirt + "%" : "",
                  Settings.audioSpin > 0 ? "8D " + Settings.audioSpin + "%" : ""].filter(x => x).join("  ·  ")
        Repeater {
            model: root.extras
            delegate: SettingRow { required property var modelData; entry: modelData; width: parent.width }
        }
        Txt { x: 10; width: parent.width - 20; text: Labels.t("audioBoostHint"); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false; wrapMode: Text.Wrap }
    }
    Txt { visible: AudioFx.active; x: 10; width: parent.width - 20; text: Labels.t("audioFxActive"); color: Theme.grayMid; font.pixelSize: Theme.small; wrapMode: Text.Wrap }
    Txt { visible: AudioFx.error !== ""; x: 10; width: parent.width - 20; text: AudioFx.error; color: Theme.foreground; font.pixelSize: Theme.small; wrapMode: Text.Wrap }

    Section { width: parent.width; text: Labels.t("outputs") }
    Repeater {
        model: Audio.sinks
        delegate: ListRow {
            required property var modelData
            width: parent.width
            icon: Theme.glyph.vol; title: Audio.label(modelData); selected: Audio.isCurrent(modelData)
            onClicked: m => Audio.setDefault(modelData)   // with the effects on this retargets the chain
        }
    }
    Section { width: parent.width; text: Labels.t("apps") }
    Txt { visible: Audio.streams.length === 0; x: 10; text: Labels.t("noApps"); color: Theme.grayMid }
    Repeater {
        model: Audio.streams
        delegate: Item {
            required property var modelData
            width: parent.width; height: 30
            Txt { id: n; x: 10; width: 160; height: parent.height; text: Audio.appName(modelData) }
            ThinSlider {
                anchors { left: n.right; right: pct.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                value: modelData.audio ? modelData.audio.volume : 0; onMoved: v => { if (modelData.audio) modelData.audio.volume = v }
            }
            Txt { id: pct; anchors.right: parent.right; width: 44; height: parent.height; horizontalAlignment: Text.AlignRight; color: Theme.grayMid; text: Math.round((modelData.audio ? modelData.audio.volume : 0) * 100) + "%" }
        }
    }
}
