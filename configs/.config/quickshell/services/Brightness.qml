pragma Singleton
import QtQuick
import "../core"
import Quickshell
import Quickshell.Io

// Screen backlight (laptops). Reads sysfs directly (no process per refresh); writes through brightnessctl.
Singleton {
    id: root
    property string device: ""
    property real current: 0
    property real max: 1
    readonly property bool available: device !== "" && max > 1
    readonly property real fraction: max > 0 ? current / max : 0

    Process {
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -e \"$d/brightness\" ] && echo \"$d\" && break; done"]
        running: true
        stdout: SplitParser { onRead: line => root.device = line.trim() }
    }

    FileView {
        id: cur
        path: root.device ? root.device + "/brightness" : ""
        onLoaded: root.current = parseInt(text())
    }
    FileView {
        id: mx
        path: root.device ? root.device + "/max_brightness" : ""
        onLoaded: root.max = parseInt(text())
    }
    // brightness keys change the value behind our back: re-read it every few seconds (only when a backlight exists)
    Timer { interval: 4000; repeat: true; running: root.available; onTriggered: cur.reload() }

    function set(fraction) {
        const pct = Math.max(1, Math.min(100, Math.round(fraction * 100)))
        current = Math.round(pct / 100 * max)
        Quickshell.execDetached(["brightnessctl", "-q", "set", pct + "%"])
    }
    function nudge(deltaPct) { set(fraction + deltaPct / 100) }
}
