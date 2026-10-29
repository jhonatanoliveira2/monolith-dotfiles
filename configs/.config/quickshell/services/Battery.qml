pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../core"

// Laptop battery and power policy, shared by the bar button, the power menu and Settings > Power.
//  - "on AC" comes from UPower.onBattery: a battery that is full or held at a charge limit is plugged in,
//    not discharging (its state is FullyCharged / PendingCharge, never Charging)
//  - draw in W and time left: UPower's estimate when it has one, energy / rate otherwise
//  - low-battery alerts and an optional action at the critical level (after a 60 s warning)
//  - automatic power profile (power-profiles-daemon): power saver on battery, the chosen one on AC
//  - battery saver: blur, shadows and animations off while unplugged; plugging in runs `hyprctl reload`,
//    which restores the config and Sys reapplies the Settings choices
//  - charge limit (charge_control_end_threshold), written through pkexec and kept by a udev rule
Singleton {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property var bat: UPower.devices.values.find(d => d.isLaptopBattery) || dev
    readonly property bool present: dev !== null && dev !== undefined && dev.isPresent && dev.isLaptopBattery
    readonly property real pct: present ? (dev.percentage > 1 ? dev.percentage : dev.percentage * 100) : 0
    readonly property bool onAc: present && !UPower.onBattery
    readonly property bool charging: present && dev.state === UPowerDeviceState.Charging
    readonly property bool full: present && dev.state === UPowerDeviceState.FullyCharged
    readonly property bool low: present && !onAc && pct <= 20
    readonly property real watts: present ? (Math.abs(dev.changeRate) || (bat ? Math.abs(bat.changeRate) : 0)) : 0
    // seconds until empty (on battery) or full (charging); 0 when unknown
    readonly property int timeLeft: {
        if (!present) return 0
        if (!onAc) return dev.timeToEmpty > 0 ? dev.timeToEmpty : watts > 0.1 ? Math.round(dev.energy / watts * 3600) : 0
        if (!charging) return 0
        return dev.timeToFull > 0 ? dev.timeToFull : watts > 0.1 ? Math.round(Math.max(0, dev.energyCapacity - dev.energy) / watts * 3600) : 0
    }
    readonly property real health: bat && bat.healthSupported ? bat.healthPercentage : 0
    readonly property bool saverActive: present && !onAc && Settings.batterySaver
    property bool saverApplied: false
    property string limitFile: ""             // charge_control_end_threshold of the first battery ("" = unsupported)
    property int limit: 0
    property int warned: 101                  // lowest alert level already shown in this discharge

    function span(s) {
        if (!s || s <= 0) return ""
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60)
        return (h > 0 ? h + "h " : "") + m + "min"
    }
    function stateText() {
        if (!present) return ""
        return charging ? Strings.t("charging") : full ? Strings.t("batFull") : onAc ? Strings.t("batHeld") : Strings.t("discharging")
    }
    // "2h 10min left  ·  8.4 W"
    function detailText() {
        const t = span(timeLeft)
        return [t ? t + " " + Strings.t(onAc ? "batUntilFull" : "batLeft") : "", watts > 0.05 ? watts.toFixed(1) + " W" : ""].filter(x => x).join("  ·  ")
    }

    // ── alerts ──
    onPctChanged: check()
    onOnAcChanged: { if (onAc) { warned = 101; critical.stop() } else check(); profile() }
    function check() {
        if (!present || onAc || !Settings.batteryAlerts) return
        const level = pct <= 5 ? 5 : pct <= 10 ? 10 : pct <= 20 ? 20 : 101
        if (level >= warned) return
        warned = level
        if (level === 5 && Settings.criticalAction !== "none") {
            Notifs.toast(Strings.t("batCritical"), Strings.t("batAction_" + Settings.criticalAction))
            critical.restart()
        } else Notifs.toast(level === 5 ? Strings.t("batCritical") : Strings.t("batLow"), Math.round(pct) + "%  ·  " + detailText())
    }
    Timer {
        id: critical
        interval: 60000
        onTriggered: {
            if (root.onAc || !root.present) return
            const a = Settings.criticalAction
            if (a === "suspend" || a === "hibernate" || a === "poweroff") Quickshell.execDetached(["systemctl", a])
        }
    }

    // ── automatic power profile ──
    function profile() {
        if (!present || Settings.autoProfile === "off") return
        PowerProfiles.profile = !onAc ? PowerProfile.PowerSaver
            : Settings.autoProfile === "performance" && PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.Balanced
    }

    // ── battery saver ──
    onSaverActiveChanged: {
        if (saverActive) applySaver()
        else if (saverApplied) { saverApplied = false; Quickshell.execDetached(["hyprctl", "reload"]) }
    }
    function applySaver() {
        saverProc.command = Config.hyprEval.concat(["hl.config(" + Sys.luaTable(Sys.flatOf({ blur: 0, shadow: 0, animations: 0, wobble: 0 }), false) + ")"])
        saverProc.running = true
        saverApplied = true
    }
    Process { id: saverProc }
    // a reload drops runtime changes; put the saver back after Sys has reapplied the Settings choices
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded" && root.saverActive) saverAgain.restart() }
    }
    Timer { id: saverAgain; interval: 700; onTriggered: if (root.saverActive) root.applySaver() }
    Connections {
        target: Settings
        function onLoadedOnce() { startup.start() }
    }
    Timer { id: startup; interval: 1500; onTriggered: { if (root.saverActive) root.applySaver(); root.profile(); root.check() } }

    // ── charge limit ──
    Process {
        id: limitRead
        running: true
        command: ["sh", "-c", "for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do [ -r \"$f\" ] && { echo \"$f\"; cat \"$f\"; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: { const l = text.split("\n"); root.limitFile = (l[0] || "").trim(); root.limit = parseInt(l[1]) || 0 }
        }
    }
    // the start threshold (ThinkPads & co.) must stay below the end one, so it is lowered first when needed
    function setLimit(n) {
        limitWrite.command = ["pkexec", "sh", "-c", `
            n="$1"
            for b in /sys/class/power_supply/BAT*; do
                e="$b/charge_control_end_threshold"; s="$b/charge_control_start_threshold"
                [ -w "$e" ] || continue
                if [ -w "$s" ] && [ "$(cat "$s")" -ge "$n" ]; then echo $((n - 5)) > "$s"; fi
                echo "$n" > "$e"
            done
            r=/etc/udev/rules.d/99-monolith-charge-limit.rules
            if [ "$n" -ge 100 ]; then rm -f "$r"
            else printf 'SUBSYSTEM=="power_supply", KERNEL=="BAT*", ATTR{charge_control_end_threshold}="%s"\\n' "$n" > "$r"; fi`, "sh", String(Math.round(n))]
        limitWrite.running = true
    }
    Process { id: limitWrite; onExited: limitRead.running = true }
}
