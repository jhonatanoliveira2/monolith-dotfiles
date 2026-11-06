pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One-off commands with a result: exit code, stdout, stderr and a timeout, never blocking the UI.
// Every failure (non-zero exit, missing program, timeout) is logged with its command and error output,
// so problems in the network / Bluetooth backends leave a trace in `qs log` instead of vanishing.
//
//   Jobs.run("net", ["iwctl", "station", "wlan0", "scan"], { timeout: 10000 }, (ok, out, err) => { ... })
//
// The program is started through `sh -c 'exec "$@"'`, so a missing binary still ends with exit 127 and
// a readable error ("not found") instead of a process that never starts.
Singleton {
    id: root

    function run(tag, cmd, opts, done) {
        const o = opts || {}
        const job = jobComponent.createObject(root, { tag: tag, cmd: cmd, timeoutMs: o.timeout || 15000, done: done || null })
        job.running = true
        return job
    }
    // first meaningful line of an error output, for a one-line message in the UI
    function firstLine(s) { return String(s || "").split("\n").map(l => l.trim()).filter(l => l)[0] || "" }

    Component {
        id: jobComponent
        Process {
            id: job
            property string tag: ""
            property var cmd: []
            property int timeoutMs: 15000
            property var done: null
            property bool finished: false
            command: ["sh", "-c", "exec \"$@\"", "sh"].concat(cmd)
            stdout: StdioCollector { id: out }
            stderr: StdioCollector { id: err }
            function finish(ok, code, why) {
                if (finished) return
                finished = true
                limit.stop()
                // the collectors receive their last chunk with the exit: read them on the next turn
                Qt.callLater(() => {
                    const e = why || err.text.trim()
                    if (!ok) console.warn("[" + tag + "]", cmd.join(" "), "->", why ? why : "exit " + code, e && !why ? "| " + firstLine(e) : "")
                    if (done) done(ok, out.text, e, code)
                    job.destroy()
                })
            }
            onExited: (code, status) => finish(code === 0, code, "")
            // Process takes no child objects: the timeout timer hangs off a property
            property Timer limit: Timer { id: limit; interval: job.timeoutMs; running: job.running; onTriggered: { job.running = false; job.finish(false, -1, "timeout after " + job.timeoutMs / 1000 + " s") } }
        }
    }
}
