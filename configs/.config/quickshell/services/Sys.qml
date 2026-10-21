pragma Singleton
import QtQuick
import "../core"
import Quickshell
import Quickshell.Io

// Desktop-level controls: Hyprland runtime options, GTK dark mode and session actions.
Singleton {
    id: root

    // key -> Hyprland option
    readonly property var options: ({
        gapsIn: "general:gaps_in",
        gapsOut: "general:gaps_out",
        borderSize: "general:border_size",
        rounding: "decoration:rounding",
        animations: "animations:enabled",
        blur: "decoration:blur:enabled",
        shadow: "decoration:shadow:enabled",
        newRenderScheduling: "render:new_render_scheduling"
    })

    property var values: ({})
    property bool darkMode: true

    function parse(json) {
        try {
            const j = JSON.parse(json)
    
            if (j.int !== undefined) return j.int
            if (j.float !== undefined) return Math.round(j.float)
            if (j.bool !== undefined) return j.bool ? 1 : 0
    
            if (j.css !== undefined) {
                const values = String(j.css).trim().split(/\s+/)
                return parseInt(values[0], 10) || 0
            }
    
            if (j.custom !== undefined)
                return parseInt(String(j.custom).split(" ")[0], 10) || 0
    
            if (j.str !== undefined)
                return parseInt(j.str, 10) || 0
        } catch (e) {}
    
        return 0
    }

    function refresh() {
        readProc.running = true
        darkProc.running = true
    }

    // Apply a runtime option through the Lua configuration API.
    function applyValue(key, value) {
        const option = options[key]
        if (!option) return
    
        if (key === "vrr") {
            const mode = Math.max(0, Math.min(3, Number(value)))
            Quickshell.execDetached([
                "hyprctl", "eval",
                "hl.config({ misc = { vrr = " + mode + " } })"
            ])
            return
        }
    
        if (key === "newRenderScheduling") {
            const enabled = Number(value) !== 0
            Quickshell.execDetached([
                "hyprctl", "eval",
                "hl.config({ render = { new_render_scheduling = " + enabled + " } })"
            ])
            return
        }
    
        const path = option.replace(/:/g, ".")
        const boolOptions = ["animations", "blur", "shadow"]
        const formattedValue = boolOptions.includes(key)
            ? (Number(value) !== 0 ? "true" : "false")
            : String(value)
    
        const lua = "hl.config({ [\"" + path + "\"] = " + formattedValue + " })"
        Quickshell.execDetached(["hyprctl", "eval", lua])
    }

    function setValue(key, value) {
        if (!options[key]) return

        values = Object.assign({}, values, { [key]: value })
        Settings[key] = value
        applyValue(key, value)
    }

    function toggle(key) {
        setValue(key, values[key] ? 0 : 1)
    }

    function setDark(on) {
        darkMode = on
        Quickshell.execDetached([
            "gsettings", "set", "org.gnome.desktop.interface",
            "color-scheme", on ? "prefer-dark" : "default"
        ])
    }

    function init() {}
    function run(cmd) { Quickshell.execDetached(cmd) }
    function lock() { run(Config.lockCommand) }
    function logout() { run(Config.logoutCommand) }
    function suspend() { run(["systemctl", "suspend"]) }
    function reboot() { run(["systemctl", "reboot"]) }
    function poweroff() { run(["systemctl", "poweroff"]) }
    function reloadHyprland() { run(["hyprctl", "reload"]) }

    // Read the current Hyprland option values.
    Process {
        id: readProc
        command: [
            "sh", "-c",
            "for o in " + Object.values(root.options).join(" ") +
            "; do printf '%s ' \"$o\"; hyprctl getoption \"$o\" -j | tr -d '\\n'; echo; done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const v = Object.assign({}, root.values)

                for (const line of text.split("\n")) {
                    const i = line.indexOf(" ")
                    if (i < 0) continue

                    const opt = line.slice(0, i)
                    for (const k in root.options) {
                        if (root.options[k] === opt)
                            v[k] = root.parse(line.slice(i + 1))
                    }
                }

                root.values = v
            }
        }
    }

    Process {
        id: darkProc
        command: [
            "gsettings", "get",
            "org.gnome.desktop.interface", "color-scheme"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.darkMode = text.indexOf("dark") >= 0
        }
    }

    // Re-apply saved overrides (-1 means untouched by the menu).
    Timer {
        id: applyOverrides
        interval: 1500
        running: true

        onTriggered: {
            for (const k in root.options) {
                const v = Settings[k]
                if (v !== undefined && v >= 0)
                    root.applyValue(k, v)
            }
        }
    }
}
