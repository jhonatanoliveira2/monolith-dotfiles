pragma Singleton
import QtQuick
import "../core"
import Quickshell
import Quickshell.Services.Pipewire

// PipeWire through Quickshell's native service (no pactl / wpctl polling).
Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool ready: sink !== null && sink !== undefined && sink.audio !== null && sink.audio !== undefined
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0

    // the effect chains' own nodes (monolith_*: AudioFx / MicFx / mic test) stay out of every list: with the
    // effects on, the lists show the physical devices and picking one retargets the chain (setDefault)
    function own(n) { return String(n.name || "").indexOf("monolith_") >= 0 }
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio && !own(n))
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && !own(n))
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink && n.audio && !own(n))
    // applications capturing audio (the shell's own level meters are left out)
    readonly property var recorders: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio && !own(n) && String((n.properties || {})["application.name"] || "").toLowerCase() !== "quickshell")
    // the physical device in use (the chain's target while the effects are on)
    readonly property var outDevice: AudioFx.active ? (sinks.find(n => n.name === AudioFx.target) || sink) : sink
    readonly property var inDevice: MicFx.active ? (sources.find(n => n.name === MicFx.target) || source) : source
    function isCurrent(node) { return !!node && (node === (node.isSink ? outDevice : inDevice)) }

    // bind only audio devices and streams (video / MIDI nodes stay unbound)
    PwObjectTracker { objects: root.sinks.concat(root.sources, root.streams, root.recorders) }

    function label(node) {
        if (!node) return ""
        return node.description || node.nickname || node.name
    }
    function appName(node) {
        const p = node.properties || {}
        return p["application.name"] || node.nickname || node.name
    }
    function glyph() {
        if (muted || (ready && volume <= 0.001)) return Theme.glyph.volMuted
        const d = outDevice ? String(outDevice.description || "").toLowerCase() : ""
        if (d.indexOf("head") >= 0 || d.indexOf("bluez") >= 0) return Theme.glyph.headphone
        return volume < 0.35 ? Theme.glyph.volLow : Theme.glyph.vol
    }
    function setVolume(v) { if (ready) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1, v)) } }
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted }
    function nudge(deltaPct) { setVolume(volume + deltaPct / 100) }
    function setDefault(node) {
        if (!node) return
        if (node.isSink && AudioFx.active) { AudioFx.setTarget(node.name); return }
        if (!node.isSink && MicFx.active) { MicFx.setTarget(node.name); return }
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }
    function toggleMic() { if (source && source.audio) source.audio.muted = !source.audio.muted }
    function setMic(v) { if (source && source.audio) source.audio.volume = Math.max(0, Math.min(1, v)) }
}
