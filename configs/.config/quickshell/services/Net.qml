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
// Without NetworkManager the state is event driven: `ip monitor` (rtnetlink: links, addresses, routes) and
// `gdbus monitor` on iwd's signals trigger a re-read (debounced); a slow poll is only a safety net.
// Backends are found by their D-Bus names (any init system, not only systemd). Every command goes through
// Jobs (exit code, error output, timeout): failures reach `message` and the log instead of vanishing.
// Wi-Fi scanning only runs while a menu that lists networks is open (see scan()).
Singleton {
    id: root

    // ── backend ──
    readonly property bool nm: Networking.backend === NetworkBackendType.NetworkManager
    property var services: ({})               // D-Bus names present: iwd, networkd, resolved
    readonly property bool iwd: !nm && services["iwd"] === true
    readonly property bool networkd: services["networkd"] === true
    readonly property bool resolved: services["resolved"] === true
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

    // ── fallback state (iwd / networkd / plain links), filled by refresh() ──
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
    property var pending: null                // NetworkManager: the network being connected
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
    function clean(s) { return Jobs.firstLine(String(s || "").replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "")) }
    // a command for the fallback backends: errors become `message`, the state is re-read either way
    function exec(cmd, quiet) {
        Jobs.run("net", cmd, { timeout: 15000 }, (ok, out, err) => {
            if (!ok && !(quiet && quiet.test(err + out))) root.message = Strings.t("netOpFail") + ": " + (root.clean(err) || root.clean(out) || cmd[0])
            root.kick()
        })
    }
    function iwctl(args, quiet) { exec(["iwctl"].concat(args), quiet) }

    // Menus call scan() while they are open; the scanner switches itself off 30 s after the last call.
    // force: a fresh scan now (the menu's refresh button), not only the periodic one.
    function scan(force) {
        if (!hasWifi || !wifiEnabled) return
        if (nm) {
            if (force && wifiDev.scannerEnabled) { wifiDev.scannerEnabled = false; Qt.callLater(() => { if (root.wifiDev) root.wifiDev.scannerEnabled = true }) }
            else wifiDev.scannerEnabled = true
            scanStop.restart()
            return
        }
        if (iwd) iwctl(["station", fb.wifi.name, "scan"], /in progress|busy/i)
    }
    function refresh() { if (nm) readWiredName(); else if (!poll.running) poll.running = true }
    function refreshInfo() { info.running = false; info.running = true }
    function setWifi(on) {
        message = ""
        if (nm) Networking.wifiEnabled = on
        else if (fb.wifi) iwctl(["device", fb.wifi.name, "set-property", "Powered", on ? "on" : "off"])
    }
    function disconnect() {
        message = ""
        if (busy) { cancel(); return }
        if (nm) {
            if (kind === "wifi" && activeWifi) activeWifi.disconnect()
            else if (activeDevice) activeDevice.disconnect()
        } else if (kind === "wifi" && iwd) iwctl(["station", fb.wifi.name, "disconnect"])
        else if (kind !== "none" && networkd) exec(["networkctl", "down", device])
    }
    function find(ssid) { const e = networks.find(n => n.ssid === ssid); return e || null }
    function forget(ssid) {
        const e = find(ssid)
        if (!e || !e.known) return
        message = ""
        if (nm) e.obj.forget()
        else if (iwd) iwctl(["known-networks", ssid, "forget"])
    }
    // Known / open networks connect directly; new secured ones use the PSK (never placed in argv).
    // A new attempt (or disconnect()) cancels the one in flight.
    function connectTo(ssid, password) {
        if (busy) cancel(true)
        const e = find(ssid)
        if (!e) { message = Strings.t("netGone"); return }
        message = ""
        busy = true
        pendingSsid = ssid
        busyTimeout.restart()
        if (nm) {
            pending = e.obj
            if (password) e.obj.connectWithPsk(password); else e.obj.connect()
            return
        }
        if (!iwd) { busy = false; return }
        // iwctl asks for the passphrase on its terminal: it goes through stdin, never through argv
        joinProc.secret = password || ""
        joinProc.environment = ({ NET_DEV: fb.wifi.name, NET_SSID: ssid })
        joinProc.running = true
    }
    // stop the attempt in flight; `silent` when a new attempt replaces it
    function cancel(silent) {
        if (!busy) return
        console.log("[net] canceling the connection to", pendingSsid)
        if (nm && pending) pending.disconnect()
        if (joinProc.running) {
            joinProc.running = false
            if (fb.wifi) iwctl(["station", fb.wifi.name, "disconnect"])
        }
        done(silent ? "" : Strings.t("netCanceled"))
    }
    // end of an attempt: "" = success, otherwise the message to show
    function done(msg) {
        busy = false
        busyTimeout.stop()
        pending = null
        pendingSsid = ""
        if (msg) { message = msg; console.warn("[net]", msg) }
        else if (nm && Networking.canCheckConnectivity) Networking.checkConnectivity()
    }
    function advanced() {
        // a GUI that keeps running: started detached, but a missing program is still reported
        const cmd = nm ? "exec nm-connection-editor"
            : iwd ? "command -v iwgtk >/dev/null && exec iwgtk || exec ${TERMINAL:-ghostty} -e iwctl"
            : "exec ${TERMINAL:-ghostty} -e sh -c 'networkctl status; exec ${SHELL:-sh}'"
        const needs = nm ? "nm-connection-editor" : iwd ? "iwctl" : "networkctl"
        exec(["sh", "-c", 'command -v "$2" >/dev/null || { echo "$2 is not installed" >&2; exit 127; }; setsid -f sh -c "$1" >/dev/null 2>&1', "sh", cmd, needs])
    }

    Timer { id: scanStop; interval: 30000; onTriggered: if (root.wifiDev) root.wifiDev.scannerEnabled = false }
    // NetworkManager gives up on its own after ~25-45 s; past 30 s the attempt is canceled and reported
    Timer {
        id: busyTimeout
        interval: 30000
        onTriggered: {
            if (!root.busy) return
            if (root.nm && root.pending) root.pending.disconnect()
            if (joinProc.running) joinProc.running = false
            root.done(Strings.t("netTimeout"))
        }
    }

    // ── NetworkManager: result of the attempt ──
    function reason(r) {
        const s = ConnectionFailReason.toString(r)
        return /secret|auth|supplicant|psk|key/i.test(s) ? Strings.t("netAuth") + " (" + s + ")" : s
    }
    Connections {
        target: root.pending
        ignoreUnknownSignals: true
        function onConnectionFailed(r) { root.done(Strings.t("netFail") + ": " + root.reason(r)) }
        function onConnectedChanged() { if (root.pending && root.pending.connected) root.done("") }
    }
    // the network object can be replaced by a rescan while connecting: the active one counts too
    onActiveWifiChanged: if (busy && nm && activeWifi && activeWifi.name === pendingSsid) done("")

    // the wired profile name is not exposed by the native backend: one nmcli read when the link changes
    // (deferred: the device bindings may not have been re-evaluated yet)
    onKindChanged: Qt.callLater(() => {
        if (nm && kind === "wired") readWiredName()
        if (nm && kind !== "none" && Networking.canCheckConnectivity) Networking.checkConnectivity()
        refreshInfo()
    })
    function readWiredName() {
        if (!wired) return
        Jobs.run("net", ["nmcli", "-t", "-g", "GENERAL.CONNECTION", "device", "show", wired.name], { timeout: 5000 },
                 (ok, out) => { if (ok) root.wiredName = out.trim() })
    }

    // ── backend detection: D-Bus names (any init system); without NetworkManager also every 60 s ──
    function detect() {
        Jobs.run("net", ["gdbus", "call", "--system", "--dest", "org.freedesktop.DBus", "--object-path", "/org/freedesktop/DBus",
                         "--method", "org.freedesktop.DBus.ListNames"], { timeout: 5000 }, (ok, out) => {
            if (!ok) return
            const has = n => out.indexOf("'" + n + "'") >= 0
            const s = { iwd: has("net.connman.iwd"), networkd: has("org.freedesktop.network1"), resolved: has("org.freedesktop.resolve1") }
            if (JSON.stringify(s) !== JSON.stringify(root.services)) {
                console.log("[net] backend:", root.nm ? "NetworkManager" : "", JSON.stringify(s))
                root.services = s
            }
        })
    }
    Component.onCompleted: detect()
    Timer { interval: 60000; repeat: true; running: !root.nm; onTriggered: root.detect() }

    // ── fallback (no NetworkManager): events trigger a re-read; a slow poll is the safety net ──
    function kick() { if (!nm) debounce.restart() }
    Timer { id: debounce; interval: 250; onTriggered: if (!poll.running) poll.running = true; else root.again = true }
    property bool again: false                // an event arrived while reading: read once more
    Timer {
        id: pollTimer
        interval: root.busy ? 3000 : 60000
        repeat: true; triggeredOnStart: true
        running: !root.nm
        onTriggered: if (!poll.running) poll.running = true
    }
    onIwdChanged: kick()
    // event sources (services/EventStream.qml): restarted after a pause if they exit, with the reason logged
    EventStream { label: "ip monitor"; wanted: !root.nm; command: ["ip", "-o", "monitor", "link", "address", "route"]; onEvent: root.kick() }
    EventStream { label: "gdbus monitor (iwd)"; wanted: root.iwd; command: ["gdbus", "monitor", "--system", "--dest", "net.connman.iwd"]; onEvent: root.kick() }

    Process {
        id: poll
        command: ["sh", "-c", `
            echo @links; for i in /sys/class/net/*; do [ -e "$i/device" ] || continue; [ -d "$i/wireless" ] && echo "w \${i##*/}" || echo "e \${i##*/}"; done
            printf '@addr\\n%s\\n@route\\n%s\\n' "$(ip -j addr 2>/dev/null)" "$(ip -j route show default 2>/dev/null)"
            [ "$1" = 1 ] || exit 0
            command -v busctl >/dev/null || { echo @nobusctl; exit 0; }
            printf '@iwd\\n%s\\n' "$(busctl --system --json=short call net.connman.iwd / org.freedesktop.DBus.ObjectManager GetManagedObjects 2>&1)"
            for p in $(busctl --system --list tree net.connman.iwd 2>/dev/null | grep -E '^/net/connman/iwd/[0-9]+/[0-9]+$'); do
                printf '@ordered %s\\n%s\\n' "$p" "$(busctl --system --json=short call net.connman.iwd "$p" net.connman.iwd.Station GetOrderedNetworks 2>/dev/null)"
            done`, "sh", root.iwd ? "1" : "0"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        onExited: if (root.again) { root.again = false; debounce.restart() }
    }
    property bool warned: false               // a broken iwd read is reported once, not every poll
    function parse(text) {
        const sec = {}, ordered = {}
        for (const chunk of text.split(/^@/m)) {
            const nl = chunk.indexOf("\n")
            const head = (nl < 0 ? chunk : chunk.slice(0, nl)).trim(), body = nl < 0 ? "" : chunk.slice(nl + 1).trim()
            if (head.startsWith("ordered ")) ordered[head.slice(8)] = body
            else if (head) sec[head] = body
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
        const iwdObj = json(sec.iwd)
        if (iwd && !warned && ("nobusctl" in sec || (sec.iwd && !iwdObj))) {
            warned = true
            const why = "nobusctl" in sec ? "busctl not found (systemd): iwd's state cannot be read" : clean(sec.iwd)
            console.warn("[net] iwd:", why)
            message = Strings.t("netOpFail") + ": " + why
        }
        const om = (iwdObj || { data: [null] }).data[0]
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
        if (busy && activeNet && activeNet.ssid === pendingSsid) done("")
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
            if (code !== 0 && root.busy) root.done(Strings.t("netFail") + (err ? ": " + err : " (iwctl exit " + code + ")"))
            root.kick()
        }
    }

    // ── details of the active link (Settings page): address, gateway, DNS ──
    Process {
        id: info
        command: ["sh", "-c", `
            dev="$1"
            printf 'A%s\\nR%s\\n' "$(ip -j addr show dev "$dev" 2>/dev/null)" "$(ip -j route show default dev "$dev" 2>/dev/null)"
            if [ "$2" = 1 ] && command -v resolvectl >/dev/null; then
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
