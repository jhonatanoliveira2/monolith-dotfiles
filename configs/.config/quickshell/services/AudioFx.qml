pragma Singleton
import QtQuick
import Quickshell
import "../core"

// Output effects (Settings > Audio): 10-band equalizer, bass boost (low shelf), volume boost (pre-gain) and a
// headphone virtualizer (crossfeed: each ear also gets the other channel, low-passed and slightly delayed, as
// from speakers). All PipeWire builtins, run by FxChain in the user unit monolith-audiofx. The chain exposes the
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

    function graph() {
        const nodes = [], links = []
        const f = v => Number(v).toFixed(4)
        const boost = Math.pow(10, Settings.audioBoost / 20)
        const virt = Settings.audioVirt / 100
        const g = gains()
        for (const c of ["L", "R"]) {
            const chainNames = ["pre_" + c, "bass_" + c].concat(bands.map((b, i) => "eq" + i + "_" + c))
            nodes.push('{ type = builtin name = pre_' + c + ' label = linear control = { "Mult" = ' + f(boost) + ' "Add" = 0.0 } }')
            nodes.push('{ type = builtin name = bass_' + c + ' label = bq_lowshelf control = { "Freq" = 90.0 "Q" = 0.707 "Gain" = ' + f(Settings.audioBass) + ' } }')
            bands.forEach((b, i) => nodes.push('{ type = builtin name = eq' + i + '_' + c + ' label = ' + b.label
                + ' control = { "Freq" = ' + f(b.freq) + ' "Q" = ' + b.q + ' "Gain" = ' + f(g[i]) + ' } }'))
            for (let i = 1; i < chainNames.length; i++) links.push('{ output = "' + chainNames[i - 1] + ':Out" input = "' + chainNames[i] + ':In" }')
        }
        const last = c => "eq" + (bands.length - 1) + "_" + c
        let outs = [last("L") + ":Out", last("R") + ":Out"]
        if (virt > 0) {
            // crossfeed: own channel + the other one low-passed at 700 Hz and delayed (0.3–0.7 ms)
            for (const c of ["L", "R"]) {
                const o = c === "L" ? "R" : "L"
                nodes.push('{ type = builtin name = xlp_' + c + ' label = bq_lowpass control = { "Freq" = 700.0 "Q" = 0.707 } }')
                nodes.push('{ type = builtin name = xd_' + c + ' label = delay config = { "max-delay" = 0.01 } control = { "Delay (s)" = ' + f(0.0003 + 0.0004 * virt) + ' } }')
                nodes.push('{ type = builtin name = mix_' + c + ' label = mixer control = { "Gain 1" = ' + f(1 - 0.25 * virt) + ' "Gain 2" = ' + f(0.5 * virt) + ' } }')
                links.push('{ output = "' + last(c) + ':Out" input = "mix_' + c + ':In 1" }')
                links.push('{ output = "' + last(c) + ':Out" input = "xlp_' + c + ':In" }')
                links.push('{ output = "xlp_' + c + ':Out" input = "xd_' + c + ':In" }')
                links.push('{ output = "xd_' + o + ':Out" input = "mix_' + c + ':In 2" }')
            }
            outs = ["mix_L:Out", "mix_R:Out"]
        }
        return "nodes = [\n" + nodes.map(n => "          " + n).join("\n") + "\n        ]\n"
            + "        links = [\n" + links.map(l => "          " + l).join("\n") + "\n        ]\n"
            + '        inputs = [ "pre_L:In" "pre_R:In" ]\n'
            + '        outputs = [ "' + outs[0] + '" "' + outs[1] + '" ]'
    }
    function args(sink) {
        console.log("[audiofx] gains=" + JSON.stringify(gains()) + " bass=" + Settings.audioBass + "dB boost=" + Settings.audioBoost
            + "dB virtualizer=" + Settings.audioVirt + "%")
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
    }
}
