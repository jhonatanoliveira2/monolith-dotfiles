import QtQuick
import Quickshell
import "../core"
import "../components"

// Format from Settings > Appearance (Settings.clockPattern); ticks every second only when it shows seconds.
// A vertical bar stacks hours, minutes (seconds) and a short date.
MenuButton {
    id: root
    // side bar: the clock opens the whole center menu at the top centre (the calendar is in its Dashboard)
    menu: root.vertical && Settings.centerMenu ? "center" : "calendar"
    SystemClock { id: clock; precision: /s/.test(Settings.clockPattern.replace(/'[^']*'/g, "")) ? SystemClock.Seconds : SystemClock.Minutes }
    BarTxt { visible: !root.vertical; text: Qt.formatDateTime(clock.date, Settings.clockPattern)
             font.family: Theme.fontDot; font.pixelSize: Theme.nothing && Nothing.hasDot ? 17 : Theme.fontSize
             font.weight: Theme.nothing && Nothing.hasDot ? Font.Black : Font.Bold }
    // side bar: hours over minutes; Nothing theme: in Doto, minutes dimmer (as NIHIL Shell's bar clock)
    readonly property bool dots: root.vertical && Theme.nothing && Nothing.hasDot
    BarTxt { visible: root.vertical; text: Qt.formatDateTime(clock.date, Settings.clock24 ? "HH" : "hh"); color: BarTheme.white
             font.family: root.dots ? Theme.fontDot : Theme.font; font.pixelSize: root.dots ? 20 : Theme.fontSize
             font.weight: root.dots ? Font.Black : Font.Bold; bottomPadding: root.dots ? -6 : 0 }
    BarTxt { visible: root.vertical; text: Qt.formatDateTime(clock.date, "mm"); color: root.dots ? BarTheme.grayMid : BarTheme.grayLight
             font.family: root.dots ? Theme.fontDot : Theme.font; font.pixelSize: root.dots ? 20 : Theme.fontSize
             font.weight: root.dots ? Font.Black : Font.Bold }
    BarTxt { visible: root.vertical && Settings.clockSeconds; text: Qt.formatDateTime(clock.date, "ss"); font.pixelSize: Theme.small; color: BarTheme.grayMid }
    BarTxt { visible: root.vertical && Settings.clockDate !== ""; topPadding: 4; text: Qt.formatDateTime(clock.date, "dd\nMM"); font.pixelSize: Theme.small; color: BarTheme.grayMid
          horizontalAlignment: Text.AlignHCenter; lineHeight: 0.9 }
}
