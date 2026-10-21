import QtQuick
import "../core"
import "../services"
import "../components"

MenuButton {
    id: root
    menu: "notifications"
    onAlt: m => { if (m.button === Qt.MiddleButton) Settings.dnd = !Settings.dnd }
    Txt { text: Settings.dnd ? Theme.glyph.bellOff : Theme.glyph.bell; color: Settings.dnd ? Theme.grayMid : Theme.grayLight }
    Txt { visible: Notifs.count > 0; text: Notifs.count; color: Theme.foreground }
}
