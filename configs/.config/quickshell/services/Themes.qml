pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Colour themes (Settings > Themes): default, presets and a dynamic palette made by wpgtk from the wallpaper.
// Generation lives in ~/.local/bin/monolith-theme (wpgtk in its own home: it never sets wallpapers or outputs);
// wallpapers stay with wallpaper-menu, whose state file (services/Wallpapers.qml) says which one changed last,
// on any monitor. The palette and its source are saved in settings.json, so a restart applies them at once
// without running wpgtk. Fish follows through ~/.config/fish/conf.d/monolith-theme.fish (see writeFish).
Singleton {
    id: root
    readonly property string script: Quickshell.env("HOME") + "/.local/bin/monolith-theme"
    readonly property string fishFile: Settings.dir + "/fish-theme.fish"
    readonly property bool dynamic: Settings.themeMode === "dynamic"
    property string status: "idle"          // idle | loading | ok | error
    property string error: ""
    property var deps: []                   // [{ name, ok, detail }] from `monolith-theme check`
    property bool depsChecked: false
    readonly property bool depsOk: depsChecked && deps.every(d => d.ok || d.name === "fish")
    property var job: null                  // { path, outputs, force } being generated
    property var pending: null              // the newest request while one runs

    // referenced from shell.qml so the singleton loads at startup (settings / wallpaper may already be read)
    function init() {
        checkDeps()
        if (Settings.loaded) { follow(true); fishSoon.restart() }
    }

    function setMode(mode, preset) {
        if (preset) Settings.themePreset = preset
        Settings.themeMode = mode
        error = ""
        status = "idle"
        if (mode === "dynamic") follow(false)
    }
    // regenerate from the wallpaper changed last (wpgtk cache dropped)
    function regenerate() {
        if (!Wallpapers.current) { fail(Strings.t("thNoWallpaper")); return }
        generate(Wallpapers.current, Wallpapers.currentOutputs, true)
    }
    function checkDeps() { if (!depsProc.running) depsProc.running = true }

    // a wallpaper was set (or the state file was read at startup: `initial`)
    function follow(initial) {
        if (!dynamic || !Settings.loaded) return
        if (!Wallpapers.current) { if (!initial) fail(Strings.t("thNoWallpaper")); return }
        const cur = Settings.themePalette
        if (Palettes.valid(cur) && cur.source === Wallpapers.current) {
            // same file on another monitor: same colours, only the source changes
            if (cur.outputs !== Wallpapers.currentOutputs) Settings.themePalette = Object.assign({}, cur, { outputs: Wallpapers.currentOutputs })
            // at startup the saved palette is already right; a new choice re-checks it (the script's cache
            // answers at once unless the file itself changed)
            if (initial) return
        }
        generate(Wallpapers.current, Wallpapers.currentOutputs, false)
    }

    function generate(path, outputs, force) {
        const req = { path: path, outputs: outputs || "ALL", force: !!force }
        if (genProc.running) { pending = req; return }
        job = req
        status = "loading"
        error = ""
        genProc.command = root.run(["generate", path].concat(force ? ["--force"] : []))
        genProc.running = true
    }
    function fail(msg) { status = "error"; error = msg }
    // through sh, so a missing script still ends the process (exit 127) instead of never starting
    function run(args) { return ["sh", "-c", '[ -x "$0" ] || exit 127; exec "$0" "$@"', script].concat(args) }

    Connections {
        target: Wallpapers
        function onChanged() { root.follow(Wallpapers.loads <= 1) }
    }
    Connections {
        target: Settings
        function onLoadedOnce() { root.follow(true); fishSoon.restart() }
    }

    Process {
        id: genProc
        stdout: StdioCollector { id: genOut }
        stderr: StdioCollector { id: genErr }
        onExited: code => {
            const req = root.job
            root.job = null
            let pal = null
            try { pal = code === 0 ? JSON.parse(genOut.text) : null } catch (e) { pal = null }
            // a failure keeps the last valid palette (or the default colours when there is none)
            if (!Palettes.valid(pal)) {
                root.fail(genErr.text.trim().split("\n").pop() || (code === 127 ? Strings.t("thNoScript") : "monolith-theme " + code))
            } else if (root.dynamic) {
                pal.outputs = req.outputs
                pal.time = Date.now()
                Settings.themePalette = pal
                root.status = "ok"
            } else root.status = "idle"   // the theme was changed while generating
            if (root.pending) { const p = root.pending; root.pending = null; root.generate(p.path, p.outputs, p.force) }
        }
    }

    Process {
        id: depsProc
        command: root.run(["check"])
        stdout: StdioCollector { id: depsOut }
        onExited: code => {
            const list = []
            for (const l of depsOut.text.split("\n")) {
                const [name, state, detail] = l.split("\t")
                if (name) list.push({ name: name, ok: state === "ok", detail: detail || "" })
            }
            root.deps = list.length ? list : [{ name: "monolith-theme", ok: false, detail: root.script.replace(Quickshell.env("HOME"), "~") }]
            root.depsChecked = true
        }
    }

    // ── Fish ──
    // fish-theme.fish defines the colours of the active theme; conf.d/monolith-theme.fish sources it in every
    // new interactive session and again in open ones when the universal variable __monolith_theme_rev changes
    // (fish delivers that change to running sessions itself: no polling). The default theme writes no
    // colours, so the conf.d script puts back fish's own colours and the original terminal palette.
    function fishBody() {
        const a = Palettes.active, c = a.ansi
        let out = "# Monolith Shell colour theme, written by Settings > Themes (services/Themes.qml). Do not edit.\n"
                + "# theme: " + Settings.themeMode + (Settings.themeMode === "preset" ? " " + Settings.themePreset : "") + "\n"
        if (!c) return out
        const h = x => String(x).replace("#", "")
        const bg = x => "--background=" + h(x)
        const colors = {
            fish_color_normal: h(a.foreground), fish_color_command: h(a.accent), fish_color_keyword: h(c[5]),
            fish_color_quote: h(c[3]), fish_color_redirection: h(c[6]), fish_color_end: h(c[4]), fish_color_error: h(c[1]),
            fish_color_param: h(a.grayLight), fish_color_option: h(a.grayLight), fish_color_comment: h(a.grayMid),
            fish_color_autosuggestion: h(a.grayMid), fish_color_operator: h(c[6]), fish_color_escape: h(c[6]),
            fish_color_valid_path: "--underline", fish_color_selection: h(a.white) + " --bold " + bg(a.grayDark),
            fish_color_search_match: bg(a.grayDark), fish_color_history_current: "--bold", fish_color_cancel: "-r",
            fish_color_cwd: h(c[2]), fish_color_cwd_root: h(c[1]), fish_color_user: h(c[2]), fish_color_host: h(a.foreground),
            fish_color_host_remote: h(c[3]), fish_color_status: h(c[1]),
            fish_pager_color_prefix: h(a.accent) + " --bold --underline", fish_pager_color_completion: h(a.foreground),
            fish_pager_color_description: h(a.grayMid), fish_pager_color_progress: h(a.onAccent) + " " + bg(a.accent),
            fish_pager_color_selected_background: bg(a.grayDark)
        }
        out += "function __monolith_theme_colors\n"
        for (const k in colors) out += "    set -g " + k + " " + colors[k] + "\n"
        out += "end\nfunction __monolith_theme_terminal\n"
            + "    printf '\\e]4;%s;%s\\a' " + c.map((x, i) => i + " '" + x + "'").join(" ") + "\n"
            + "    printf '\\e]10;%s\\a\\e]11;%s\\a\\e]12;%s\\a' '" + a.foreground + "' '" + a.background + "' '" + a.foreground + "'\n"
            + "end\n"
        return out
    }
    // written only when the content changes, so restarts do not repaint every terminal
    function writeFish() {
        if (!Settings.loaded || !Settings.ready) return
        const body = fishBody()
        fishView.reload()
        if (fishView.text() === body) return
        fishView.setText(body)
        fishRev.command = ["fish", "-c", "set -U __monolith_theme_rev " + Date.now()]
        fishRev.running = true
    }
    Timer { id: fishSoon; interval: 400; onTriggered: root.writeFish() }
    Connections {
        target: Palettes
        function onActiveChanged() { fishSoon.restart() }
    }
    FileView { id: fishView; path: Settings.ready ? root.fishFile : ""; blockLoading: true; blockWrites: true; printErrors: false }
    Process { id: fishRev }
}
