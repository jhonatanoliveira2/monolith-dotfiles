pragma Singleton
import QtQuick
import "../core"
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Network state for the bar, the menus and the Settings page, over whichever backend is running.
// Quickshell.Networking only implements NetworkManager, so:
//  - NetworkManager (whatever its Wi-Fi backend, iwd included): the native D-Bus backend — no processes,
//    no polling; device, network and connectivity changes arrive as D-Bus signals.
//  - iwd on its own: state from its D-Bus API (busctl), actions through iwctl.
//  - systemd-networkd (or anything else): link / route state from `ip -j`; wired down via networkctl.
//  - systemd-resolved: DNS servers from resolvectl (otherwise /etc/resolv.conf).
// Without NetworkManager the state is polled: every 10 s, every 2.5 s while a menu scans or connects.
// Wi-Fi scanning only runs while a menu that lists networks is open (see scan()).
Singleton {
    id: root

    // ── backend ──
    readonly property bool nm: Networking.backend === NetworkBackendType.NetworkManager
    property var services: ({})               // systemctl is-active of the four backends
    readonly property bool iwd: !nm && services["iwd"] === true
    readonly property bool networkd: services["systemd-networkd"] === true
    readonly property bool resolved: services["systemd-resolved"] === true
    readonly property string backend: nm ? "NetworkManager" : [iwd ? "iwd" : "", networkd ? "systemd-networkd" : ""].filter(s => s).join(" + ")
    readonly property bool available: backend !== ""

    // ── NetworkManager (native) ──
    readonly property var devices: nm ? Networking.devices.values : []
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected)
        || devices.find(d => d.type === DeviceType.Wired) || null
    readonly property var wifiDev: devices.find(d => d.type === DeviceType.Wifi) || null
    readonly property var activeWifi: wifiDev ? (wifiDev.networks.values.find(n => n.connected) || null) : null
    readonly property string nmKind: wired && wired.connected ? "wired" : activeWifi ? "wifi" : "none"
    readonly property var activeDevice: nmKind === "wired" ? wired : nmKind === "wifi" ? wifiDev : null

    // ── fallback state (iwd / networkd / plain links), filled by the poll ──
    // {kind, device, connection, signal, online, wifi: {name, powered, hardware, scanning} | null, networks}
    property var fb: ({ kind: "none", device: "", connection: "", signal: 0, online: false, wifi: null, networks: [] })

    // ── summary used by the bar / menus ──
    readonly property string kind: nm ? nmKind : fb.kind
    readonly property string device: nm ? (activeDevice ? activeDevice.name : "") : fb.device
    readonly property string connection: !nm ? fb.connection
        : kind === "wifi" ? activeWifi.name : kind === "wired" ? (wiredName || wired.name) : ""
    readonly property int signal: nm ? (activeWifi ? pct(activeWifi.signalStrength) : 0) : fb.signal
    // waves lit in the Wi-Fi icon (components/WifiIcon.qml): 4 strong .. 1 weak
    readonly property int signalLevel: signal >= 75 ? 4 : signal >= 50 ? 3 : signal >= 25 ? 2 : signal > 0 ? 1 : 0
    readonly property string status: kind === "none" ? "disconnected"
        : !nm ? (fb.online ? "online" : "nointernet")
        : (Networking.connectivity === NetworkConnectivity.Full || Networking.connectivity === NetworkConnectivity.Unknown) ? "online" : "nointernet"
    readonly property bool connected: status !== "disconnected"
    readonly property bool hasWifi: nm ? wifiDev !== null : fb.wifi !== null
    readonly property bool wifiEnabled: nm ? Networking.wifiEnabled : (fb.wifi !== null && fb.wifi.powered)
    readonly property bool wifiHardware: nm ? (wifiDev !== null && Networking.wifiHardwareEnabled) : (fb.wifi !== null && fb.wifi.hardware)

    property bool busy: false                 // a connection attempt is in flight
    property string pendingSsid: ""
    property string message: ""               // last error, cleared on the next attempt
    property string wiredName: ""             // NM profile name of the wired link ("Wired connection 1")
    property string ip: ""                    // details of the active link for the Settings page (refreshInfo())
    property string gateway: ""
    property string dns: ""

    // [{ssid, signal, secure, active, known, busy, obj}] sorted: active first, then by signal
    readonly property var networks: {
        const best = {}
        if (nm && wifiDev) {
            for (const n of wifiDev.networks.values) {
                if (!n.name) continue
                const e = { ssid: n.name, signal: pct(n.signalStrength), secure: n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe,
                            active: n.connected, known: n.known, busy: n.stateChanging, obj: n }
                const old = best[e.ssid]
                if (!old || e.active || (!old.active && e.signal > old.signal)) best[e.ssid] = e
            }
        } else if (!nm) for (const e of fb.networks) best[e.ssid] = e
        return Object.values(best).sort((x, y) => (y.active - x.active) || (y.signal - x.signal))
    }
    readonly property bool scanning: nm ? (wifiDev !== null && wifiDev.scannerEnabled) : (fb.wifi !== null && fb.wifi.scanning)

    function pct(s) { return Math.round(Math.max(0, Math.min(1, Number(s) || 0)) * 100) }
    function iwctl(args) { Quickshell.execDetached(["iwctl"].concat(args)); quick() }

    // Menus call scan() while they are open; the scanner switches itself off 30 s after the last call.
    function scan(force) {
        if (!hasWifi || !wifiEnabled) return
        if (nm) { wifiDev.scannerEnabled = true; scanStop.restart(); return }
        if (iwd) iwctl(["station", fb.wifi.name, "scan"])
    }
    function refresh() { if (nm) nameProc.running = true; else poll.running = true }
    function refreshInfo() { info.running = false; info.running = true }
    function setWifi(on) {
        if (nm) Networking.wifiEnabled = on
        else if (fb.wifi) iwctl(["device", fb.wifi.name, "set-property", "Powered", on ? "on" : "off"])
    }
    function disconnect() {
        if (nm) {
            if (kind === "wifi" && activeWifi) activeWifi.disconnect()
            else if (activeDevice) activeDevice.disconnect()
        } else if (kind === "wifi" && iwd) iwctl(["station", fb.wifi.name, "disconnect"])
        else if (kind !== "none" && networkd) { Quickshell.execDetached(["networkctl", "down", device]); quick() }
    }
    function find(ssid) { const e = networks.find(n => n.ssid === ssid); return e || null }
    function forget(ssid) {
        const e = find(ssid)
        if (!e || !e.known) return
        if (nm) e.obj.forget()
        else if (iwd) iwctl(["known-networks", ssid, "forget"])
    }
    // Known / open networks connect directly; new secured ones use the PSK (never placed in argv).
    function connectTo(ssid, password) {
        const e = find(ssid)
        if (!e) { message = Strings.t("netGone"); return }
        message = ""
        busy = true
        pendingSsid = ssid
        busyTimeout.restart()
        if (nm) { if (password) e.obj.connectWithPsk(password); else e.obj.connect(); return }
        if (!iwd) return
        // iwctl asks for the passphrase on its terminal: it goes through stdin, never through argv
        joinProc.secret = password || ""
        joinProc.environment = ({ NET_DEV: fb.wifi.name, NET_SSID: ssid })
        joinProc.running = true
        quick()
    }
    function advanced() {
        if (nm) Quickshell.execDetached(["nm-connection-editor"])
        else Quickshell.execDetached(["sh", "-c", iwd ? "command -v iwgtk >/dev/null && exec iwgtk || exec ${TERMINAL:-ghostty} -e iwctl"
                                                      : "exec ${TERMINAL:-ghostty} -e sh -c 'networkctl status; exec ${SHELL:-sh}'"])
    }

    Timer { id: scanStop; interval: 30000; onTriggered: if (root.wifiDev) root.wifiDev.scannerEnabled = false }
    Timer { id: busyTimeout; interval: 45000; onTriggered: { if (root.busy) { root.busy = false; root.message = Strings.t("netTimeout") } } }

    // connection result: success when the network reports connected, failure through connectionFailed
    Instantiator {
        model: root.nm && root.wifiDev ? root.wifiDev.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                if (modelData.name !== root.pendingSsid) return
                root.busy = false
                busyTimeout.stop()
                root.message = Strings.t("netFail") + ": " + ConnectionFailReason.toString(reason)
            }
            function onConnectedChanged() {
                if (modelData.connected && modelData.name === root.pendingSsid) { root.busy = false; busyTimeout.stop(); root.pendingSsid = "" }
            }
        }
    }

    // the wired profile name is not exposed by the native backend: one nmcli read when the link changes
    // (deferred: the process commands bind to the new device, which may not have been re-evaluated yet)
    onKindChanged: Qt.callLater(() => { if (nm && kind === "wired") refresh(); refreshInfo() })
    Process {
        id: nameProc
        command: ["nmcli", "-t", "-g", "GENERAL.CONNECTION", "device", "show", root.wired ? root.wired.name : "lo"]
        stdout: StdioCollector { onStreamFinished: root.wiredName = text.trim() }
    }

    // ── backend detection (cheap; also catches a backend started / stopped later) ──
    Process {
        id: detect
        command: ["systemctl", "is-active", "NetworkManager", "iwd", "systemd-networkd", "systemd-resolved"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = ["NetworkManager", "iwd", "systemd-networkd", "systemd-resolved"], l = text.split("\n"), s = {}
                names.forEach((n, i) => s[n] = (l[i] || "").trim() === "active")
                if (JSON.stringify(s) !== JSON.stringify(root.services)) root.services = s
            }
        }
    }
    Timer { interval: 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: detect.running = true }

    // ── fallback poll ──
    property bool fast: false
    function quick() { fast = true; fastOff.restart(); pollTimer.restart() }
    Timer { id: fastOff; interval: 30000; onTriggered: root.fast = false }
    Timer {
        id: pollTimer
        interval: root.fast || root.busy ? 2500 : 10000
        repeat: true; triggeredOnStart: true
        running: !root.nm
        onTriggered: if (!poll.running) poll.running = true
    }
    onIwdChanged: if (!nm) poll.running = true
    Process {
        id: poll
        command: ["sh", "-c", `
            echo @links; for i in /sys/class/net/*; do [ -e "$i/device" ] || continue; [ -d "$i/wireless" ] && echo "w \${i##*/}" || echo "e \${i##*/}"; done
            printf '@addr\\n%s\\n@route\\n%s\\n' "$(ip -j addr 2>/dev/null)" "$(ip -j route show default 2>/dev/null)"
            [ "$1" = 1 ] || exit 0
            printf '@iwd\\n%s\\n' "$(busctl --system --json=short call net.connman.iwd / org.freedesktop.DBus.ObjectManager GetManagedObjects 2>/dev/null)"
            for p in $(busctl --system --list tree net.connman.iwd 2>/dev/null | grep -E '^/net/connman/iwd/[0-9]+/[0-9]+$'); do
                printf '@ordered %s\\n%s\\n' "$p" "$(busctl --system --json=short call net.connman.iwd "$p" net.connman.iwd.Station GetOrderedNetworks 2>/dev/null)"
            done`, "sh", root.iwd ? "1" : "0"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    function parse(text) {
        const sec = {}, ordered = {}
        for (const chunk of text.split(/^@/m)) {
            const nl = chunk.indexOf("\n")
            if (nl < 0) continue
            const head = chunk.slice(0, nl).trim(), body = chunk.slice(nl + 1).trim()
            if (head.startsWith("ordered ")) ordered[head.slice(8)] = body
            else sec[head] = body
        }
        const json = s => { try { return s ? JSON.parse(s) : null } catch (e) { return null } }
        const v = x => x !== null && typeof x === "object" && "data" in x ? x.data : x     // busctl variant
        const links = (sec.links || "").split("\n").map(l => l.split(" ")).filter(p => p.length === 2)
        const up = {}
        for (const a of json(sec.addr) || [])
            up[a.ifname] = a.operstate === "UP" && (a.addr_info || []).some(x => x.scope === "global")
        const online = (json(sec.route) || []).length > 0

        // iwd: the first station-mode device, its networks and their signal (dBm × 100)
        let wifi = null, nets = [], st = null
        const om = (json(sec.iwd) || { data: [null] }).data[0]
        if (om) for (const path in om) {
            const dev = om[path]["net.connman.iwd.Device"]
            if (!dev) continue
            const ad = om[v(dev.Adapter)] ? om[v(dev.Adapter)]["net.connman.iwd.Adapter"] : null
            const s = om[path]["net.connman.iwd.Station"]
            st = s ? { state: v(s.State), net: v(s.ConnectedNetwork) || "" } : null
            wifi = { path: path, name: v(dev.Name), powered: v(dev.Powered) === true, hardware: !ad || v(ad.Powered) === true,
                     scanning: s ? v(s.Scanning) === true : false }
            break
        }
        if (wifi) {
            const sig = {}
            const ord = json(ordered[wifi.path])
            if (ord && ord.data) for (const p of ord.data[0]) sig[p[0]] = p[1]
            for (const path in om) {
                const n = om[path]["net.connman.iwd.Network"]
                if (!n || v(n.Device) !== wifi.path || !v(n.Name)) continue
                const known = v(n.KnownNetwork) || ""
                nets.push({ ssid: v(n.Name), signal: path in sig ? Math.round(Math.max(0, Math.min(100, 2 * (sig[path] / 100 + 100)))) : 0,
                            secure: v(n.Type) !== "open", active: v(n.Connected) === true, known: known !== "" && known !== "/",
                            busy: st !== null && st.state === "connecting" && st.net === path, obj: null })
            }
        }
        const activeNet = nets.find(n => n.active) || null
        const wired = links.find(p => p[0] === "e" && up[p[1]]) || null
        const wlan = wifi ? wifi.name : (links.find(p => p[0] === "w" && up[p[1]]) || [null, ""])[1]
        const wifiUp = wifi ? (st !== null && st.state === "connected") : wlan !== ""
        const k = wired ? "wired" : wifiUp ? "wifi" : "none"
        fb = { kind: k, device: k === "wired" ? wired[1] : k === "wifi" ? wlan : "",
               connection: k === "wired" ? wired[1] : k === "wifi" ? (activeNet ? activeNet.ssid : wlan) : "",
               signal: k === "wifi" && activeNet ? activeNet.signal : 0, online: online, wifi: wifi, networks: nets }
        if (busy && activeNet && activeNet.ssid === pendingSsid) { busy = false; busyTimeout.stop(); pendingSsid = "" }
    }

    // iwd connect: a pty so iwctl prompts for the passphrase, answered through stdin
    Process {
        id: joinProc
        property string secret: ""
        property string out: ""
        stdinEnabled: true
        command: ["script", "-qfec", "iwctl station \"$NET_DEV\" connect \"$NET_SSID\"", "/dev/null"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: d => {
                joinProc.out += d.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "")
                if (/Passphrase:\s*$/.test(joinProc.out)) {
                    joinProc.write(joinProc.secret + "\n")
                    joinProc.secret = ""
                    joinProc.out = ""
                }
            }
        }
        onStarted: out = ""
        onExited: code => {
            const err = out.split(/[\r\n]+/).map(l => l.trim()).filter(l => l && !/^\*+$/.test(l)).pop() || ""
            secret = ""; out = ""
            if (code !== 0 && root.busy) { root.busy = false; busyTimeout.stop(); root.message = Strings.t("netFail") + (err ? ": " + err : "") }
            root.quick()
        }
    }

    // ── details of the active link (Settings page): address, gateway, DNS ──
    Process {
        id: info
        command: ["sh", "-c", `
            dev="$1"
            printf 'A%s\\nR%s\\n' "$(ip -j addr show dev "$dev" 2>/dev/null)" "$(ip -j route show default dev "$dev" 2>/dev/null)"
            if [ "$2" = 1 ]; then
                d=$(resolvectl dns "$dev" 2>/dev/null | sed 's/^[^:]*: *//')
                [ -n "$d" ] || d=$(resolvectl dns 2>/dev/null | sed -n 's/^Global: *//p')
            else d=$(awk '/^nameserver/{printf "%s ", $2}' /etc/resolv.conf 2>/dev/null); fi
            printf 'D%s\\n' "$d"`, "sh", root.device || "lo", root.resolved ? "1" : "0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const get = c => (text.split("\n").find(l => l[0] === c) || c).slice(1)
                const json = s => { try { return JSON.parse(s) } catch (e) { return [] } }
                const a = (json(get("A"))[0] || {}).addr_info || []
                const v4 = a.find(x => x.family === "inet") || a.find(x => x.scope === "global")
                root.ip = root.device && v4 ? v4.local + "/" + v4.prefixlen : ""
                root.gateway = (json(get("R"))[0] || {}).gateway || ""
                root.dns = get("D").trim()
            }
        }
    }
}
