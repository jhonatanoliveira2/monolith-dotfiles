pragma Singleton
import QtQuick
import Quickshell
import "../core"

// Output effects (Settings > Audio): 10-band equalizer, bass boost (low shelf), volume boost (pre-gain), a
// virtualizer (the music sounds farther away as it grows) and the 8D rotation (the music circles the head); see
// controls(). All PipeWire builtins, run by FxChain in the user unit monolith-audiofx. The chain exposes the
// virtual sink "monolith_out" (Monolith Audio), the default output while the effects are on, and plays into the
// physical output (Settings.audioFxTarget).
Singleton {
    id: root

    readonly property string tag: "audiofx"
    readonly property string nodeName: "monolith_out"
    readonly property real maxDb: 12
    readonly property var bands: [
        { label: "bq_lowshelf", freq: 31, q: 0.707 }, { label: "bq_peaking", freq: 62, q: 1.41 },
        { label: "bq_peaking", freq: 125, q: 1.41 }, { label: "bq_peaking", freq: 250, q: 1.41 },
        { label: "bq_peaking", freq: 500, q: 1.41 }, { label: "bq_peaking", freq: 1000, q: 1.41 },
        { label: "bq_peaking", freq: 2000, q: 1.41 }, { label: "bq_peaking", freq: 4000, q: 1.41 },
        { label: "bq_peaking", freq: 8000, q: 1.41 }, { label: "bq_highshelf", freq: 16000, q: 0.707 }
    ]
    //                                  31  62 125 250 500  1k  2k  4k  8k 16k
    readonly property var presets: ({
        flat:        [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0],
        bassboost:   [ 6,  5,  4,  2,  0,  0,  0,  0,  0,  0],
        extremebass: [12, 10,  8,  4,  0, -1, -1,  0,  0,  0],
        funk:        [ 8,  7,  3,  0, -2,  0,  2,  3,  3,  2],
        trap:        [ 9,  7,  2, -1, -2,  0,  1,  3,  4,  4],
        rock:        [ 5,  4,  2, -1, -2, -1,  2,  4,  5,  5],
        vocal:       [-3, -2, -1,  1,  3,  4,  4,  3,  1,  0],
        deephouse:   [ 6,  6,  4,  1, -1, -1,  0,  2,  2,  1],
        asmr:        [-3, -1,  1,  2,  1, -1,  0,  2,  3,  4],
        pop:         [-1,  1,  3,  4,  2,  0, -1,  1,  2,  3],
        electronic:  [ 6,  5,  1,  0, -2,  2,  1,  1,  5,  6],
        jazz:        [ 3,  2,  1,  2, -1, -1,  0,  1,  2,  3],
        classical:   [ 4,  3,  2,  1, -1, -1,  0,  2,  3,  4],
        lofi:        [ 2,  3,  2,  0, -1, -2, -3, -3, -4, -6],
        podcast:     [-6, -4, -1,  2,  3,  4,  3,  2,  0, -2],
        night:       [ 6,  4,  2,  0,  0,  0,  0,  1,  3,  4],
        treble:      [ 0,  0,  0,  0,  0,  1,  3,  5,  6,  7]
    })
    readonly property var presetList: [["flat", "Plano", "Flat"], ["bassboost", "Bass boost", "Bass boost"],
        ["extremebass", "Extreme bass", "Extreme bass"], ["funk", "Funk", "Funk"], ["trap", "Trap", "Trap"],
        ["rock", "Rock", "Rock"], ["vocal", "Vocal boost", "Vocal boost"], ["deephouse", "Deep house", "Deep house"],
        ["asmr", "ASMR", "ASMR"], ["pop", "Pop", "Pop"], ["electronic", "Eletrônica", "Electronic"], ["jazz", "Jazz", "Jazz"],
        ["classical", "Clássica", "Classical"], ["lofi", "Lo-fi", "Lo-fi"], ["podcast", "Podcast / fala", "Podcast / speech"],
        ["night", "Volume baixo (noite)", "Late night (low volume)"], ["treble", "Agudos", "Treble boost"]]
    readonly property bool wanted: Settings.audioFx
    readonly property bool active: chain.active
    readonly property string error: chain.error
    readonly property string target: Settings.audioFxTarget

    function gains() {
        const g = Settings.audioEqGains
        return bands.map((b, i) => g && g[i] !== undefined ? Number(g[i]) : 0)
    }
    function setGain(i, v) { const g = gains(); g[i] = v; Settings.audioEqGains = g; schedule() }
    function setGains(g) { Settings.audioEqGains = g.slice(); schedule() }
    function setPreset(id) { if (presets[id]) { console.log("[audiofx] preset", id); Settings.audioEqGains = presets[id].slice(); schedule() } }
    function presetOf() {
        const g = gains()
        for (const k in presets) if (presets[k].every((v, i) => v === g[i])) return k
        return "custom"
    }
    function setTarget(name) {
        if (!name || name === nodeName) return
        console.log("[audiofx] output ->", name)
        Settings.audioFxTarget = name
        if (wanted) schedule()
    }
    function physicalSink() {
        const cur = Audio.sink && Audio.sink.name !== nodeName ? Audio.sink.name : ""
        if (cur !== "") return cur
        if (Settings.audioFxTarget !== "") return Settings.audioFxTarget
        const other = Audio.sinks[0]
        return other ? other.name : ""
    }

    // Two independent effects, both 0–100 %; at 0 % every node is neutral, so the chain is transparent and every
    // change stays a live update:
    // - virtualizer (Settings.audioVirt): distance. Less direct sound, softer highs and more of a diffuse reverb.
    // - 8D rotation (Settings.audioSpin): the music narrows to mono and circles the head (equal-power pan driven by a
    //   slow sine; the far ear gets the near one low-passed and delayed; duller while it passes behind), one turn
    //   every Settings.audioSpinSpeed seconds.
    // reverb: 8 feed-forward echo stages in series (x + g·delay(x)) = 256 reflections, ~0.55 s tail, flat response;
    // different delays per side keep the tail wide. Its RMS gain (~4.5) is divided out in the wet gains.
    readonly property var revDelays: ({ L: [6.7, 13.1, 23.3, 37.1, 59.3, 89.9, 131.1, 193.7], R: [7.9, 14.9, 25.7, 41.3, 61.7, 97.1, 139.3, 199.1] })
    readonly property var revGains: [0.85, 0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5]

    // control values, shared by the config file and the live updates (FxChain.makeParams)
    function controls() {
        const clamp01 = x => Math.max(0, Math.min(1, x))
        const v = clamp01(Settings.audioVirt / 100), s = clamp01(Settings.audioSpin / 100), g = gains(), c = {}
        const rate = 1 / Math.max(2, Math.min(30, Settings.audioSpinSpeed || 8))   // turns per second
        c["lfo:Freq"] = rate
        c["lfo:Ampl"] = 0.95 * Math.sqrt(s)          // pan position: 1 ± a·sin, square-rooted per ear (√: clear at mid values)
        c["lfod:Delay (s)"] = 0.25 / rate            // a quarter turn later than fb (the sine's Phase control is ignored)
        c["fb:Freq"] = rate
        c["fb:Ampl"] = 0.4 * s                       // behind-the-head dullness: 0.4·s·(1 + sin), 0 in front
        c["fb:Offset"] = 0.4 * s
        for (const ch of ["L", "R"]) {
            c["pre_" + ch + ":Mult"] = Math.pow(10, Settings.audioBoost / 20)
            c["bass_" + ch + ":Gain"] = Settings.audioBass
            bands.forEach((b, i) => c["eq" + i + "_" + ch + ":Gain"] = g[i])
            c["nar_" + ch + ":Gain 1"] = 1 - 0.5 * s // mono at 100 % rotation
            c["nar_" + ch + ":Gain 2"] = 0.5 * s
            c["air_" + ch + ":Gain"] = -6 * v        // highs fade with distance
            c["xd_" + ch + ":Delay (s)"] = 0.0003 + 0.0004 * Math.max(s, v)
            const direct = 1 - 0.45 * v
            c["mix_" + ch + ":Gain 1"] = direct      // direct sound
            c["mix_" + ch + ":Gain 2"] = direct * (0.22 * s + 0.12 * v)   // head shadow: the other ear, low-passed and delayed
            c["mix_" + ch + ":Gain 3"] = 0.12 * v    // reverb, own side (≈ the direct level at 100 %)
            c["mix_" + ch + ":Gain 4"] = 0.035 * v   // reverb, other side
        }
        return c
    }
    function params() { const c = controls(); return Object.keys(c).map(k => [k, c[k]]) }
    function graph() {
        const nodes = [], links = []
        const f = v => Number(v).toFixed(4)
        const k = controls()
        const node = (name, label, control, config) => nodes.push("{ type = builtin name = " + name + " label = " + label
            + (config ? " config = { " + config + " }" : "") + " control = { " + Object.keys(control).map(n => '"' + n + '" = ' + f(control[n])).join(" ") + " } }")
        const link = (a, b) => links.push('{ output = "' + a + '" input = "' + b + '" }')
        const ctl = (name, ...ports) => { const o = {}; ports.forEach(p => o[p] = k[name + ":" + p]); return o }
        for (const c of ["L", "R"]) {
            const chainNames = ["pre_" + c, "bass_" + c].concat(bands.map((b, i) => "eq" + i + "_" + c))
            node("pre_" + c, "linear", { "Mult": k["pre_" + c + ":Mult"], "Add": 0 })
            node("bass_" + c, "bq_lowshelf", { "Freq": 90, "Q": 0.707, "Gain": k["bass_" + c + ":Gain"] })
            bands.forEach((b, i) => node("eq" + i + "_" + c, b.label, { "Freq": b.freq, "Q": b.q, "Gain": k["eq" + i + "_" + c + ":Gain"] }))
            for (let i = 1; i < chainNames.length; i++) link(chainNames[i - 1] + ":Out", chainNames[i] + ":In")
        }
        // shared LFOs: with φ = 2π·rate·t the source sits at x = −cos φ (right +), y = −sin φ (front +).
        // fb = b·(1 + sin φ) (0 in front, 2b behind), fbi = 1 − fb; the pan sine is delayed a quarter turn, so
        // lfod = 1 + a·sin(φ − π/2) = 1 + a·x (right ear power) and lfoi = 1 − a·x (left).
        node("lfo", "sine", { "Freq": k["lfo:Freq"], "Ampl": k["lfo:Ampl"], "Offset": 1 })
        node("lfod", "delay", ctl("lfod", "Delay (s)"), '"max-delay" = 8.0')
        node("lfoi", "linear", { "Mult": -1, "Add": 2 })
        node("fb", "sine", { "Freq": k["fb:Freq"], "Ampl": k["fb:Ampl"], "Offset": k["fb:Offset"] })
        node("fbi", "linear", { "Mult": -1, "Add": 1 })
        node("pan_L", "sqrt", {})
        node("pan_R", "sqrt", {})
        link("lfo:Out", "lfod:In"); link("lfod:Out", "lfoi:In"); link("lfoi:Out", "pan_L:In"); link("lfod:Out", "pan_R:In"); link("fb:Out", "fbi:In")
        const last = c => "eq" + (bands.length - 1) + "_" + c
        for (const c of ["L", "R"]) {
            const o = c === "L" ? "R" : "L"
            node("nar_" + c, "mixer", ctl("nar_" + c, "Gain 1", "Gain 2"))
            link(last(c) + ":Out", "nar_" + c + ":In 1"); link(last(o) + ":Out", "nar_" + c + ":In 2")
            node("pmul_" + c, "mult", {})
            link("nar_" + c + ":Out", "pmul_" + c + ":In 1"); link("pan_" + c + ":Out", "pmul_" + c + ":In 2")
            // front/back: crossfade towards a 3 kHz low-passed copy while behind
            node("dull_" + c, "bq_lowpass", { "Freq": 3000, "Q": 0.707 })
            node("fba_" + c, "mult", {}); node("fbb_" + c, "mult", {})
            node("fbs_" + c, "mixer", { "Gain 1": 1, "Gain 2": 1 })
            link("pmul_" + c + ":Out", "dull_" + c + ":In")
            link("pmul_" + c + ":Out", "fba_" + c + ":In 1"); link("fbi:Out", "fba_" + c + ":In 2")
            link("dull_" + c + ":Out", "fbb_" + c + ":In 1"); link("fb:Out", "fbb_" + c + ":In 2")
            link("fba_" + c + ":Out", "fbs_" + c + ":In 1"); link("fbb_" + c + ":Out", "fbs_" + c + ":In 2")
            node("air_" + c, "bq_highshelf", { "Freq": 3000, "Q": 0.707, "Gain": k["air_" + c + ":Gain"] })
            link("fbs_" + c + ":Out", "air_" + c + ":In")
            // head shadow: low-passed at 700 Hz and delayed 0.3–0.7 ms, mixed into the other ear
            node("xlp_" + c, "bq_lowpass", { "Freq": 700, "Q": 0.707 })
            node("xd_" + c, "delay", ctl("xd_" + c, "Delay (s)"), '"max-delay" = 0.01')
            link("air_" + c + ":Out", "xlp_" + c + ":In"); link("xlp_" + c + ":Out", "xd_" + c + ":In")
            // reverb send: 150 Hz – 5 kHz, then the echo stages
            node("rhp_" + c, "bq_highpass", { "Freq": 150, "Q": 0.707 })
            node("rlp_" + c, "bq_lowpass", { "Freq": 5000, "Q": 0.707 })
            link("air_" + c + ":Out", "rhp_" + c + ":In"); link("rhp_" + c + ":Out", "rlp_" + c + ":In")
            let prev = "rlp_" + c
            revDelays[c].forEach((ms, i) => {
                const d = "rd" + i + "_" + c, m = "rm" + i + "_" + c
                node(d, "delay", { "Delay (s)": ms / 1000 }, '"max-delay" = ' + f(ms / 1000 + 0.01))
                node(m, "mixer", { "Gain 1": 1, "Gain 2": revGains[i] })
                link(prev + ":Out", d + ":In"); link(prev + ":Out", m + ":In 1"); link(d + ":Out", m + ":In 2")
                prev = m
            })
        }
        const wet = c => "rm" + (revDelays[c].length - 1) + "_" + c
        for (const c of ["L", "R"]) {
            const o = c === "L" ? "R" : "L"
            node("mix_" + c, "mixer", ctl("mix_" + c, "Gain 1", "Gain 2", "Gain 3", "Gain 4"))
            link("air_" + c + ":Out", "mix_" + c + ":In 1"); link("xd_" + o + ":Out", "mix_" + c + ":In 2")
            link(wet(c) + ":Out", "mix_" + c + ":In 3"); link(wet(o) + ":Out", "mix_" + c + ":In 4")
        }
        return "nodes = [\n" + nodes.map(n => "          " + n).join("\n") + "\n        ]\n"
            + "        links = [\n" + links.map(l => "          " + l).join("\n") + "\n        ]\n"
            + '        inputs = [ "pre_L:In" "pre_R:In" ]\n'
            + '        outputs = [ "mix_L:Out" "mix_R:Out" ]'
    }
    function args(sink) {
        console.log("[audiofx] gains=" + JSON.stringify(gains()) + " bass=" + Settings.audioBass + "dB boost=" + Settings.audioBoost
            + "dB virtualizer=" + Settings.audioVirt + "% spin=" + Settings.audioSpin + "% every " + Settings.audioSpinSpeed + "s")
        return "      node.description = \"Monolith Audio\"\n      media.name = \"Monolith Audio\"\n"
            + "      filter.graph = {\n        " + graph() + "\n      }\n"
            + "      audio.channels = 2\n      audio.position = [ FL FR ]\n"
            + "      capture.props = { node.name = \"" + nodeName + "\" media.class = Audio/Sink }\n"
            + "      playback.props = { node.name = \"monolith_out_play\" node.passive = true stream.dont-remix = true"
            + (sink !== "" ? " target.object = " + JSON.stringify(sink) : "") + " }\n"
    }

    function schedule() { chain.schedule() }
    function init() { if (Settings.loaded) chain.apply(); else Settings.loadedOnce.connect(chain.apply) }

    FxChain {
        id: chain
        tag: root.tag
        unit: "monolith-audiofx"
        nodeName: root.nodeName
        kind: "sink"
        description: "Monolith audio effects"
        conf: Settings.dir + "/audiofx.conf"
        wanted: root.wanted
        makeTarget: () => { const s = root.wanted ? root.physicalSink() : Settings.audioFxTarget; if (root.wanted && s !== "") Settings.audioFxTarget = s; return s }
        makeArgs: sink => root.args(sink)
        makeStructure: () => "stereo-eq10-8d"
        makeParams: () => root.params()
    }
}
