pragma Singleton
import QtQuick
import "../core"
import Quickshell
import Quickshell.Io

// CPU / GPU / RAM from one fork-free shell loop (scripts/sysmon-stream.sh).
Singleton {
    id: root
    property int cpu: -1
    property int cpuTemp: -1
    property int gpu: -1
    property int gpuTemp: -1
    property int ramPct: 0
    property string ramUsed: "0.0"
    property string ramTotal: "0.0"
    property var cpuHistory: []         // last samples (one per interval), drawn by the stats menu
    property var ramHistory: []
    readonly property int historyLength: 40
    function push(list, v) { const l = list.concat([v]); return l.length > historyLength ? l.slice(l.length - historyLength) : l }
    readonly property int hottest: Math.max(cpuTemp, gpuTemp)
    readonly property string level: hottest >= 90 ? "critical" : hottest >= 80 ? "warning" : "normal"

    Process {
        running: Config.showSysmon
        command: ["bash", Quickshell.shellPath("scripts/sysmon-stream.sh"), "3"]
        stdout: SplitParser {
            onRead: line => {
                for (const kv of line.trim().split(" ")) {
                    const i = kv.indexOf("=")
                    if (i < 0) continue
                    const k = kv.slice(0, i), v = kv.slice(i + 1)
                    if (k === "cpu") root.cpu = Number(v)
                    else if (k === "cputemp") root.cpuTemp = Number(v)
                    else if (k === "gpu") root.gpu = Number(v)
                    else if (k === "gputemp") root.gpuTemp = Number(v)
                    else if (k === "ram") root.ramPct = Number(v)
                    else if (k === "ramused") root.ramUsed = v
                    else if (k === "ramtotal") root.ramTotal = v
                }
                if (root.cpu >= 0) root.cpuHistory = root.push(root.cpuHistory, root.cpu)
                root.ramHistory = root.push(root.ramHistory, root.ramPct)
            }
        }
    }
}
