import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

MenuWindow {
    menu: "audio"
    panelWidth: 360

    Column {
        width: parent.width
        spacing: 2

        // master volume
        Item {
            width: parent.width; height: 40
            Txt {
                id: ico
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: Audio.glyph(); font.pixelSize: 18; color: Audio.muted ? Theme.grayMid : Theme.foreground
                MouseArea { anchors.fill: parent; onClicked: Audio.toggleMute() }
            }
            ThinSlider {
                anchors { left: ico.right; leftMargin: 12; right: pct.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                value: Audio.volume
                onMoved: v => Audio.setVolume(v)
            }
            Txt { id: pct; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } width: 40; horizontalAlignment: Text.AlignRight; text: Math.round(Audio.volume * 100) + "%" }
        }

        Section { width: parent.width; text: Strings.t("output") }
        Repeater {
            model: Audio.sinks
            delegate: ListRow {
                required property var modelData
                width: parent.width
                icon: Theme.glyph.vol
                title: Audio.label(modelData)
                selected: Audio.sink !== null && Audio.sink !== undefined && modelData.id === Audio.sink.id
                onClicked: Audio.setDefault(modelData)
            }
        }

        Section { width: parent.width; text: Strings.t("input"); visible: Audio.source !== null && Audio.source !== undefined }
        Item {
            visible: Audio.source !== null && Audio.source !== undefined
            width: parent.width; height: 32
            Txt {
                id: mic
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: Audio.micMuted ? Theme.glyph.micOff : Theme.glyph.mic; color: Audio.micMuted ? Theme.grayMid : Theme.foreground
                MouseArea { anchors.fill: parent; onClicked: Audio.toggleMic() }
            }
            ThinSlider {
                anchors { left: mic.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                value: Audio.micVolume
                onMoved: v => Audio.setMic(v)
            }
        }

        Section { width: parent.width; text: Strings.t("apps"); visible: Audio.streams.length > 0 }
        Repeater {
            model: Audio.streams
            delegate: Item {
                required property var modelData
                width: parent.width; height: 28
                Txt { id: nm; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } width: 120; text: Audio.appName(modelData); font.bold: false }
                ThinSlider {
                    anchors { left: nm.right; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    value: modelData.audio ? modelData.audio.volume : 0
                    onMoved: v => { if (modelData.audio) modelData.audio.volume = v }
                }
            }
        }

        Item { width: 1; height: 6 }
        Btn { text: Strings.t("mixer"); onActivated: { Popups.close(); Quickshell.execDetached(["pavucontrol"]) } }
    }
}
