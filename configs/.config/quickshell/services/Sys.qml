pragma Singleton
import QtQuick
import "../core"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Desktop-level controls: Hyprland runtime options (through the Lua API), GTK dark mode and session actions.
// `hyprctl keyword` does not work with the Lua config parser: options are written with `hyprctl eval "hl.config{…}"`
// and read back with one batched `hyprctl getoption` call.
// Persistence: Settings.json (re-applied when the shell starts / Hyprland reloads) and
// ~/.config/hypr/generated/settings.lua, which hyprland.lua loads last so the choices hold even without the shell.
Singleton {
    id: root

    // key -> { opt: getoption name, type, min/max (numbers) or choices (strings) }
    // The Lua path is the same name with "." instead of ":". Values outside the range are clamped.
    readonly property var options: ({
        // general
        gapsIn: { opt: "general:gaps_in", type: "int", min: 0, max: 40 },
        gapsOut: { opt: "general:gaps_out", type: "int", min: 0, max: 80 },
        borderSize: { opt: "general:border_size", type: "int", min: 0, max: 10 },
        layout: { opt: "general:layout", type: "str", choices: ["dwindle", "master", "scrolling"] },
        resizeOnBorder: { opt: "general:resize_on_border", type: "bool" },
        allowTearing: { opt: "general:allow_tearing", type: "bool" },
        snap: { opt: "general:snap:enabled", type: "bool" },
        // decoration
        rounding: { opt: "decoration:rounding", type: "int", min: 0, max: 30 },
        roundingPower: { opt: "decoration:rounding_power", type: "float", min: 1, max: 10 },
        activeOpacity: { opt: "decoration:active_opacity", type: "float", min: 0.1, max: 1 },
        inactiveOpacity: { opt: "decoration:inactive_opacity", type: "float", min: 0.1, max: 1 },
        dimInactive: { opt: "decoration:dim_inactive", type: "bool" },
        dimStrength: { opt: "decoration:dim_strength", type: "float", min: 0, max: 1 },
        // blur
        blur: { opt: "decoration:blur:enabled", type: "bool" },
        blurSize: { opt: "decoration:blur:size", type: "int", min: 1, max: 20 },
        blurPasses: { opt: "decoration:blur:passes", type: "int", min: 1, max: 6 },
        blurNoise: { opt: "decoration:blur:noise", type: "float", min: 0, max: 0.2 },
        blurVibrancy: { opt: "decoration:blur:vibrancy", type: "float", min: 0, max: 1 },
        blurXray: { opt: "decoration:blur:xray", type: "bool" },
        blurPopups: { opt: "decoration:blur:popups", type: "bool" },
        // shadow
        shadow: { opt: "decoration:shadow:enabled", type: "bool" },
        shadowRange: { opt: "decoration:shadow:range", type: "int", min: 0, max: 50 },
        shadowPower: { opt: "decoration:shadow:render_power", type: "int", min: 1, max: 4 },
        shadowSharp: { opt: "decoration:shadow:sharp", type: "bool" },
        // animations
        animations: { opt: "animations:enabled", type: "bool" },
        wsWrap: { opt: "animations:workspace_wraparound", type: "bool" },
        // layouts
        preserveSplit: { opt: "dwindle:preserve_split", type: "bool" },
        smartSplit: { opt: "dwindle:smart_split", type: "bool" },
        mfact: { opt: "master:mfact", type: "float", min: 0.1, max: 0.9 },
        newStatus: { opt: "master:new_status", type: "str", choices: ["master", "slave", "inherit"] },
        // behaviour / cursor
        vrr: { opt: "misc:vrr", type: "int", min: 0, max: 3 },
        focusOnActivate: { opt: "misc:focus_on_activate", type: "bool" },
        swallow: { opt: "misc:enable_swallow", type: "bool" },
        middlePaste: { opt: "misc:middle_click_paste", type: "bool" },
        cursorTimeout: { opt: "cursor:inactive_timeout", type: "float", min: 0, max: 30 },
        hideOnKey: { opt: "cursor:hide_on_key_press", type: "bool" },
        noWarps: { opt: "cursor:no_warps", type: "bool" },
        // input
        kbLayout: { opt: "input:kb_layout", type: "str", pattern: /^[a-z]{2,3}(\([a-z0-9_-]+\))?(,[a-z]{2,3}(\([a-z0-9_-]+\))?)*$/ },
        followMouse: { opt: "input:follow_mouse", type: "int", min: 0, max: 3 },
        repeatRate: { opt: "input:repeat_rate", type: "int", min: 1, max: 100 },
        repeatDelay: { opt: "input:repeat_delay", type: "int", min: 100, max: 2000 },
        sensitivity: { opt: "input:sensitivity", type: "float", min: -1, max: 1 },
        naturalMouse: { opt: "input:natural_scroll", type: "bool" },
        naturalTouchpad: { opt: "input:touchpad:natural_scroll", type: "bool" },
        tapToClick: { opt: "input:touchpad:tap-to-click", type: "bool" }
    })
    // keys with their own Settings property (-1 = untouched); the rest is stored in Settings.overrides
    readonly property var persisted: ["gapsIn", "gapsOut", "borderSize", "rounding", "animations", "blur", "shadow"]
    property var values: ({})          // key -> number | string (read from Hyprland when a menu opens)
    property bool darkMode: true
    property string lastError: ""
    readonly property string hyprDir: Quickshell.env("HOME") + "/.config/hypr"
    readonly property string generatedFile: hyprDir + "/generated/settings.lua"

    // ── validation ─────────────────────────────────────────────────────────
    // Returns the value coerced to the option's type and range, or undefined when it is not acceptable.
    function validate(key, v) {
        const o = options[key]
        if (!o) return undefined
        if (o.type === "bool") return (v === true || Number(v) !== 0 && v !== false && v !== "false") ? 1 : 0
        if (o.type === "int" || o.type === "float") {
            let n = Number(v)
            if (!isFinite(n)) return undefined
            if (o.type === "int") n = Math.round(n)
            if (o.min !== undefined) n = Math.max(o.min, n)
            if (o.max !== undefined) n = Math.min(o.max, n)
            return o.type === "float" ? Math.round(n * 1000) / 1000 : n
        }
        const s = String(v).trim()
        if (o.choices) return o.choices.indexOf(s) >= 0 ? s : undefined
        if (o.pattern && !o.pattern.test(s)) return undefined
        return s
    }

    // ── Lua helpers ─────────────────────────────────────────────────────────
    function luaValue(type, v) {
        if (type === "bool") return Number(v) !== 0 && v !== false ? "true" : "false"
        if (type === "int") return String(Math.round(Number(v)) || 0)
        if (type === "float") return String(Number(v) || 0)
        return "\"" + String(v).replace(/[^A-Za-z0-9_,.:()+ -]/g, "") + "\""   // keyboard layouts etc.
    }
    // { "general.gaps_in": "4", "input.touchpad.natural_scroll": "true" } -> "{ general = { gaps_in = 4 }, input = { … } }"
    function luaTable(flat, pretty) {
        const tree = {}
        for (const path in flat) {
            const parts = path.split(".")
            let node = tree
            for (let i = 0; i < parts.length - 1; i++) node = node[parts[i]] = node[parts[i]] || {}
            node[parts[parts.length - 1]] = flat[path]
        }
        const key = k => /^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : "[\"" + k + "\"]"
        const ser = (n, ind) => {
            if (typeof n === "string") return n
            const pad = pretty ? "\n" + "    ".repeat(ind + 1) : " "
            const end = pretty ? "\n" + "    ".repeat(ind) : " "
            return "{" + Object.keys(n).map(k => pad + key(k) + " = " + ser(n[k], ind + 1)).join(",") + end + "}"
        }
        return ser(tree, 0)
    }
    function flatOf(entries) {
        const flat = {}
        for (const k in entries) {
            const o = options[k]
            const v = validate(k, entries[k])
            if (o && v !== undefined) flat[o.opt.replace(/:/g, ".")] = luaValue(o.type, v)
        }
        return flat
    }
    function apply(entries) {            // entries: { key: value }
        const flat = flatOf(entries)
        if (!Object.keys(flat).length) return
        applyProc.command = Config.hyprEval.concat(["hl.config(" + luaTable(flat, false) + ")"])
        applyProc.running = true
    }

    function parse(j, type) {
        let v = 0
        if (j.int !== undefined) v = j.int
        else if (j.float !== undefined) v = Math.round(j.float * 1000) / 1000
        else if (j.bool !== undefined) v = j.bool ? 1 : 0
        else if (j.css !== undefined) v = parseInt(String(j.css).trim().split(/\s+/)[0], 10) || 0
        else if (j.custom !== undefined) v = parseInt(String(j.custom).split(" ")[0], 10) || 0
        else if (j.str !== undefined) v = j.str === "[[EMPTY]]" ? "" : j.str
        return type === "str" ? String(v) : v
    }

    function refresh() {
        readProc.running = true
        darkProc.running = true
    }

    function setValue(key, value) {
        const v = validate(key, value)
        if (v === undefined) { lastError = key + ": " + String(value); return false }
        lastError = ""
        values = Object.assign({}, values, { [key]: v })
        apply({ [key]: v })
        if (persisted.indexOf(key) >= 0) Settings[key] = Number(v)      // remembered across restarts
        else Settings.overrides = Object.assign({}, Settings.overrides, { [key]: v })
        writeSoon.restart()
        return true
    }
    function toggle(key) { setValue(key, values[key] ? 0 : 1) }
    // Forget a choice: Hyprland's own config takes over again after the reload.
    function resetAll() {
        for (const k of persisted) Settings[k] = -1
        Settings.overrides = ({})
        writeSoon.restart()
        reloadAfterWrite = true
    }
    property bool reloadAfterWrite: false

    // Everything changed from the menu or the Settings app (-1 = never touched).
    function chosen() {
        const e = {}
        for (const k of persisted) if (Settings[k] !== undefined && Settings[k] >= 0) e[k] = Settings[k]
        const o = Settings.overrides || {}
        for (const k in o) {
            // settings written by older versions used the hyprlang name ("input:kb_layout") as key
            const key = options[k] ? k : Object.keys(options).find(x => options[x].opt === k)
            if (key) e[key] = o[k]
        }
        return e
    }
    function reapply() { apply(chosen()) }

    // generated/settings.lua: plain hl.config{} with the chosen values (no logic, safe to delete)
    function writeGenerated() {
        const flat = flatOf(chosen())
        const body = "-- Generated by the MONOLITH Settings app (Quickshell). Do not edit: change the values in\n"
            + "-- Settings > Configs, or delete this file to go back to your own modules/*.lua.\n"
            + (Object.keys(flat).length ? "hl.config(" + luaTable(flat, true) + ")\n" : "")
        genFile.setText(body)
    }
    Timer { id: writeSoon; interval: 600; onTriggered: mkdirProc.running = true }
    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.hyprDir + "/generated"]
        onExited: code => {
            if (code !== 0) return
            root.writeGenerated()
            if (root.reloadAfterWrite) { root.reloadAfterWrite = false; root.reloadHyprland() }
        }
    }
    FileView { id: genFile; path: root.generatedFile; blockWrites: true; printErrors: false }

    function setDark(on) {
        darkMode = on
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", on ? "prefer-dark" : "default"])
    }

    function init() {}      // referenced from shell.qml so the singleton (and the overrides) load at startup
    function run(cmd) { Quickshell.execDetached(cmd) }
    function lock() { run(Config.lockCommand) }
    function logout() { run(Config.logoutCommand) }
    function suspend() { run(["systemctl", "suspend"]) }
    function reboot() { run(["systemctl", "reboot"]) }
    function poweroff() { run(["systemctl", "poweroff"]) }
    function reloadHyprland() { run(["hyprctl", "reload"]) }

    Connections {
        target: Settings
        function onLoadedOnce() { root.reapply(); if (Object.keys(root.chosen()).length) writeSoon.restart() }
    }
    // `hyprctl reload` re-runs hyprland.lua and drops runtime changes: put the menu's choices back.
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") reapplySoon.restart() }
    }
    Timer { id: reapplySoon; interval: 200; onTriggered: { root.reapply(); root.refresh() } }

    Process {
        id: applyProc
        stdout: StdioCollector { id: applyOut }
        onExited: code => { const t = applyOut.text.trim(); if (code !== 0 || (t !== "" && t !== "ok")) root.lastError = t || ("hyprctl " + code) }
    }

    // every option in one process: hyprctl --batch "j/getoption a; j/getoption b; …"
    Process {
        id: readProc
        command: ["hyprctl", "--batch", Object.keys(root.options).map(k => "j/getoption " + root.options[k].opt).join(";")]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = Object.assign({}, root.values)
                for (const m of text.match(/\{[^{}]*\}/g) || []) {
                    let j
                    try { j = JSON.parse(m) } catch (e) { continue }
                    for (const k in root.options) if (root.options[k].opt === j.option) v[k] = root.parse(j, root.options[k].type)
                }
                root.values = v
            }
        }
    }

    Process {
        id: darkProc
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        stdout: StdioCollector { onStreamFinished: root.darkMode = text.indexOf("dark") >= 0 }
    }
}
