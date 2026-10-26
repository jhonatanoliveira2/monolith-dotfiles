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

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink && n.audio)
    // applications capturing audio (the shell's own level meters are left out)
    readonly property var recorders: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio && String((n.properties || {})["application.name"] || "").toLowerCase() !== "quickshell")

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
        const d = ready ? String(sink.description || "").toLowerCase() : ""
        if (d.indexOf("head") >= 0 || d.indexOf("bluez") >= 0) return Theme.glyph.headphone
        return volume < 0.35 ? Theme.glyph.volLow : Theme.glyph.vol
    }
    function setVolume(v) { if (ready) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1, v)) } }
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted }
    function nudge(deltaPct) { setVolume(volume + deltaPct / 100) }
    function setDefault(node) {
        if (!node) return
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node
        else Pipewire.preferredDefaultAudioSource = node
    }
    function toggleMic() { if (source && source.audio) source.audio.muted = !source.audio.muted }
    function setMic(v) { if (source && source.audio) source.audio.volume = Math.max(0, Math.min(1, v)) }
}
