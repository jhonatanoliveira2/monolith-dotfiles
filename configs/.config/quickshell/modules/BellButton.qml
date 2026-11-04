import QtQuick
import "../core"
import "../services"
import "../components"

MenuButton {
    id: root
    menu: "notifications"
    onAlt: m => { if (m.button === Qt.MiddleButton) Settings.dnd = !Settings.dnd }
    BarTxt { text: Settings.dnd ? Theme.glyph.bellOff : Theme.glyph.bell; color: Settings.dnd ? BarTheme.grayMid : BarTheme.grayLight; font.pixelSize: Theme.barIcon }
    BarTxt { visible: Notifs.count > 0; text: Notifs.count; color: BarTheme.foreground }
}
