import QtQuick
import Quickshell
import "../core"
import "../components"

MenuButton {
    menu: "calendar"
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Txt { text: Qt.formatDateTime(clock.date, "HH:mm ~ dd/MM/yy") }
}
