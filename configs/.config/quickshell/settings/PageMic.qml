import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../core"
import "../services"
import "../components"

// Microphone: input device, volume, mute, a live level meter (only while this page is open) and the apps recording.
Column {
    id: root
    spacing: 8

    PwNodePeakMonitor { id: peak; node: Audio.source; enabled: Audio.source !== null && !Audio.micMuted }
    Item {
        width: parent.width; height: 34
        Txt { id: mi; x: 10; width: 24; height: parent.height; text: Audio.micMuted ? Theme.glyph.micOff : Theme.glyph.mic; font.pixelSize: 16 }
        Rectangle {
            anchors { left: mi.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            height: 6; radius: 3; color: Theme.grayDark
            Rectangle {
                width: parent.width * Math.min(1, peak.peak * 1.4); height: parent.height; radius: 3
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.grayMid } GradientStop { position: 1; color: Theme.white } }
                Behavior on width { NumberAnimation { duration: 80 } }
            }
        }
    }
    Txt { visible: Audio.source === null; x: 10; text: Labels.t("noMic"); color: Theme.grayMid }
    EntryList { page: "mic"; width: parent.width }

    Section { width: parent.width; text: Labels.t("inputs") }
    Repeater {
        model: Audio.sources
        delegate: ListRow {
            required property var modelData
            width: parent.width
            icon: Theme.glyph.mic; title: Audio.label(modelData); selected: modelData === Audio.source
            onClicked: m => Audio.setDefault(modelData)
        }
    }
    Section { width: parent.width; text: Labels.t("recording") }
    Txt { visible: Audio.recorders.length === 0; x: 10; text: Labels.t("noRecording"); color: Theme.grayMid }
    Repeater {
        model: Audio.recorders
        delegate: ListRow { required property var modelData; width: parent.width; icon: Theme.glyph.mic; title: Audio.appName(modelData) }
    }
}
