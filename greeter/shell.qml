//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import "core"
import "components"

// MONOLITH greeter (greetd + Quickshell, inside cage). Started by nix/modules/nixos/greeter.nix.
//
// It opens on Plymouth's last frame (mark, wordmark and the full progress line at the same place, on black),
// then the mark rises, the line fades and the login appears. Authentication is PAM through greetd: the
// password typed first answers the first secret prompt; any further prompt (second factor, expired password,
// a question) is shown and answered in the same field. Success plays the mark's light sweep, fades to black
// and hands the VT to the session (the remembered user / session are saved for the next boot).
// Recovery: the wrapper falls back to a text greeter if this one fails to start, the "Console" session gives a
// login shell and Ctrl+Alt+F<n> still switches VTs (cage -s).
ShellRoot {
    id: root

    // ── configuration (JSON written by the NixOS module) ──
    FileView { id: cfgFile; path: Quickshell.env("MONOLITH_GREETER_CONFIG") || ""; blockLoading: true }
    readonly property var cfg: { try { return JSON.parse(cfgFile.text()) } catch (e) { return ({}) } }
    readonly property bool en: cfg.language === "en"
    function tr(pt, en) { return root.en ? en : pt }

    // ── last user / session, kept in /var/lib/monolith-greeter ──
    FileView { id: stateFile; path: root.cfg.statePath || ""; blockLoading: true; printErrors: false }
    readonly property var saved: { try { return JSON.parse(stateFile.text() || "{}") } catch (e) { return ({}) } }

    readonly property var users: cfg.users || []
    property int userIndex: 0
    property bool customUser: users.length === 0
    property string typedUser: ""
    readonly property var user: customUser ? ({ name: typedUser.trim(), description: "" }) : (users[userIndex] || ({ name: "", description: "" }))
    property var sessions: []
    property int sessionIndex: 0
    readonly property var session: sessions[sessionIndex] || null

    property string message: ""
    property bool messageError: false
    property string prompt: ""           // a further PAM prompt shown in the field
    property bool promptEcho: false
    property bool awaiting: false        // that prompt waits for an answer
    property var secret: null            // the password, until the first secret prompt asks for it
    property bool busy: false
    property bool leaving: false

    Component.onCompleted: {
        Theme.animations = cfg.animations !== false
        Theme.nothing = cfg.nothing === true
        const u = saved.user || cfg.defaultUser || ""
        const i = users.findIndex(x => x.name === u)
        if (i >= 0) userIndex = i
        else if (u && cfg.allowOtherUsers !== false) { customUser = true; typedUser = u }
        sessionsProc.running = true
    }

    function cycleUser(d) {
        if (busy) return
        const n = users.length + (cfg.allowOtherUsers !== false ? 1 : 0)
        if (n < 2) return
        let i = (customUser ? users.length : userIndex) + d
        i = (i + n) % n
        customUser = i >= users.length
        if (!customUser) userIndex = i
        message = ""
    }
    function cycleSession(d) {
        if (busy || sessions.length < 2) return
        sessionIndex = (sessionIndex + d + sessions.length) % sessions.length
    }
    function show(text, error) { message = text; messageError = error }

    function submit(text) {
        if (leaving) return
        if (awaiting) { awaiting = false; busy = true; Greetd.respond(text); return }
        if (busy) return
        if (!user.name) { show(tr("Informe o usuário", "Enter the user name"), true); return }
        if (!session) { show(tr("Nenhuma sessão encontrada", "No session found"), true); return }
        secret = text; busy = true; show(tr("Autenticando…", "Authenticating…"), false)
        Greetd.createSession(user.name)
    }
    function reset() {
        secret = null; awaiting = false; prompt = ""; promptEcho = false; busy = false
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession()
    }
    function fail(text) {
        reset()
        show(text, true)
        win.shake()
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                if (!echoResponse && root.secret !== null) {
                    const s = root.secret
                    root.secret = null
                    Greetd.respond(s)
                    return
                }
                root.prompt = message; root.promptEcho = echoResponse; root.awaiting = true; root.busy = false
                root.show("", false)
                win.focusField()
            } else if (message) {
                root.show(message, error)
            }
        }
        function onAuthFailure(message) { root.fail(message || root.tr("Senha incorreta", "Wrong password")) }
        function onError(error) { root.fail(String(error)) }
        function onReadyToLaunch() { root.launch() }
    }

    function launch() {
        const s = session
        leaving = true; busy = true; awaiting = false; prompt = ""
        show("", false)
        if (cfg.statePath)
            Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1%/*}" && printf "%s" "$2" > "$1.tmp" && mv -f "$1.tmp" "$1"',
                                     "sh", cfg.statePath, JSON.stringify({ user: user.name, session: s.id })])
        win.leave(() => Greetd.launch(s.command, s.env, true))
    }

    // ── sessions: .desktop files of services.displayManager.sessionData (Wayland) + a console login ──
    Process {
        id: sessionsProc
        command: ["sh", "-c", 'for d; do for f in "$d"/*.desktop; do [ -f "$f" ] || continue
            g() { sed -n "s/^$1=//p" "$f" | head -n1; }
            [ "$(g Hidden)" = true ] || [ "$(g NoDisplay)" = true ] && continue
            id=${f##*/}; printf "%s\\t%s\\t%s\\t%s\\n" "${id%.desktop}" "$(g Name)" "$(g Exec)" "$(g DesktopNames)"
            done; done', "sh"].concat(root.cfg.sessionDirs || [])
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of text.split("\n")) {
                    const f = line.split("\t")
                    if (f.length < 3 || !f[2].trim()) continue
                    const exec = f[2].replace(/%[a-zA-Z]/g, "").trim()
                    const names = (f[3] || "").replace(/;+$/, "").replace(/;/g, ":") || f[1]
                    list.push({ id: f[0], name: f[1] || f[0], command: ["sh", "-c", exec],
                                env: ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + f[0], "XDG_CURRENT_DESKTOP=" + names] })
                }
                list.sort((a, b) => a.name.localeCompare(b.name))
                if (root.cfg.console !== false)
                    list.push({ id: "console", name: root.tr("Console (shell)", "Console (shell)"),
                                command: ["sh", "-c", 'exec "${SHELL:-/bin/sh}" -l'], env: ["XDG_SESSION_TYPE=tty"] })
                root.sessions = list
                const want = root.saved.session || root.cfg.defaultSession || "hyprland"
                let i = list.findIndex(s => s.id === want)
                if (i < 0) i = list.findIndex(s => s.id.toLowerCase().indexOf("hyprland") >= 0)
                root.sessionIndex = Math.max(0, i)
            }
        }
    }

    // ── small system facts for the footer ──
    FileView { id: hostFile; path: "/proc/sys/kernel/hostname"; blockLoading: true; printErrors: false }
    property bool capsLock: false
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*capslock/brightness 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.capsLock = text.split("\n").some(l => l.trim() !== "" && l.trim() !== "0") }
    }
    Timer { interval: 400; running: !root.leaving; repeat: true; triggeredOnStart: true; onTriggered: capsProc.running = true }

    GreeterWindow {
        id: win
        greeter: root
        hostname: String(hostFile.text() || "").trim()
    }
}
