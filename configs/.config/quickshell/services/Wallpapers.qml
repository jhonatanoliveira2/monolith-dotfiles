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
    property string error: ""
    property string current: ""
    property string currentKind: ""

    readonly property var env: ({
        WALLPAPER_STATIC_DIR: Settings.wpStaticDir.trim() || null,
        WALLPAPER_LIVE_DIR: Settings.wpLiveDir.trim() || null,
        WALLPAPER_TRANSITION: Settings.wpTransition,
        WALLPAPER_TRANSITION_DURATION: String(Settings.wpDuration),
        WALLPAPER_LIVE_AUDIO: Settings.wpLiveAudio ? "1" : "0",
        WALLPAPER_LIVE_PAUSE: Settings.wpLivePause ? "1" : "0"
    })

    // list both kinds (previews are generated on the first run, in parallel)
    function refresh() {
        if (loading) return
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
        onExited: root.loading = false
    }
    Process {
        id: setProc
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim().split("\n").pop() }
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/wallpaper-menu/last"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const [kind, , file] = text().trim().split("\t")
            if (file) { root.current = file; root.currentKind = kind === "live" ? "video" : "image" }
        }
    }
}
