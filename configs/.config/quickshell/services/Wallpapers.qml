pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Wallpaper picker data. The backends stay in ~/.local/bin/wallpaper-menu (awww for images, mpvpaper for
// videos, ffmpeg previews in its cache): the shell lists with `--list` and applies with `--set`, passing the
// options of Settings > Wallpapers as WALLPAPER_* variables. The current choice is read from the script's
// state file, so a wallpaper set from rofi or at login shows up here too.
Singleton {
    id: root
    property var images: []                   // [{ path, thumb, name }]
    property var videos: []
    property bool loading: false
    property string listed: ""                // the last `--list` output
    // emptied from outside (Settings: another folder, cleared cache): the next listing must fill it again
    onImagesChanged: if (!images.length) listed = ""
    onVideosChanged: if (!videos.length) listed = ""
    property string error: ""
    property string current: ""
    property string currentKind: ""
    property string currentOutputs: ""        // monitors of the last change: "ALL" or "DP-1,HDMI-A-1"
    property int loads: 0                     // state file reads; the first one is the session's restored wallpaper
    // emitted on every read of the state file (a choice from here, rofi or a terminal), even for the same file
    signal changed()

    readonly property var env: ({
        WALLPAPER_STATIC_DIR: Settings.wpStaticDir.trim() || null,
        WALLPAPER_LIVE_DIR: Settings.wpLiveDir.trim() || null,
        WALLPAPER_TRANSITION: Settings.wpTransition,
        WALLPAPER_TRANSITION_DURATION: String(Settings.wpDuration),
        WALLPAPER_LIVE_AUDIO: Settings.wpLiveAudio ? "1" : "0",
        WALLPAPER_LIVE_PAUSE: Settings.wpLivePause ? "1" : "0",
        // Nothing theme: the look in effect (Nix defaults + Settings overrides), so a change applies at once
        WALLPAPER_NOTHING: Nothing.available ? JSON.stringify(Nothing.effective) : null
    })
    // the dot-matrix look changed (Settings > Themes > Nothing): show the current still wallpaper again, and list
    // again in the background, so the picker's previews in the new look are rendered before it is opened
    Connections {
        target: Nothing
        function onWallpaperChanged() {
            if (root.currentKind === "image" && root.current) root.apply("static", root.current, root.currentOutputs || "ALL")
            root.refresh()
        }
    }
    // the first listing a little after login, in the background: the picker's first opening shows the grid at once
    // instead of "loading" while the script runs (and, in the dot-matrix look, renders every missing preview)
    Timer { interval: 5000; running: true; onTriggered: root.refresh() }

    // first run: apply the shipped default of the theme in use (wallpapers/static, copied to the static folder by
    // install.sh / Home Manager) once, unless wallpaper-menu already has a saved choice. It waits for nothing.json
    // to be read (Nothing.settled), so a first login in the Nothing theme gets its own default.
    readonly property string defaultPlain: "blue_sky.png"
    readonly property string defaultNothing: "orange_horizon_snowy_ridge.jpg"
    readonly property string defaultWallpaper: Nothing.active ? defaultNothing : defaultPlain
    function staticDir() { return (Settings.wpStaticDir.trim() || "~/Pictures/Wallpapers").replace(/^~/, Quickshell.env("HOME")) }
    function applyDefault() {
        if (!Settings.loaded || !Nothing.settled || Settings.wpDefaultDone) return
        Settings.wpDefaultDone = true
        defaultProc.outputs = "ALL"
        defaultProc.command = ["sh", "-c", "[ -s \"$1\" ] || [ ! -f \"$2\" ] || echo \"$2\"", "sh", stateFile.path, staticDir() + "/" + defaultWallpaper]
        defaultProc.running = true
    }
    // the theme turned on or off (scripts/nothing-theme.sh, a rebuild): the other theme's default, still shown,
    // becomes this theme's default; a wallpaper you chose yourself stays
    function followTheme() {
        if (!Nothing.settled || currentKind !== "image" || !current) return
        if (current.split("/").pop() !== (Nothing.active ? defaultPlain : defaultNothing)) return
        defaultProc.outputs = currentOutputs || "ALL"
        defaultProc.command = ["sh", "-c", "[ ! -f \"$1\" ] || echo \"$1\"", "sh", staticDir() + "/" + defaultWallpaper]
        defaultProc.running = true
    }
    Component.onCompleted: applyDefault()
    Connections { target: Settings; function onLoadedOnce() { root.applyDefault() } }
    Connections {
        target: Nothing
        function onSettledChanged() { root.applyDefault() }
        function onActiveChanged() { root.followTheme() }
    }

    // list both kinds (previews are generated on the first run, in parallel)
    // asked while a listing runs (the picker opened during the one above): once more when it ends, as it may
    // have started before a change (another look, a new file)
    property bool again: false
    function refresh() {
        if (loading) { again = true; return }
        loading = true
        error = ""
        listProc.running = true
    }
    // outputs: "ALL" or "DP-1,HDMI-A-1"
    function apply(kind, path, outputs) {
        error = ""
        setProc.environment = env
        setProc.command = [Config.wallpaperMenu, "--set", kind, path, outputs || "ALL"]
        setProc.running = true
        current = path
        currentKind = kind === "live" ? "video" : "image"
    }

    Process {
        id: listProc
        environment: root.env
        command: ["sh", "-c", "echo @image; \"$1\" --list image; echo @video; \"$1\" --list video", "sh", Config.wallpaperMenu]
        stdout: StdioCollector {
            onStreamFinished: {
                // the picker rescans on every opening: the same list keeps the arrays, so its grid is not built
                // again (and its previews do not ease in a second time) a moment after it opened
                if (text === root.listed) return
                root.listed = text
                const out = { image: [], video: [] }
                let kind = "image"
                for (const l of text.split("\n")) {
                    if (l === "@image" || l === "@video") { kind = l.slice(1); continue }
                    const [path, thumb] = l.split("\t")
                    if (path) out[kind].push({ path: path, thumb: thumb || "", name: path.split("/").pop().replace(/\.[^.]+$/, "") })
                }
                root.images = out.image
                root.videos = out.video
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim().split("\n").pop() }
        onExited: {
            root.loading = false
            if (root.again) { root.again = false; root.refresh() }
        }
    }
    Process {
        id: defaultProc
        property string outputs: "ALL"
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.apply("static", text.trim(), defaultProc.outputs) }
    }
    Process {
        id: setProc
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim().split("\n").pop() }
    }

    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/wallpaper-menu/last"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const [kind, outputs, file] = text().trim().split("\t")
            if (!file) return
            root.current = file
            root.currentKind = kind === "live" ? "video" : "image"
            root.currentOutputs = outputs || "ALL"
            root.loads++
            root.changed()
        }
    }
}
