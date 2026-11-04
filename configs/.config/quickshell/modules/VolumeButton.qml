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
    BarTxt { text: Audio.glyph(); color: Audio.muted ? BarTheme.grayMid : BarTheme.grayLight; font.pixelSize: Theme.barIcon }
    BarTxt { text: Math.round(Audio.volume * 100) + "%"; color: Audio.muted ? BarTheme.grayMid : BarTheme.grayLight; visible: !root.vertical }   // icon only on a side bar
}
