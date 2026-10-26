import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

// Outputs and per-application volume (the microphone has its own page).
Column {
    spacing: 8
    EntryList { page: "audio"; width: parent.width }

    Section { width: parent.width; text: Labels.t("outputs") }
    Repeater {
        model: Audio.sinks
        delegate: ListRow {
            required property var modelData
            width: parent.width
            icon: Theme.glyph.vol; title: Audio.label(modelData); selected: modelData === Audio.sink
            onClicked: m => Audio.setDefault(modelData)
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
