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
    stderr: StdioCollector { id: err }
    onExited: code => {
        if (!w.wanted) return
        console.warn("[events]", w.label, "exited", code, Jobs.firstLine(err.text))
        retry.restart()
    }
    // Process takes no child objects: the retry timer hangs off a property
    property Timer retry: Timer { id: retry; interval: 5000; onTriggered: if (w.wanted) w.running = true }
}
