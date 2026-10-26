pragma Singleton
import QtQuick
import "../core"
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// NetworkManager through Quickshell's native D-Bus backend (Quickshell.Networking): no nmcli processes,
// no polling. Device, network and connectivity changes arrive as D-Bus signals.
// Wi-Fi scanning only runs while a menu that lists networks is open (see scan()).
Singleton {
    id: root

    readonly property bool available: Networking.backend === NetworkBackendType.NetworkManager
    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected)
        || devices.find(d => d.type === DeviceType.Wired) || null
    readonly property var wifiDev: devices.find(d => d.type === DeviceType.Wifi) || null
    readonly property var activeWifi: wifiDev ? (wifiDev.networks.values.find(n => n.connected) || null) : null

    // ── summary used by the bar / menus ──
    readonly property string kind: wired && wired.connected ? "wired" : activeWifi ? "wifi" : "none"
    readonly property var activeDevice: kind === "wired" ? wired : kind === "wifi" ? wifiDev : null
    readonly property string device: activeDevice ? activeDevice.name : ""
    readonly property string connection: kind === "wifi" ? activeWifi.name : kind === "wired" ? (wiredName || wired.name) : ""
    readonly property int signal: activeWifi ? pct(activeWifi.signalStrength) : 0
    readonly property string status: kind === "none" ? "disconnected"
        : (Networking.connectivity === NetworkConnectivity.Full || Networking.connectivity === NetworkConnectivity.Unknown) ? "online" : "nointernet"
    readonly property bool connected: status !== "disconnected"
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardware: wifiDev !== null && Networking.wifiHardwareEnabled
    readonly property bool hasWifi: wifiDev !== null

    property bool busy: false                 // a connection attempt is in flight
    property string pendingSsid: ""
    property string message: ""               // last error, cleared on the next attempt
    property string wiredName: ""             // NM profile name of the wired link ("Wired connection 1")

    // [{ssid, signal, secure, active, known, busy, obj}] sorted: active first, then by signal
    readonly property var networks: {
        if (!wifiDev) return []
        const best = {}
        for (const n of wifiDev.networks.values) {
            if (!n.name) continue
            const e = { ssid: n.name, signal: pct(n.signalStrength), secure: n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe,
                        active: n.connected, known: n.known, busy: n.stateChanging, obj: n }
            const old = best[e.ssid]
            if (!old || e.active || (!old.active && e.signal > old.signal)) best[e.ssid] = e
        }
        return Object.values(best).sort((x, y) => (y.active - x.active) || (y.signal - x.signal))
    }
    readonly property bool scanning: wifiDev !== null && wifiDev.scannerEnabled

    function pct(s) { return Math.round(Math.max(0, Math.min(1, Number(s) || 0)) * 100) }

    // Menus call scan() while they are open; the scanner switches itself off 30 s after the last call.
    function scan(force) {
        if (!wifiDev || !wifiEnabled) return
        wifiDev.scannerEnabled = true
        scanStop.restart()
    }
    function refresh() { nameProc.running = true }
    function setWifi(on) { Networking.wifiEnabled = on }
    function disconnect() {
        if (kind === "wifi" && activeWifi) activeWifi.disconnect()
        else if (activeDevice) activeDevice.disconnect()
    }
    function find(ssid) { const e = networks.find(n => n.ssid === ssid); return e ? e.obj : null }
    function forget(ssid) { const n = find(ssid); if (n && n.known) n.forget() }
    // Known / open networks connect directly; new secured ones use the PSK (never placed in argv).
    function connectTo(ssid, password) {
        const n = find(ssid)
        if (!n) { message = Strings.t("netGone"); return }
        message = ""
        busy = true
        pendingSsid = ssid
        if (password) n.connectWithPsk(password)
        else n.connect()
        busyTimeout.restart()
    }

    Timer { id: scanStop; interval: 30000; onTriggered: if (root.wifiDev) root.wifiDev.scannerEnabled = false }
    Timer { id: busyTimeout; interval: 45000; onTriggered: { if (root.busy) { root.busy = false; root.message = Strings.t("netTimeout") } } }

    // connection result: success when the network reports connected, failure through connectionFailed
    Instantiator {
        model: root.wifiDev ? root.wifiDev.networks : null
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
    onKindChanged: if (kind === "wired") refresh()
    Process {
        id: nameProc
        command: ["nmcli", "-t", "-g", "GENERAL.CONNECTION", "device", "show", root.wired ? root.wired.name : "lo"]
        stdout: StdioCollector { onStreamFinished: root.wiredName = text.trim() }
    }
}
