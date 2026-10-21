
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
//
Singleton {
    id: root

    property string current: ""
    property string screenName: ""
    property real anchorX: 0
    property var buttons: ({})

    Timer {
        id: closeTimer
        interval: 300
        repeat: false
        onTriggered: root.close()
    }

    function register(screen, name, item) {
        buttons[screen + ":" + name] = item
    }

    function cancelClose() {
        closeTimer.stop()
    }

    function scheduleClose() {
        closeTimer.restart()
    }

    function close() {
        closeTimer.stop()
        current = ""
    }

    function show(name, screen, item) {
        if (!name || !screen) return

        closeTimer.stop()

        const it = item || buttons[screen + ":" + name]
        anchorX = it ? it.mapToItem(null, it.width / 2, 0).x : 0
        screenName = screen
        current = name
    }

    function toggle(name, screen, item) {
        if (current === name && screenName === screen) {
            close()
            return
        }

        show(name, screen, item)
    }

    function toggleFocused(name) {
        const m = Hyprland.focusedMonitor
        const s = m ? m.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
        toggle(name, s, null)
    }
}
