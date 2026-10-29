pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Colour themes (Settings > Themes): default, presets and a dynamic palette made by wpgtk from the wallpaper.
// Generation lives in ~/.local/bin/monolith-theme (wpgtk in its own home: it never sets wallpapers or outputs);
// wallpapers stay with wallpaper-menu, whose state file (services/Wallpapers.qml) says which one changed last,
// on any monitor. The palette and its source are saved in settings.json, so a restart applies them at once
// without running wpgtk. Fish follows through ~/.config/fish/conf.d/monolith-theme.fish (see writeFish) and
// hyprlock through ~/.config/hypr/generated/lock-theme.conf (see writeLock) and VS Code through its
// workbench.colorCustomizations (see writeCode).
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

    // dynamic theme from the wallpaper set last, on request (the wallpaper picker's "Apply theme"); also
    // switches to the dynamic theme; coming from another theme it starts with following off, so later
    // wallpaper changes keep these colours until it is pressed again
    function applyWallpaper() {
        if (!dynamic) Settings.themeFollow = false
        Settings.themeMode = "dynamic"
        error = ""
        if (!Wallpapers.current) { fail(Strings.t("thNoWallpaper")); return }
        generate(Wallpapers.current, Wallpapers.currentOutputs, false)
    }

    // a wallpaper was set (or the state file was read at startup: `initial`)
    function follow(initial) {
        if (!dynamic || !Settings.loaded) return
        // following off: keep the palette until applyWallpaper / regenerate (the first one is still made)
        if (!Settings.themeFollow && Palettes.valid(Settings.themePalette)) return
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
    Timer { id: fishSoon; interval: 400; onTriggered: { root.writeFish(); root.writeLock(); root.writeCode() } }
    Connections {
        target: Palettes
        function onActiveChanged() { fishSoon.restart() }
    }
    Connections {
        target: Settings
        function onLanguageChanged() { fishSoon.restart() }
        function onThemeVscodeChanged() { if (Settings.themeVscode) codeSetup.done = false; root.writeCode(!Settings.themeVscode) }
    }
    FileView { id: fishView; path: Settings.ready ? root.fishFile : ""; blockLoading: true; blockWrites: true; printErrors: false }
    Process { id: fishRev }

    // ── hyprlock ──
    // lock-theme.conf sets the $lock_* colours and texts that hypr/hyprlock.conf uses (it keeps defaults for
    // when the file is missing); hyprlock reads it on every lock, so nothing has to be reloaded.
    readonly property string lockFile: Quickshell.env("HOME") + "/.config/hypr/generated/lock-theme.conf"
    property string lockWritten: ""
    function lockBody() {
        const a = Palettes.active, c = a.ansi
        const col = (h, al) => "rgba(" + String(h).replace("#", "") + ("0" + Math.round((al === undefined ? 1 : al) * 255).toString(16)).slice(-2) + ")"
        const en = Settings.language === "en"
        const v = {
            lock_text: col(a.foreground), lock_time: col(a.white), lock_date: col(a.grayLight), lock_layout: col(a.grayMid),
            lock_inner: col(a.panel, 0.15), lock_line: col(a.line, 0.25), lock_check: col(a.accent),
            lock_fail: col(c ? c[1] : "#e06c75"), lock_caps: col(c ? c[3] : "#e5c07b"),
            lock_txt_password: en ? "Password" : "Senha", lock_txt_caps: en ? "Caps Lock is on" : "Caps Lock ativado"
        }
        let out = "# Monolith Shell lock screen theme, written by services/Themes.qml. Do not edit.\n"
        for (const k in v) out += "$" + k + " = " + v[k] + "\n"
        return out
    }
    function writeLock() {
        if (!Settings.loaded) return
        const body = lockBody()
        if (body === lockWritten) return
        if (lockProc.running) { fishSoon.restart(); return }
        lockWritten = body
        lockProc.command = ["sh", "-c", 'mkdir -p "${1%/*}" && printf %s "$2" > "$1.tmp" && mv -f "$1.tmp" "$1"', "sh", lockFile, body]
        lockProc.running = true
    }
    Process { id: lockProc; onExited: code => { if (code !== 0) root.lockWritten = "" } }

    // ── VS Code ──
    // Sets "workbench.colorCustomizations" and "editor.tokenColorCustomizations" (syntax) in the user settings.json
    // of Code / Code - OSS / VSCodium (VS Code applies them at once). jq rewrites the file, so one with comments
    // (not plain JSON) is left alone. Turning the option off removes both keys once. Before the first write of a
    // session, ~/.local/bin/monolith-vscode sets up an editor installed since (Vibrancy Continued, settings.json).
    readonly property var codeFiles: ["Code", "Code - OSS", "VSCodium"].map(d => (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/" + d + "/User/settings.json")
    property string codeWritten: ""
    function codeColors() {
        const a = Palettes.active, c = a.ansi
        const h = (x, al) => String(x) + (al === undefined ? "" : ("0" + Math.round(al * 255).toString(16)).slice(-2))
        const bg = a.background, bar = a.bar, fg = a.foreground, acc = a.accent, dark = a.grayDark, border = h(a.line, 0.15)
        // the window is translucent: layers that stack over a pane stay clear, panes are glass, popups nearly opaque
        const clear = h(bg, 0), glass = h(bg, 0.8), glassBar = h(bar, 0.8), pop = h(bar, 0.9)
        const v = {
            "foreground": fg, "focusBorder": h(acc, 0.5), "widget.border": border, "selection.background": h(acc, 0.3),
            "editor.background": glass, "editor.foreground": fg, "editorCursor.foreground": acc, "editorPane.background": clear,
            "editorStickyScroll.background": glass, "editorStickyScrollGutter.background": glass, "minimap.background": glass,
            "sideBarStickyScroll.background": glassBar, "panelStickyScroll.background": glass, "terminalStickyScroll.background": glass,
            "inlineChat.background": pop, "notificationCenterHeader.background": pop, "editorGroupHeader.noTabsBackground": clear,
            "tab.unfocusedActiveBackground": clear, "tab.unfocusedInactiveBackground": glassBar, "sideBarTitle.background": glassBar,
            "editor.selectionBackground": h(acc, 0.25), "editor.lineHighlightBackground": h(dark, 0.3), "editor.lineHighlightBorder": "#00000000",
            "editorLineNumber.foreground": a.grayMid, "editorLineNumber.activeForeground": fg,
            "editorGutter.background": clear, "editorIndentGuide.background1": h(dark, 0.6), "editorWhitespace.foreground": h(dark, 0.8),
            "editorWidget.background": pop, "editorWidget.border": border, "editorHoverWidget.background": pop, "editorSuggestWidget.background": pop,
            "editorGroup.border": border, "editorGroupHeader.tabsBackground": clear, "editorGroupHeader.tabsBorder": border,
            "tab.activeBackground": clear, "tab.inactiveBackground": glassBar, "tab.activeForeground": a.white, "tab.inactiveForeground": a.grayMid,
            "tab.activeBorderTop": acc, "tab.border": border, "tab.hoverBackground": h(dark, 0.4),
            "titleBar.activeBackground": bar, "titleBar.inactiveBackground": bar, "titleBar.activeForeground": fg, "titleBar.inactiveForeground": a.grayMid, "titleBar.border": border,
            "activityBar.background": glassBar, "activityBar.foreground": fg, "activityBar.inactiveForeground": a.grayMid, "activityBar.border": border,
            "activityBar.activeBorder": acc, "activityBarBadge.background": acc, "activityBarBadge.foreground": a.onAccent,
            "activityBarTop.foreground": fg, "activityBarTop.inactiveForeground": a.grayMid, "activityBarTop.activeBorder": acc,
            "sideBar.background": glassBar, "sideBar.foreground": a.grayLight, "sideBar.border": border, "sideBarTitle.foreground": fg,
            "sideBarSectionHeader.background": clear, "sideBarSectionHeader.foreground": fg, "sideBarSectionHeader.border": border,
            "statusBar.background": bar, "statusBar.foreground": a.grayLight, "statusBar.border": border, "statusBar.noFolderBackground": bar,
            "panel.background": clear, "panel.border": border, "panelTitle.activeForeground": fg, "panelTitle.inactiveForeground": a.grayMid, "panelTitle.activeBorder": acc,
            "terminal.background": clear, "terminal.foreground": fg, "terminalCursor.foreground": acc,
            "list.activeSelectionBackground": h(dark, 0.8), "list.activeSelectionForeground": a.white, "list.inactiveSelectionBackground": h(dark, 0.5),
            "list.hoverBackground": h(dark, 0.4), "list.focusOutline": h(acc, 0.5), "list.highlightForeground": acc,
            "input.background": bar, "input.foreground": fg, "input.border": border, "input.placeholderForeground": a.grayMid,
            "dropdown.background": bar, "dropdown.border": border, "quickInput.background": pop, "menu.background": pop, "menu.foreground": fg,
            "menu.selectionBackground": h(dark, 0.8), "menu.border": border,
            "button.background": acc, "button.foreground": a.onAccent, "button.secondaryBackground": dark, "button.secondaryForeground": fg,
            "badge.background": acc, "badge.foreground": a.onAccent, "progressBar.background": acc, "textLink.foreground": acc, "textLink.activeForeground": acc,
            "scrollbarSlider.background": h(dark, 0.5), "scrollbarSlider.hoverBackground": h(dark, 0.8), "scrollbarSlider.activeBackground": dark,
            "notifications.background": pop, "notifications.border": border, "breadcrumb.background": clear
        }
        if (c) {
            const names = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]
            for (let i = 0; i < 16; i++) v["terminal.ansi" + (i < 8 ? "" : "Bright") + names[i % 8]] = c[i]
        }
        return v
    }
    // syntax colours as TextMate rules over whatever colour theme is chosen; the default theme has no ansi
    // colours, so it leaves the syntax to that theme
    function codeTokens() {
        const a = Palettes.active, c = a.ansi
        if (!c) return null
        const r = (scope, fg, style) => ({ scope: scope, settings: style ? { foreground: fg, fontStyle: style } : { foreground: fg } })
        return { textMateRules: [
            r(["source", "variable", "meta.definition.variable"], a.foreground),
            r(["comment", "punctuation.definition.comment"], a.grayMid, "italic"),
            r(["keyword", "storage", "storage.type", "storage.modifier", "keyword.control"], c[5]),
            r(["keyword.operator", "punctuation.separator", "punctuation.accessor"], c[6]),
            r(["string", "punctuation.definition.string", "markup.inline.raw"], c[2]),
            r(["string.regexp", "constant.character.escape", "constant.other.placeholder"], c[14]),
            r(["constant.numeric", "constant.language", "constant.character", "constant.other", "support.constant"], c[3]),
            r(["entity.name.function", "support.function", "meta.function-call.generic", "variable.function"], c[4]),
            r(["entity.name.type", "entity.name.class", "entity.name.namespace", "support.type", "support.class", "entity.other.inherited-class"], c[11]),
            r(["variable.parameter", "meta.parameter"], a.grayLight, "italic"),
            r(["variable.other.property", "variable.other.object.property", "support.variable.property", "meta.object-literal.key"], c[14]),
            r(["variable.language", "variable.other.constant", "variable.other.enummember"], c[9]),
            r(["entity.name.tag", "punctuation.definition.tag"], c[4]),
            r(["entity.other.attribute-name"], c[3], "italic"),
            r(["support.type.property-name", "meta.property-name"], c[6]),
            r(["markup.heading", "entity.name.section"], a.accent, "bold"),
            r(["markup.bold"], a.foreground, "bold"), r(["markup.italic"], a.foreground, "italic"),
            r(["markup.underline.link", "string.other.link"], a.accent),
            r(["markup.inserted"], c[2]), r(["markup.deleted"], c[1]), r(["markup.changed"], c[3]),
            r(["invalid", "invalid.illegal"], c[1])
        ] }
    }
    function writeCode(remove) {
        if (!Settings.loaded || (!remove && !Settings.themeVscode)) return
        if (!remove && !codeSetup.done) { codeSetup.running = true; return }
        // keys set to null are removed: the default theme drops the syntax rules, turning the option off drops both
        const json = JSON.stringify(remove ? { "workbench.colorCustomizations": null, "editor.tokenColorCustomizations": null }
                                           : { "workbench.colorCustomizations": codeColors(), "editor.tokenColorCustomizations": codeTokens() })
        if (!remove && json === codeWritten) return
        if (codeProc.running) { fishSoon.restart(); return }
        codeWritten = json
        // jq takes the keys as $c (--argjson); a file is rewritten only when the result differs
        const script = [
            'c=$1; shift',
            'for f; do',
            '  [ -f "$f" ] || continue',
            '  new=$(jq --indent 2 --argjson c "$c" \'reduce ($c | to_entries[]) as $e (.; if $e.value == null then del(.[$e.key]) else .[$e.key] = $e.value end)\' "$f" 2>/dev/null) || continue',
            '  [ "$new" = "$(cat "$f")" ] || printf "%s\\n" "$new" >"$f"',
            'done'
        ].join("\n")
        codeProc.command = ["sh", "-c", script, "sh", json].concat(codeFiles)
        codeProc.running = true
    }
    Process { id: codeProc }
    Process {
        id: codeSetup
        property bool done: false
        command: ["sh", "-c", '[ -x "$1" ] && "$1" --quiet; exit 0', "sh", Quickshell.env("HOME") + "/.local/bin/monolith-vscode"]
        onExited: { done = true; root.codeWritten = ""; root.writeCode() }
    }
}
