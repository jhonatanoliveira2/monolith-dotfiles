import QtQuick
import "../core"
import "../services"
import "../components"

MenuButton {
    id: root
    menu: "bluetooth"
    visible: Bt.present
    onAlt: m => { if (m.button === Qt.MiddleButton) Bt.setEnabled(!Bt.enabled) }
    Txt {
        font.pixelSize: root.vertical ? 18 : 15
        text: !Bt.enabled ? Theme.glyph.btOff : Bt.anyConnected ? Theme.glyph.btConn : Theme.glyph.btOn
        color: Bt.enabled ? Theme.grayLight : Theme.grayMid
    }
}
