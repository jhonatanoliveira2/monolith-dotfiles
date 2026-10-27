import QtQuick
import "../core"
import "../services"
import "../components"

// Scroll = volume (touchpad friendly), middle click = mute, click = audio menu.
MenuButton {
    id: root
    menu: "audio"
    property real acc: 0
    onAlt: m => { if (m.button === Qt.MiddleButton) Audio.toggleMute() }
    onScrolled: w => {
        acc += w.angleDelta.y
        while (Math.abs(acc) >= 60) { Audio.nudge(acc > 0 ? Config.volumeStep : -Config.volumeStep); acc -= acc > 0 ? 60 : -60 }
    }
    Txt { text: Audio.glyph(); color: Audio.muted ? Theme.grayMid : Theme.grayLight }
    Txt { text: Math.round(Audio.volume * 100) + "%"; color: Audio.muted ? Theme.grayMid : Theme.grayLight; font.pixelSize: Settings.barVertical ? Theme.small : Theme.fontSize }
}
