import QtQuick
import Quickshell
import "../core"
import "../components"

// Format from Settings > Appearance (Settings.clockPattern); ticks every second only when it shows seconds.
// A vertical bar stacks hours, minutes (seconds) and a short date.
MenuButton {
    id: root
    menu: "calendar"
    SystemClock { id: clock; precision: /s/.test(Settings.clockPattern.replace(/'[^']*'/g, "")) ? SystemClock.Seconds : SystemClock.Minutes }
    Txt { visible: !root.vertical; text: Qt.formatDateTime(clock.date, Settings.clockPattern) }
    Txt { visible: root.vertical; text: Qt.formatDateTime(clock.date, Settings.clock24 ? "HH" : "hh"); color: Theme.white }
    Txt { visible: root.vertical; text: Qt.formatDateTime(clock.date, "mm") }
    Txt { visible: root.vertical && Settings.clockSeconds; text: Qt.formatDateTime(clock.date, "ss"); font.pixelSize: Theme.small; color: Theme.grayMid }
    Txt { visible: root.vertical && Settings.clockDate !== ""; topPadding: 4; text: Qt.formatDateTime(clock.date, "dd\nMM"); font.pixelSize: Theme.small; color: Theme.grayMid
          horizontalAlignment: Text.AlignHCenter; lineHeight: 0.9 }
}
