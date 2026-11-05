pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Details for the center menu's Performance tab: top apps by CPU / RAM / GPU, network speed, the shell's own
// usage (scripts/perf-stream.sh) and storage (lsblk, read when asked). Totals and temperatures come from
// Stats. The sampler runs only while `demand` > 0, i.e. while that tab is open.
Singleton {
    id: root
    property int demand: 0
    readonly property int historyLength: 40
    property real rx: 0                 // B/s
    property real tx: 0
    property real rxTotal: 0            // bytes since boot
    property real txTotal: 0
    property var rxHistory: []
    property var txHistory: []
    property var topCpu: []             // [{ name, v }]  v = % of the whole CPU
    property var topMem: []             //                v = bytes
    property var topGpu: []             //                v = %
    property real selfCpu: 0
    property real selfMem: 0
    property real selfGpu: 0
    property var disks: []              // [{ name, model, size, parts: [{ name, mount, fs, size, used, avail }] }]

    function push(list, v) { const l = list.concat([v]); return l.length > historyLength ? l.slice(l.length - historyLength) : l }
    function pairs(f, div) {
        const out = []
        for (let i = 1; i + 1 < f.length; i += 2) out.push({ name: f[i], v: Number(f[i + 1]) / div })
        return out
    }
    function bytes(b) {
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
        return (i === 0 ? Math.round(b) : b >= 100 ? Math.round(b) : b.toFixed(1)) + " " + u[i]
    }

    Process {
        running: root.demand > 0
        command: ["bash", Quickshell.shellPath("scripts/perf-stream.sh"), "2"]
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t")
                switch (f[0]) {
                case "net":
                    root.rx = Number(f[1]); root.tx = Number(f[2]); root.rxTotal = Number(f[3]); root.txTotal = Number(f[4])
                    root.rxHistory = root.push(root.rxHistory, root.rx); root.txHistory = root.push(root.txHistory, root.tx)
                    break
                case "cpu": root.topCpu = root.pairs(f, 10); break
                case "mem": root.topMem = root.pairs(f, 1); break
                case "gpu": root.topGpu = root.pairs(f, 10); break
                case "self": root.selfCpu = Number(f[1]) / 10; root.selfMem = Number(f[2]); root.selfGpu = Number(f[3]) / 10; break
                }
            }
        }
    }

    function refreshStorage() { if (!lsblk.running) lsblk.running = true }
    Process {
        id: lsblk
        command: ["lsblk", "-J", "-b", "-o", "NAME,TYPE,SIZE,MODEL,FSTYPE,FSSIZE,FSUSED,FSAVAIL,MOUNTPOINT,LABEL"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const flat = (n, out) => { out.push(n); for (const c of n.children || []) flat(c, out); return out }
                    root.disks = JSON.parse(text).blockdevices.filter(d => d.type === "disk" && Number(d.size) > 0).map(d => ({
                        name: d.name, model: String(d.model || "").trim(), size: Number(d.size),
                        parts: flat(d, []).filter(p => p.mountpoint && p.fssize && p.mountpoint !== "[SWAP]").map(p => ({
                            name: p.label || p.name, mount: p.mountpoint, fs: p.fstype || "",
                            size: Number(p.fssize), used: Number(p.fsused), avail: Number(p.fsavail) }))
                    })).filter(d => d.parts.length > 0)
                } catch (e) { console.warn("[perf] lsblk:", String(e)) }
            }
        }
    }
}
