import QtQuick
import "../core"
import "../services"
import "../components"

// Laptops only (needs a backlight). Scroll to change; click opens the brightness menu.
MenuButton {
    id: root
    menu: "brightness"
    property real acc: 0
    visible: Brightness.available
    onScrolled: w => {
        acc += w.angleDelta.y
        while (Math.abs(acc) >= 60) { Brightness.nudge(acc > 0 ? 5 : -5); acc -= acc > 0 ? 60 : -60 }
    }
    BarTxt { text: Theme.glyph.backlight; font.pixelSize: Theme.barIcon }
    BarTxt { text: Math.round(Brightness.fraction * 100) + "%"; visible: !root.vertical }   // icon only on a side bar
}
