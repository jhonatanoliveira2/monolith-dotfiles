import QtQuick
import Quickshell
import Quickshell.Io

// A long-running command whose output lines are events (`ip monitor`, `gdbus monitor`...): each line emits
// `event`. It runs while `wanted`; if it exits on its own it is logged with its error output and started
// again after a pause, so a backend that restarts does not leave the shell without updates.
Process {
    id: w
    property string label: ""
    property bool wanted: false
    signal event()
    running: wanted
    stdout: SplitParser { onRead: w.event() }
    // the last lines of the error output only: these commands run for the whole session
    property var errTail: []
    stderr: SplitParser { onRead: l => { if (l.trim()) w.errTail = w.errTail.concat([l.trim()]).slice(-5) } }
    onExited: code => {
        if (!w.wanted) return
        console.warn("[events]", w.label, "exited", code, w.errTail.join(" | "))
        w.errTail = []
        retryTimer.restart()
    }
    // Process takes no child objects: the retry timer hangs off a property
    property Timer retry: Timer { id: retryTimer; interval: 5000; onTriggered: if (w.wanted) w.running = true }
}
