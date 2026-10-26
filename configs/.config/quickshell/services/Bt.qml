pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../core"

// BlueZ through Quickshell's native D-Bus backend (Quickshell.Bluetooth). Shared by the bar button,
// the menu and the Settings page: sorting, pair -> trust -> connect, discovery that stops by itself,
// and a short error line when an operation does not complete.
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

    // left click: connect / disconnect (pairs new devices first)
    function activate(d) {
        if (!d || busy(d)) return
        message = ""
        target = d
        if (!d.paired) { d.pair(); watch.restart(); return }
        if (d.connected) d.disconnect()
        else { if (!d.trusted) d.trusted = true; d.connect() }
        watch.restart()
    }
    function forget(d) { if (d && (d.paired || d.trusted)) d.forget() }

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
        interval: 20000
        onTriggered: {
            const d = root.target
            if (!d) return
            if (d.pairing) d.cancelPair()
            if (!d.connected && !d.paired) root.message = Strings.t("btPairFail") + ": " + (d.name || d.address)
            else if (!d.connected && d.state !== BluetoothDeviceState.Disconnected) root.message = Strings.t("btConnFail") + ": " + (d.name || d.address)
            root.target = null
        }
    }
    // a freshly paired device is trusted and connected right away
    Connections {
        target: root.target
        ignoreUnknownSignals: true
        function onPairedChanged() {
            const d = root.target
            if (d && d.paired && !d.connected) { d.trusted = true; d.connect(); watch.restart() }
        }
        function onConnectedChanged() { if (root.target && root.target.connected) { watch.stop(); root.target = null } }
    }
}
