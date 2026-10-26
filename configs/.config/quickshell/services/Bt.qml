pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../core"

// BlueZ through Quickshell's native D-Bus backend (Quickshell.Bluetooth). Shared by the bar button,
// the menu and the Settings page: sorting, pair -> trust -> connect, discovery that stops by itself,
// and a short error line when an operation does not complete.
//
// Pairing agent: Quickshell.Bluetooth does not register an org.bluez.Agent1, and without one BlueZ
// rejects every pairing that needs a confirmation, passkey or PIN ("Authentication Rejected"; Blueman
// works because blueman-applet registers its own). A persistent bluetoothctl is registered as the
// default agent (under a pty from script(1): its agent prompts only run in an interactive shell). Its
// prompts become `request`, answered with reply(); it also retries a failed pairing by itself.
Singleton {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null && adapter !== undefined
    readonly property bool enabled: present && adapter.enabled
    readonly property bool blocked: present && adapter.state === BluetoothAdapterState.Blocked
    // what the user asked for: BlueZ may report Discovering=false for a moment right after
    // StartDiscovery (or drop it while the controller settles), so the UI follows the request
    property bool wantScan: false
    property int scanRetries: 0
    readonly property bool discovering: present && enabled && (wantScan || adapter.discovering)
    readonly property bool anyConnected: devices.some(d => d.connected)
    // nameless devices (only an address) are noise while scanning: keep them only when paired
    readonly property var devices: Bluetooth.devices.values
        .filter(d => d.paired || d.connected || (d.name && d.name !== d.address.replace(/:/g, "-")))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || String(a.name).localeCompare(String(b.name)))
    property string message: ""
    property var target: null                 // device of the operation being watched
    property bool retried: false              // the target's pairing was already retried through bluetoothctl

    // ── agent state ──
    property bool agentReady: false           // bluetoothctl is the default agent
    // {kind: "confirm" | "passkey" | "pin" | "display" | "authorize" | "service", code, device}
    property var request: null
    property string agentBuf: ""

    function setEnabled(on) {
        if (!present) return
        if (blocked && on) { Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]); return }
        adapter.enabled = on
    }
    // Discovery costs power and radio time: it stops 60 s after the last request.
    function scan(on) {
        if (!enabled) return
        wantScan = on
        scanRetries = 0
        retryScan.stop()
        adapter.discovering = on
        if (on) stopScan.restart(); else stopScan.stop()
    }

    function status(d) {
        if (d.pairing) return Strings.t("pairing")
        if (d.state === BluetoothDeviceState.Connecting) return Strings.t("connecting")
        if (d.state === BluetoothDeviceState.Disconnecting) return Strings.t("disconnecting")
        if (d.connected) return Strings.t("connected") + (d.batteryAvailable ? "  ·  " + Math.round(d.battery * 100) + "%" : "")
        return d.paired ? Strings.t("paired") : Strings.t("new")
    }
    function busy(d) { return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting }
    function label(d) { return d ? String(d.name || d.address) : "" }

    // left click: connect / disconnect (pairs new devices first)
    function activate(d) {
        if (!d || busy(d)) return
        message = ""
        target = d
        retried = false
        if (!d.paired) {
            if (!adapter.pairable) adapter.pairable = true
            d.pair()
            watch.restart()
            return
        }
        if (d.connected) d.disconnect()
        else { if (!d.trusted) d.trusted = true; d.connect() }
        watch.restart()
    }
    function forget(d) { if (d && (d.paired || d.trusted)) d.forget() }

    function fail(d) {
        if (d.pairing) d.cancelPair()
        message = Strings.t("btPairFail") + ": " + label(d) + " — " + Strings.t(agentReady ? "btPairHint" : "btNoAgent")
        target = null
        request = null
    }

    // ── agent ──
    function reply(ok, value) {
        const r = request
        if (!r) return
        request = null
        reqTimeout.stop()
        if (r.kind === "display") { if (!ok && target && target.pairing) target.cancelPair(); return }
        if (r.kind === "pin" || r.kind === "passkey") {
            agent.write((ok ? String(value || "").trim() : "") + "\n")
            if (!ok && target && target.pairing) target.cancelPair()
        } else agent.write(ok ? "yes\n" : "no\n")
    }
    function ask(kind, code) {
        if (request && request.kind === kind) return            // readline redraws the same prompt
        const d = target || Bluetooth.devices.values.find(x => x.pairing) || null
        // service / Just Works prompts for an operation started here (or a paired device) answer themselves
        if ((kind === "authorize" || kind === "service") && d && (d === target || d.paired)) { agent.write("yes\n"); return }
        request = { kind: kind, code: code || "", device: label(d) }
        if (kind !== "display") reqTimeout.restart()
        if (target) watch.restart()
        if (Popups.current !== "bluetooth") Popups.toggleFocused("bluetooth")
    }
    // agent prompts wait for input without a line break, so they are matched on the unfinished tail
    function prompt(s) {
        let m
        if ((m = s.match(/Confirm passkey (\d+) \(yes\/no\)/))) ask("confirm", m[1])
        else if (/Enter PIN code:/.test(s)) ask("pin")
        else if (/Enter passkey[^:]*:/.test(s)) ask("passkey")
        else if (/Accept pairing \(yes\/no\)/.test(s)) ask("authorize")
        else if ((m = s.match(/Authorize service (\S+) \(yes\/no\)/))) ask("service", m[1])
        else return false
        return true
    }
    function line(l) {
        let m
        if (/Agent registered/.test(l)) agent.write("default-agent\n")
        else if (/Default agent request successful/.test(l)) agentReady = true
        else if (/Agent unregistered|Agent released|Waiting to connect to bluetoothd/.test(l)) agentReady = false
        else if (/Request canceled/.test(l)) { request = null; reqTimeout.stop() }
        else if ((m = l.match(/(?:^|\] )(?:Passkey|PIN code): (\w+)/))) ask("display", m[1])
        else if (/Failed to pair/.test(l) && target && !target.paired) fail(target)
    }
    function feed(data) {
        const parts = (agentBuf + data.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "")).split(/[\r\n]+/)
        agentBuf = parts.pop()
        for (const l of parts) line(l)
        if (prompt(agentBuf) || agentBuf.length > 4096) agentBuf = ""
    }

    Process {
        id: agent
        stdinEnabled: true
        command: ["script", "-qfec", "bluetoothctl --agent KeyboardDisplay", "/dev/null"]
        stdout: SplitParser { splitMarker: ""; onRead: d => root.feed(d) }
        onExited: { root.agentReady = false; root.request = null; root.agentBuf = ""; agentRestart.restart() }
    }
    // bluetoothctl exits when bluetoothd goes away for good: start it again
    Timer { id: agentRestart; interval: 5000; onTriggered: if (root.present) agent.running = true }
    Component.onCompleted: if (present) agent.running = true
    onPresentChanged: if (present && !agent.running) agent.running = true
    // BlueZ gives up on an unanswered agent request after ~30 s: reject before that
    Timer { id: reqTimeout; interval: 28000; onTriggered: root.reply(false) }

    Timer { id: stopScan; interval: 60000; onTriggered: { root.wantScan = false; if (root.present) root.adapter.discovering = false } }
    // discovery dropped while still wanted: ask again (a few times) instead of making the user click
    Timer {
        id: retryScan
        interval: 500
        onTriggered: {
            if (!root.wantScan || !root.enabled || root.adapter.discovering) return
            if (++root.scanRetries > 6) { root.wantScan = false; stopScan.stop(); return }
            root.adapter.discovering = true
            restart()
        }
    }
    Connections {
        target: root.adapter
        ignoreUnknownSignals: true
        function onDiscoveringChanged() { if (root.wantScan && !root.adapter.discovering) retryScan.restart() }
        function onEnabledChanged() { if (!root.adapter.enabled) { root.wantScan = false; stopScan.stop(); retryScan.stop() } }
    }
    // BlueZ errors are not exposed to QML: report an operation that did not finish in time
    Timer {
        id: watch
        interval: 30000
        onTriggered: {
            const d = root.target
            if (!d) return
            if (!d.connected && !d.paired) { root.fail(d); return }
            if (!d.connected && d.state !== BluetoothDeviceState.Disconnected) root.message = Strings.t("btConnFail") + ": " + root.label(d)
            root.target = null
        }
    }
    // pair() ended without a bond ("Authentication Rejected" and friends): retry once from bluetoothctl,
    // whose own agent then answers the request (covers a caller-agent mismatch and stale controller state)
    Timer {
        id: pairCheck
        interval: 1500
        onTriggered: {
            const d = root.target
            if (!d || d.paired || d.pairing) return
            if (root.retried || !root.agentReady) { root.fail(d); return }
            root.retried = true
            agent.write("pair " + d.address + "\n")
            watch.restart()
        }
    }
    // a freshly paired device is trusted and connected right away
    Connections {
        target: root.target
        ignoreUnknownSignals: true
        function onPairingChanged() { if (root.target && !root.target.pairing && !root.target.paired) pairCheck.restart() }
        function onPairedChanged() {
            const d = root.target
            if (d && d.paired) { pairCheck.stop(); root.request = null; if (!d.connected) { d.trusted = true; d.connect(); watch.restart() } }
        }
        function onConnectedChanged() { if (root.target && root.target.connected) { watch.stop(); root.target = null } }
    }
}
