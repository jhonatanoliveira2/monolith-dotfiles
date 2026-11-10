pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Lyrics of the current track (scripts/lyrics.sh: LRCLIB, NetEase, lyrics.ovh, cached on disk). Looked up only
// while something shows them (`consumers`, the center menu's Player tab) and once per track.
// Every line gets a timeline for the karaoke fill: word timestamps when the LRC has them (<mm:ss.xx>), else
// the line's time spread over its words by length; plain lyrics are spread over the track (`estimated`).
Singleton {
    id: root
    property int consumers: 0
    property bool loading: false
    property bool synced: false         // timestamps from the source
    property bool estimated: false      // plain lyrics timed by length
    readonly property bool timed: synced || estimated
    property string source: ""
    property var raw: []                // parsed: [{ t (-1 = unsynced), words: [{ s, at? }] }]
    property var lines: []              // timed: [{ t, end, s, words: [{ s, a, b }], gap }]
    property string key: ""             // track the lines belong to
    readonly property bool found: lines.length > 0

    // "Artist - Title (Official Video)" style names from video players, featurings and remaster tags
    function clean(artist, title) {
        let a = String(artist || "").replace(/\s+-\s+Topic$/i, "").replace(/VEVO$/, "").trim()
        let t = String(title || "")
        if (!a && t.indexOf(" - ") > 0) { a = t.slice(0, t.indexOf(" - ")).trim(); t = t.slice(t.indexOf(" - ") + 3) }
        t = t.replace(/\s*[\(\[][^\)\]]*(official|video|lyric|letra|audio|clipe|visualizer|remaster|feat\.?|ft\.)[^\)\]]*[\)\]]/gi, "")
             .replace(/\s+-\s+.*remaster.*$/i, "").replace(/\s+(feat\.?|ft\.)\s.*$/i, "").trim()
        return { artist: a.split(/,|&| e | x /)[0].trim(), title: t }
    }

    readonly property string wanted: consumers > 0 && Media.player !== null && Media.title !== "" ? Media.artist + "\u0001" + Media.title : ""
    // a new track: drop the old lines at once (the view fades them out), fetch when the metadata settles
    onWantedChanged: if (wanted !== "" && wanted !== key) { raw = []; lines = []; source = ""; loading = true; soon.restart() }
    Timer { id: soon; interval: 700; onTriggered: root.fetch() }

    function fetch() {
        if (wanted === "" || wanted === key) return
        const c = clean(Media.artist, Media.title)
        key = wanted
        raw = []; lines = []; source = ""; synced = false; estimated = false
        // the enabled sources (Settings > Bar > Player); none: nothing is requested
        const src = [Settings.lyricsLrclib ? "lrclib" : "", Settings.lyricsNetease ? "netease" : "", Settings.lyricsOvh ? "ovh" : ""].filter(s => s).join(",")
        if (!c.title || !src) { loading = false; return }
        loading = true
        proc.running = false
        proc.command = ["bash", Quickshell.shellPath("scripts/lyrics.sh"), c.artist, c.title, Media.album, String(Math.round(Media.length)), src]
        proc.running = true
    }

    function words(text) {
        // enhanced LRC: "<00:12.34>word <00:12.80>word"; a stamp applies to the first word after it
        const out = [], re = /<(\d+):(\d+(?:\.\d+)?)>/g
        let at, last = 0, m
        const take = seg => { for (const w of seg.split(/\s+/).filter(x => x)) { out.push(at !== undefined ? { s: w, at: at } : { s: w }); at = undefined } }
        while ((m = re.exec(text)) !== null) { take(text.slice(last, m.index)); at = Number(m[1]) * 60 + Number(m[2]); last = re.lastIndex }
        take(text.slice(last))
        return out
    }
    function parse(text) {
        const all = String(text).split("\n"), head = all.shift().split("\t")
        loading = false
        if (head[0] === "none" || head.length < 2) return
        const out = []
        if (head[1] === "synced") {
            const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g
            for (const l of all) {
                const body = l.replace(re, "").trim()
                let m
                re.lastIndex = 0
                while ((m = re.exec(l)) !== null) out.push({ t: Number(m[1]) * 60 + Number(m[2]), words: words(body) })
            }
            out.sort((a, b) => a.t - b.t)
        } else {
            for (const l of all) out.push({ t: -1, words: words(l.trim()) })
            while (out.length && !out[out.length - 1].words.length) out.pop()
            while (out.length && !out[0].words.length) out.shift()
        }
        source = head[0]; synced = head[1] === "synced"
        raw = out
        timeline()
    }

    // ── timeline ──
    readonly property real perChar: 0.1          // seconds a sung character takes, when nothing better is known
    function chars(ws) { return ws.reduce((n, w) => n + w.s.length + 1, 0) }
    // spread [T, E] over the words by length; stamped words start at their stamp
    function timeWords(ws, T, E) {
        const out = []
        let i = 0
        while (i < ws.length) {
            let j = i + 1
            while (j < ws.length && ws[j].at === undefined) j++
            const start = ws[i].at !== undefined ? ws[i].at : T
            const end = Math.max(start + 0.05, j < ws.length ? ws[j].at : E)
            const tot = ws.slice(i, j).reduce((n, w) => n + w.s.length + 1, 0)
            let a = start
            for (let k = i; k < j; k++) {
                const b = a + (end - start) * (ws[k].s.length + 1) / tot
                out.push({ s: ws[k].s, a: a, b: b })
                a = b
            }
            i = j
        }
        return out
    }
    function timeline() {
        const len = Media.length
        let src = raw
        estimated = false
        if (!synced) {
            if (!(len > 0)) { lines = raw.map(l => ({ t: -1, end: -1, s: l.words.map(w => w.s).join(" "), words: l.words.map(w => ({ s: w.s, a: -1, b: -1 })), gap: false })); return }
            // plain: spread the song (minus a short intro and outro) over the lines by length; blank lines = a pause
            const intro = Math.min(12, len * 0.07), span = len * 0.9 - intro
            const weight = l => l.words.length ? chars(l.words) : 8
            const total = raw.reduce((n, l) => n + weight(l), 0)
            let t = intro
            src = raw.map(l => { const r = { t: t, words: l.words }; t += span * weight(l) / total; return r })
            estimated = true
        }
        const out = []
        for (let i = 0; i < src.length; i++) {
            const l = src[i], next = i + 1 < src.length ? src[i + 1].t : (len > 0 ? len : l.t + 6)
            const room = Math.max(0.3, next - l.t)
            if (!l.words.length) {
                // instrumental gap: three dots that fill while it lasts (only when it is long enough to notice)
                if (room < 4) { out.push({ t: l.t, end: next, s: "", words: [], gap: false }); continue }
                out.push({ t: l.t, end: next, s: "", gap: true, words: timeWords([{ s: "•" }, { s: "•" }, { s: "•" }], l.t + 0.3, next - 0.4) })
                continue
            }
            const stamped = l.words.some(w => w.at !== undefined)
            const last = l.words[l.words.length - 1]
            // end of singing: a line rarely fills its whole slot; stamped lines end a little after their last word
            const sung = stamped ? Math.min(next, (last.at !== undefined ? last.at : l.t) + Math.max(0.5, (last.s.length + 1) * perChar * 1.5))
                                 : l.t + Math.min(room * 0.92, Math.max(1.0, chars(l.words) * perChar))
            out.push({ t: l.t, end: next, s: l.words.map(w => w.s).join(" "), words: timeWords(l.words, l.t, sung), gap: false })
        }
        lines = out
    }
    // plain lyrics depend on the track length, which can arrive after them
    Connections {
        target: Media
        function onLengthChanged() { if (root.raw.length && !root.synced) relength.restart() }
    }
    Timer { id: relength; interval: 500; onTriggered: root.timeline() }

    // index of the line being sung at `pos` seconds (-1 before the first), in `list` (default: lines)
    function indexAt(pos, list) {
        const l = list || lines
        let lo = 0, hi = l.length - 1, r = -1
        while (lo <= hi) {
            const m = (lo + hi) >> 1
            if (l[m].t <= pos) { r = m; lo = m + 1 } else hi = m - 1
        }
        return r
    }

    Process {
        id: proc
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        onExited: code => { if (code !== 0) root.loading = false }
    }
}
