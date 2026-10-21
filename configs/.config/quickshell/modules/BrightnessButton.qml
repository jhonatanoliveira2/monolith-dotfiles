import QtQuick
import "../core"
import "../services"
import "../components"

// Laptops only (needs a backlight). Scroll to change; click opens the power menu.
MenuButton {
    id: root
    menu: "power"
    property real acc: 0
    visible: Brightness.available
    onScrolled: w => {
        acc += w.angleDelta.y
        while (Math.abs(acc) >= 60) { Brightness.nudge(acc > 0 ? 5 : -5); acc -= acc > 0 ? 60 : -60 }
    }
    Txt { text: Theme.glyph.backlight }
    Txt { text: Math.round(Brightness.fraction * 100) + "%" }
}
