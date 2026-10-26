pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../core"

// MPRIS players (native, no playerctl): active-player choice, position tracking, volume, track history and search.
// Covers of the last 50 tracks are cached in ~/.cache/quickshell-monolith/covers (players often hand out temporary
// file:// paths or expiring URLs). YouTube Music (th-ch desktop app) does not expose shuffle / repeat over MPRIS:
// those go through its "API Server" plugin when it is enabled (see ytm* below).
Singleton {
    id: root

    // playerctld only mirrors the real players: hide it so nothing shows up twice
    readonly property var players: Mpris.players.values.filter(p => String(p.dbusName || "").indexOf("playerctld") < 0)
    property var chosen: null                       // player picked by hand in the media menu
    readonly property var player: pick()
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string title: player ? String(player.trackTitle || player.identity || "") : ""
    readonly property string artist: player ? String(player.trackArtist || "") : ""
    readonly property string album: player ? String(player.trackAlbum || "") : ""
    readonly property string playerArt: player ? String(player.trackArtUrl || "") : ""
    // cached copy of the current cover when the player gives none (or a temporary file that is gone)
    readonly property string art: playerArt !== "" ? playerArt : cachedArt(title, artist)
    function cachedArt(t, a) { const h = history.find(e => e.title === t && e.artist === a); return h && h.cover ? h.cover : "" }

    // Position / length. Many players report length == position after a seek: keep the last sane length.
    property real position: 0
    property real length: 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
    property int consumers: 0                        // UI parts that show the position (bar progress, menu)

    function pick() {
        const l = players
        if (chosen && l.indexOf(chosen) >= 0) return chosen
        let paused = null
        for (let i = 0; i < l.length; i++) {
            if (l[i].isPlaying) return l[i]
            if (!paused && l[i].playbackState === MprisPlaybackState.Paused) paused = l[i]
        }
        return paused || (l.length ? l[0] : null)
    }
    function choose(p) { chosen = p; sync() }

    function sync() {
        if (!player) { position = 0; length = 0; return }
        const pos = player.positionSupported ? player.position : 0
        const len = player.lengthSupported ? player.length : 0
        position = pos
        if (len > pos + 1.0 || (length <= 0 && len > 0)) length = len
    }

    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60
        return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (r < 10 ? "0" : "") + r
    }

    // ── controls ────────────────────────────────────────────────────────────
    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function next() { if (player && player.canGoNext) player.next() }
    function previous() {
        if (!player) return
        // like most players: "previous" restarts the track after the first seconds
        if (player.canSeek && position > 5) seekTo(0)
        else if (player.canGoPrevious) player.previous()
    }
    function seekTo(seconds) {
        if (!player || !player.canSeek) return
        player.position = Math.max(0, Math.min(length > 0 ? length - 0.5 : seconds, seconds))
        position = player.position
    }
    function seekBy(delta) { seekTo(position + delta) }

    // ── shuffle / repeat: MPRIS when the player supports it, the YouTube Music API otherwise ──
    readonly property bool isYtm: player !== null && /youtube[- ]music/.test((String(player.desktopEntry || "") + " " + String(player.identity || "")).toLowerCase())
    readonly property bool useYtm: isYtm && !(player.shuffleSupported && player.loopSupported)
    readonly property bool canShuffle: player !== null && (player.shuffleSupported || (useYtm && ytmOk))
    readonly property bool canLoop: player !== null && (player.loopSupported || (useYtm && ytmOk))
    readonly property bool shuffle: !player ? false : player.shuffleSupported ? player.shuffle : ytmShuffle
    readonly property string loop: !player ? "none"                                  // none | playlist | track
        : player.loopSupported ? (player.loopState === MprisLoopState.Track ? "track" : player.loopState === MprisLoopState.Playlist ? "playlist" : "none")
        : ytmLoop
    function setShuffle(on) {
        if (!player) return
        if (player.shuffleSupported) player.shuffle = on
        else if (useYtm) ytm("POST", "shuffle", "")
    }
    function cycleLoop() {
        if (!player) return
        if (player.loopSupported) {
            player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                : player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
        } else if (useYtm) ytm("POST", "switch-repeat", "{\"iteration\":1}")
    }

    // th-ch/youtube-music "API Server" plugin (Plugins > API Server; set authorization to "No authorization",
    // or paste a token in Settings > Bar). Unreachable -> the buttons stay disabled and ytmError says why.
    property bool ytmOk: false
    property bool ytmShuffle: false
    property string ytmLoop: "none"
    property string ytmError: ""
    readonly property string ytmBase: "http://127.0.0.1:" + Settings.ytmPort + "/api/v1/"
    function ytm(method, path, body) {
        if (ytmProc.running) return
        const args = ["curl", "-sS", "--max-time", "3", "-X", method, "-H", "Content-Type: application/json"]
        if (Settings.ytmToken) args.push("-H", "Authorization: Bearer " + Settings.ytmToken)
        if (body) args.push("-d", body)
        // after an action, read the new state back in the same process
        const read = ["curl", "-sS", "--max-time", "3", "-w", "\\n%{http_code}\\n"].concat(Settings.ytmToken ? ["-H", "Authorization: Bearer " + Settings.ytmToken] : [])
        const q = a => "'" + String(a).replace(/'/g, "'\\''") + "'"
        let sh = method === "GET" ? "" : args.map(q).join(" ") + " " + q(ytmBase + path) + " >/dev/null || exit 7; sleep 0.3; "
        sh += read.map(q).join(" ") + " " + q(ytmBase + "shuffle") + "; " + read.map(q).join(" ") + " " + q(ytmBase + "repeat-mode")
        ytmProc.command = ["sh", "-c", sh]
        ytmProc.running = true
    }
    function ytmRefresh() { if (useYtm) ytm("GET", "", "") }
    onUseYtmChanged: ytmRefresh()
    Process {
        id: ytmProc
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n")
                // output: <shuffle json> <code> <repeat json> <code>
                let ok = false
                try {
                    const codes = l.filter(x => /^\d{3}$/.test(x.trim()))
                    const bodies = l.filter(x => x.trim().indexOf("{") === 0).map(x => JSON.parse(x))
                    if (codes.length && codes.every(c => c.trim() === "200") && bodies.length >= 2) {
                        root.ytmShuffle = !!bodies[0].state
                        const m = String(bodies[1].mode || "NONE")
                        root.ytmLoop = m === "ONE" ? "track" : m === "ALL" ? "playlist" : "none"
                        ok = true
                        root.ytmError = ""
                    } else if (codes.some(c => c.trim() === "401" || c.trim() === "403")) root.ytmError = Strings.t("ytmAuth")
                    else root.ytmError = Strings.t("ytmHttp") + " " + codes.join(",")
                } catch (e) { root.ytmError = Strings.t("ytmHttp") }
                root.ytmOk = ok
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") { root.ytmOk = false; root.ytmError = Strings.t("ytmOff") } }
    }

    // Volume: the player's own MPRIS volume when it has one, otherwise its PipeWire stream.
    readonly property var stream: {
        if (!player) return null
        const id = String(player.identity || "").toLowerCase(), de = String(player.desktopEntry || "").toLowerCase()
        return Audio.streams.find(s => {
            const p = s.properties || {}
            const n = String(p["application.name"] || "").toLowerCase(), b = String(p["application.process.binary"] || "").toLowerCase()
            return (id && (n === id || b === id)) || (de && (n === de || b === de || de.indexOf(b) >= 0 && b))
        }) || null
    }
    readonly property bool hasVolume: (player && player.volumeSupported) || (stream !== null && stream.audio !== null)
    readonly property real volume: player && player.volumeSupported ? player.volume : stream && stream.audio ? stream.audio.volume : 0
    function setVolume(v) {
        v = Math.max(0, Math.min(1, v))
        if (player && player.volumeSupported) player.volume = v
        else if (stream && stream.audio) stream.audio.volume = v
    }

    // ── history + search ────────────────────────────────────────────────────
    readonly property var history: store.tracks || []
    readonly property int historyMax: 50
    readonly property string coverDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell-monolith/covers"
    function remember() {
        if (!player || !title) return
        const md = player.metadata || {}
        const old = history.find(h => h.title === title && h.artist === artist)
        const src = playerArt
        const file = src ? coverDir + "/" + Qt.md5(src) + ".img" : ""
        const e = { title: title, artist: artist, album: album, art: src.indexOf("file://") === 0 ? "" : src,
                    cover: old && old.src === src && old.cover ? old.cover : "", src: src,
                    url: String(md["xesam:url"] || ""), trackId: String(md["mpris:trackid"] || ""),
                    player: String(player.identity || ""), at: Date.now() }
        const rest = history.filter(h => h !== old)
        const all = [e].concat(rest)
        const kept = all.slice(0, historyMax)
        // drop the cover files of evicted entries (and of the replaced cover of this track)
        const live = kept.map(h => h.cover).filter(c => c)
        const gone = all.slice(historyMax).concat(old ? [old] : []).map(h => h.cover)
            .filter(c => c && live.indexOf(c) < 0 && c !== "file://" + file).map(c => c.replace("file://", ""))
        if (gone.length) Quickshell.execDetached(["rm", "-f"].concat(gone))
        store.tracks = kept
        if (src && !e.cover) cacheCover(src, file, e.title, e.artist)
    }
    // copy (file://) or download (http/https) the cover once; the history entry points to the cached file
    property var coverQueue: []
    function cacheCover(src, file, t, a) {
        coverQueue = coverQueue.concat([{ src: src, file: file, title: t, artist: a }])
        if (!coverProc.running) nextCover()
    }
    function nextCover() {
        if (!coverQueue.length) return
        const j = coverQueue[0]
        coverProc.job = j
        coverProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && case \"$1\" in " +
            "file://*) cp -f \"${1#file://}\" \"$2.part\" ;; http://*|https://*) curl -sfL --max-time 15 --max-filesize 4000000 -o \"$2.part\" \"$1\" ;; *) exit 2 ;; esac " +
            "&& mv -f \"$2.part\" \"$2\" || { rm -f \"$2.part\"; exit 1; }", "sh", j.src, j.file]
        coverProc.running = true
    }
    Process {
        id: coverProc
        property var job: null
        onExited: code => {
            const j = job
            root.coverQueue = root.coverQueue.slice(1)
            if (code === 0 && j) store.tracks = root.history.map(h => h.title === j.title && h.artist === j.artist && h.src === j.src
                ? Object.assign({}, h, { cover: "file://" + j.file }) : h)
            root.nextCover()
        }
    }
    function search(q) {
        const terms = String(q).toLowerCase().split(/\s+/).filter(x => x.length)
        if (!terms.length) return history.slice(0, 20)
        return history.filter(h => {
            const hay = (h.title + " " + h.artist + " " + h.album).toLowerCase()
            return terms.every(t => hay.indexOf(t) >= 0)
        }).slice(0, 30)
    }
    function supports(scheme) { return player && (player.supportedUriSchemes || []).indexOf(scheme) >= 0 }
    // Replay a history entry in the current player (Spotify ids, or any URI scheme the player accepts).
    function replay(e) {
        const sp = /\/com\/spotify\/track\/(\w+)/.exec(e.trackId) || /open\.spotify\.com\/track\/(\w+)/.exec(e.url)
        if (sp && supports("spotify")) { openAndPlay("spotify:track:" + sp[1], e); return }
        const scheme = e.url.split(":")[0]
        if (e.url && supports(scheme)) { openAndPlay(e.url, e); return }
        if (/^https?:/.test(e.url)) Quickshell.execDetached(["xdg-open", e.url])
        else searchProvider(e.title + " " + e.artist)
    }
    // OpenUri only loads the track in some players (YouTube Music opens the page paused):
    // keep pressing Play until that track is the one playing, for up to ~10 s.
    property var pending: null
    function openAndPlay(uri, e) {
        pending = { player: player, title: e.title, tries: 0 }
        player.openUri(uri)
        playPending.restart()
    }
    Timer {
        id: playPending
        interval: 600
        repeat: true
        onTriggered: {
            const j = root.pending, p = j ? j.player : null
            if (!p || ++j.tries > 16) { root.pending = null; stop(); return }
            const loaded = String(p.trackTitle || "") === j.title || j.tries > 8   // titles may differ slightly: give up matching
            if (!loaded) return
            if (p.isPlaying) { root.pending = null; stop(); return }
            if (p.canPlay) p.play(); else if (p.canTogglePlaying) p.togglePlaying()
        }
    }
    // Search the music service: inside Spotify when it is the player, otherwise YouTube Music in the browser.
    function searchProvider(q) {
        q = String(q).trim()
        if (!q) return
        if (supports("spotify")) player.openUri("spotify:search:" + encodeURIComponent(q))
        else Quickshell.execDetached(["xdg-open", "https://music.youtube.com/search?q=" + encodeURIComponent(q)])
    }

    // ── equalizer level (real output peak; only measured while something plays and the bars are shown) ──
    property real level: 0
    PwNodePeakMonitor {
        id: peakMon
        node: Audio.sink
        enabled: root.playing && Settings.showEqualizer && Config.showPlayer
    }
    Timer {
        interval: 66                                  // ~15 Hz is enough for bars that animate between samples
        repeat: true
        running: peakMon.enabled
        onTriggered: root.level = Math.min(1, peakMon.peak * 1.6)
        onRunningChanged: if (!running) root.level = 0
    }

    // Position ticks: one cheap re-read per second while playing and visible somewhere.
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.playing && root.consumers > 0
        onTriggered: { if (root.player) root.player.positionChanged(); root.sync() }
    }
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged() { root.length = 0; root.sync(); rememberSoon.restart(); if (root.useYtm && root.consumers > 0) ytmSoon.restart() }
        function onTrackTitleChanged() { rememberSoon.restart() }
        function onPositionChanged() { if (!root.playing) root.sync() }
        function onLengthChanged() { root.sync() }
    }
    onPlayerChanged: { length = 0; sync(); rememberSoon.restart() }
    Timer { id: rememberSoon; interval: 1500; onTriggered: root.remember() }   // metadata arrives in pieces
    Timer { id: ytmSoon; interval: 800; onTriggered: root.ytmRefresh() }
    onConsumersChanged: if (consumers > 0) ytmRefresh()

    FileView {
        path: Settings.ready ? Settings.dir + "/media-history.json" : ""
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        adapter: JsonAdapter {
            id: store
            property var tracks: []
        }
    }
}
