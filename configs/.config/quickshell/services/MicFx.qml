pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Microphone effects (Settings > Microphone): RNNoise noise suppression (noise-suppression-for-voice, LADSPA)
// and a 5-band equalizer (PipeWire builtin biquads), run by FxChain in the user unit monolith-micfx. It captures
// the physical mic (Settings.micFxSource) and exposes the virtual source "monolith_mic" (Monolith Mic), the
// default input while the effects are on.
Singleton {
    id: root

    readonly property string tag: "micfx"
    readonly property string nodeName: "monolith_mic"
    // found by checkProc: LADSPA_PATH, the FHS folders (Arch) and the Nix profiles (NixOS / Home Manager)
    property string plugin: "/usr/lib/ladspa/librnnoise_ladspa.so"
    readonly property real maxDb: 12
    readonly property var bands: [
        { label: "bq_lowshelf", freq: 100, q: 0.707 }, { label: "bq_peaking", freq: 300, q: 1.0 },
        { label: "bq_peaking", freq: 1000, q: 1.0 }, { label: "bq_peaking", freq: 3000, q: 1.0 },
        { label: "bq_highshelf", freq: 8000, q: 0.707 }
    ]
    readonly property var presets: ({
        flat: [0, 0, 0, 0, 0], voice: [-3, -1, 0, 3, 2], warm: [3, 1, 0, -1, -2],
        bright: [-2, 0, 1, 3, 4], deep: [6, 3, -1, 1, -2], basscut: [-9, -3, 0, 0, 0]
    })
    // [id, pt, en] in display order
    readonly property var presetList: [["flat", "Plano", "Flat"], ["voice", "Voz", "Voice"], ["warm", "Quente", "Warm"],
        ["bright", "Brilhante", "Bright"], ["deep", "Voz grave", "Deep voice"], ["basscut", "Sem graves", "Bass cut"]]
    property bool hasRnnoise: false
    readonly property bool noise: Settings.micNoise && hasRnnoise
    readonly property bool wanted: noise || Settings.micEq
    readonly property bool active: chain.active
    readonly property string error: chain.error
    readonly property string target: Settings.micFxSource

    function gains() {
        const g = Settings.micEqGains
        return bands.map((b, i) => g && g[i] !== undefined ? Number(g[i]) : 0)
    }
    function setGain(i, v) { const g = gains(); g[i] = v; Settings.micEqGains = g; schedule() }
    function setGains(g) { Settings.micEqGains = g.slice(); schedule() }
    function setPreset(id) { if (presets[id]) { console.log("[micfx] preset", id); Settings.micEqGains = presets[id].slice(); schedule() } }
    function presetOf() {
        const g = gains()
        for (const k in presets) if (presets[k].every((v, i) => v === g[i])) return k
        return "custom"
    }
    // the physical mic to filter: picking another input while the chain runs changes it
    function setTarget(name) {
        if (!name || name === nodeName) return
        console.log("[micfx] source ->", name)
        Settings.micFxSource = name
        if (wanted) schedule()
    }
    function physicalSource() {
        const cur = Audio.source && Audio.source.name !== nodeName ? Audio.source.name : ""
        if (cur !== "") return cur
        if (Settings.micFxSource !== "") return Settings.micFxSource
        const other = Audio.sources[0]
        return other ? other.name : ""
    }

    function graph() {
        const nodes = [], links = []
        if (noise) nodes.push({ text: '{ type = ladspa name = rnnoise plugin = "' + plugin + '" label = noise_suppressor_mono control = { "VAD Threshold (%)" = '
            + Settings.micNoiseLevel.toFixed(1) + ' "VAD Grace Period (ms)" = 200 "Retroactive VAD Grace (ms)" = 0 } }', inp: "Input", out: "Output" })
        if (Settings.micEq) {
            nodes.push({ text: '{ type = builtin name = hp label = bq_highpass control = { "Freq" = 80.0 "Q" = 0.707 } }', inp: "In", out: "Out" })
            const g = gains()
            bands.forEach((b, i) => nodes.push({ text: '{ type = builtin name = eq' + i + ' label = ' + b.label + ' control = { "Freq" = '
                + b.freq.toFixed(1) + ' "Q" = ' + b.q + ' "Gain" = ' + g[i].toFixed(1) + ' } }', inp: "In", out: "Out" }))
        }
        const name = t => t.match(/name = (\w+)/)[1]
        for (let i = 1; i < nodes.length; i++)
            links.push('{ output = "' + name(nodes[i - 1].text) + ':' + nodes[i - 1].out + '" input = "' + name(nodes[i].text) + ':' + nodes[i].inp + '" }')
        return "nodes = [\n" + nodes.map(n => "          " + n.text).join("\n") + "\n        ]\n        links = [ " + links.join(" ") + " ]"
    }
    function args(src) {
        console.log("[micfx] noise=" + noise + " level=" + Settings.micNoiseLevel + " eq=" + Settings.micEq + " gains=" + JSON.stringify(gains()))
        return "      node.description = \"Monolith Mic\"\n      media.name = \"Monolith Mic\"\n"
            + "      filter.graph = {\n        " + graph() + "\n      }\n"
            + "      audio.channels = 1\n      audio.position = [ MONO ]\n"
            + "      capture.props = { node.name = \"monolith_mic_capture\" node.passive = true stream.dont-remix = true"
            + (src !== "" ? " target.object = " + JSON.stringify(src) : "") + " }\n"
            + "      playback.props = { node.name = \"" + nodeName + "\" media.class = Audio/Source }\n"
    }

    function schedule() { chain.schedule() }
    function check() { checkProc.running = true }
    property bool booting: false
    // the plugin check comes first: `wanted` depends on it
    function init() {
        booting = true
        if (Settings.loaded) check(); else Settings.loadedOnce.connect(check)
    }

    FxChain {
        id: chain
        tag: root.tag
        unit: "monolith-micfx"
        nodeName: root.nodeName
        kind: "source"
        description: "Monolith microphone effects"
        conf: Settings.dir + "/micfx.conf"
        wanted: root.wanted
        makeTarget: () => { const s = root.wanted ? root.physicalSource() : Settings.micFxSource; if (root.wanted && s !== "") Settings.micFxSource = s; return s }
        makeArgs: src => root.args(src)
        paramNode: "monolith_mic_capture"
        makeStructure: () => "noise=" + root.noise + " eq=" + Settings.micEq
        makeParams: () => {
            const p = []
            if (root.noise) p.push(["rnnoise:VAD Threshold (%)", Settings.micNoiseLevel])
            if (Settings.micEq) root.gains().forEach((g, i) => p.push(["eq" + i + ":Gain", g]))
            return p
        }
    }
    Process {
        id: checkProc
        command: ["sh", "-c", 'IFS=:; for d in $LADSPA_PATH /usr/lib/ladspa /usr/lib64/ladspa "$HOME/.nix-profile/lib/ladspa" "/etc/profiles/per-user/$USER/lib/ladspa" /run/current-system/sw/lib/ladspa; do [ -f "$d/librnnoise_ladspa.so" ] && { echo "$d/librnnoise_ladspa.so"; exit 0; }; done; exit 1']
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.plugin = text.trim() }
        onExited: code => {
            root.hasRnnoise = code === 0
            console.log("[micfx] rnnoise plugin " + (root.hasRnnoise ? "found" : "missing") + ": " + root.plugin)
            if (root.booting) { root.booting = false; chain.apply() }   // no-op when the unit already runs this config
        }
    }
}
