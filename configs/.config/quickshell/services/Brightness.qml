pragma Singleton
import QtQuick
import "../core"
import Quickshell
import Quickshell.Io

// Screen backlight and keyboard backlight (laptops). Reads sysfs directly (no process per refresh);
// writes through brightnessctl.
Singleton {
    id: root
    property string device: ""
    property real current: 0
    property real max: 1
    readonly property bool available: device !== "" && max > 1
    readonly property real fraction: max > 0 ? current / max : 0

    property string kbdDevice: ""             // /sys/class/leds/<x>::kbd_backlight
    property int kbdCurrent: 0
    property int kbdMax: 0
    readonly property bool kbdAvailable: kbdDevice !== "" && kbdMax > 0

    Process {
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -e \"$d/brightness\" ] && echo \"b $d\" && break; done; " +
                              "for d in /sys/class/leds/*kbd_backlight*; do [ -e \"$d/brightness\" ] && echo \"k $d\" && break; done"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim()
                if (p.startsWith("b ")) root.device = p.slice(2)
                else if (p.startsWith("k ")) root.kbdDevice = p.slice(2)
            }
        }
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
    FileView {
        id: kcur
        path: root.kbdDevice ? root.kbdDevice + "/brightness" : ""
        onLoaded: root.kbdCurrent = parseInt(text()) || 0
    }
    FileView {
        path: root.kbdDevice ? root.kbdDevice + "/max_brightness" : ""
        onLoaded: root.kbdMax = parseInt(text()) || 0
    }
    // the brightness keys go through the shell (see hypr/modules/media-keys.lua); this slow re-read only
    // catches outside changes such as hypridle dimming or the keyboard backlight keys (only with a backlight)
    Timer { interval: 10000; repeat: true; running: root.available || root.kbdAvailable; onTriggered: { if (root.available) cur.reload(); if (root.kbdAvailable) kcur.reload() } }
    function reload() { if (available) cur.reload(); if (kbdAvailable) kcur.reload() }

    // Many laptops change the backlight in firmware (the key never reaches Hyprland): the kernel still
    // sends a uevent, so show the OSD for changes this shell did not make (slider / keys mark `lastSet`).
    property double lastSet: 0
    Process {
        running: root.available || root.kbdAvailable
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight", "--subsystem-match=leds"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf(" change ") < 0) return
                const kbd = line.indexOf("kbd_backlight") >= 0
                if (!kbd && line.indexOf("/backlight/") < 0) return
                if (kbd) kcur.reload(); else cur.reload()
                if (Date.now() - root.lastSet > 1500) Osd.show(kbd ? "kbd" : "brightness")
            }
        }
    }

    function set(fraction) {
        lastSet = Date.now()
        const pct = Math.max(1, Math.min(100, Math.round(fraction * 100)))
        current = Math.round(pct / 100 * max)
        Quickshell.execDetached(["brightnessctl", "-q", "set", pct + "%"])
    }
    function nudge(deltaPct) { set(fraction + deltaPct / 100) }
    function setKbd(level) {
        if (!kbdAvailable) return
        lastSet = Date.now()
        kbdCurrent = Math.max(0, Math.min(kbdMax, Math.round(level)))
        Quickshell.execDetached(["brightnessctl", "-q", "-d", kbdDevice.split("/").pop(), "set", String(kbdCurrent)])
    }
    function kbdNudge(dir) { setKbd(kbdCurrent + dir * Math.max(1, Math.round(kbdMax / 10))) }
}
