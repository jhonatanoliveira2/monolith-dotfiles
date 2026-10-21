pragma Singleton
import QtQuick
import "../core"
import Quickshell
import Quickshell.Io

// NetworkManager through nmcli, event driven (`nmcli monitor`), plus a real connectivity probe.
Singleton {
    id: root
    property string status: "disconnected"    // online | nointernet | disconnected
    property string kind: "none"              // wifi | wired | none
    property string device: ""
    property string connection: ""
    property int signal: 0
    property bool wifiEnabled: true
    property bool scanning: false
    property bool busy: false
    property string message: ""
    property var networks: []                 // [{ssid, signal, secure, active, known}]
    property var knownNames: []
    readonly property bool connected: status !== "disconnected"

    function refresh() { devProc.running = true; radioProc.running = true }
    function scan() { scanning = true; scanProc.running = true }
    function setWifi(on) { Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]) }
    function disconnect() { if (device) Quickshell.execDetached(["nmcli", "device", "disconnect", device]) }
    function forget(ssid) { Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid]); refreshSoon.restart() }
    // The password goes in argv: fine on a single-user desktop, but it is visible in `ps` for a moment.
    function connectTo(ssid, password) {
        busy = true
        message = ""
        connProc.command = password
            ? ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
            : ["nmcli", "dev", "wifi", "connect", ssid]
        connProc.running = true
    }

    Timer { id: refreshSoon; interval: 600; onTriggered: root.refresh() }
    Timer { id: debounce; interval: 400; onTriggered: root.refresh() }
    Timer { id: monRestart; interval: 10000; onTriggered: monitor.running = true }
    // re-check connectivity from time to time (slower while everything works)
    Timer {
        interval: root.status === "online" ? 30000 : 8000
        repeat: true
        running: root.connected
        onTriggered: probe.running = true
    }

    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser { onRead: line => debounce.restart() }
        onExited: monRestart.start()
    }

    Process {
        id: devProc
        command: ["nmcli", "-t", "-e", "no", "-f", "TYPE,STATE,DEVICE,CONNECTION", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let kind = "none", dev = "", conn = ""
                for (const line of text.split("\n")) {
                    const p = line.split(":")
                    if (p.length < 4 || p[1] !== "connected") continue
                    if (p[0] !== "wifi" && p[0] !== "ethernet") continue
                    if (kind === "none" || p[0] === "ethernet") {
                        kind = p[0] === "wifi" ? "wifi" : "wired"
                        dev = p[2]
                        conn = p.slice(3).join(":")
                    }
                }
                root.kind = kind
                root.device = dev
                root.connection = conn
                if (kind === "none") { root.status = "disconnected"; root.signal = 0 }
                else probe.running = true
                if (kind === "wifi" || root.networks.length === 0) { knownProc.running = true }
            }
        }
    }

    Process {
        id: probe
        command: ["curl", "-s", "-o", "/dev/null", "-m", "3", "--connect-timeout", "2", "-w", "%{http_code}",
                  "http://connectivitycheck.gstatic.com/generate_204"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.kind === "none") return
                root.status = text.trim() === "204" ? "online" : "nointernet"
            }
        }
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiEnabled = text.trim() === "enabled" }
    }

    Process {
        id: knownProc
        command: ["nmcli", "-t", "-e", "no", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = []
                for (const line of text.split("\n")) {
                    const i = line.lastIndexOf(":")
                    if (i > 0 && line.slice(i + 1).indexOf("wireless") >= 0) names.push(line.slice(0, i))
                }
                root.knownNames = names
                listProc.running = true
            }
        }
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-e", "no", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "dev", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const best = {}
                for (const line of text.split("\n")) {
                    const a = line.indexOf(":"), b = line.indexOf(":", a + 1), c = line.indexOf(":", b + 1)
                    if (a < 0 || b < 0 || c < 0) continue
                    const ssid = line.slice(c + 1)
                    if (!ssid) continue
                    const e = { ssid: ssid, signal: Number(line.slice(a + 1, b)), secure: line.slice(b + 1, c) !== "" && line.slice(b + 1, c) !== "--",
                                active: line.slice(0, a) === "*", known: root.knownNames.indexOf(ssid) >= 0 }
                    const old = best[ssid]
                    if (!old || e.active || (!old.active && e.signal > old.signal)) best[ssid] = e
                }
                const list = Object.values(best)
                list.sort((x, y) => (y.active - x.active) || (y.signal - x.signal))
                root.networks = list
                const act = list.find(n => n.active)
                root.signal = act ? act.signal : 0
            }
        }
    }

    Process {
        id: scanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        onExited: { root.scanning = false; knownProc.running = true }
    }

    Process {
        id: connProc
        stderr: StdioCollector { id: connErr }
        stdout: StdioCollector { id: connOut }
        onExited: code => {
            root.busy = false
            root.message = code === 0 ? "" : (connErr.text.trim() || connOut.text.trim())
            root.refresh()
        }
    }

    Component.onCompleted: refresh()
}
