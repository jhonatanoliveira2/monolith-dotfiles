import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../core"
import "../services"

// Audio spectrum (cava style) of what is playing: mirrored bars, bass in the middle, growing up and down from
// the centre line. Read from `cava` (raw ASCII output, pipewire input) while `active`; nothing runs otherwise.
// Without cava (or if it exits with an error, logged) it falls back to the output peak level of the default
// sink, shaped into bars: less detail, same look.
Item {
    id: sp
    property bool active: true
    property int bands: 18                  // cava bars; shown mirrored, so 2 * bands - 1 on screen
    property int fps: 30
    property real gap: 4
    property color color: Theme.accent

    property var values: []                 // 0..1 per band, low to high frequency
    property bool checked: false            // cava looked up (the fallback waits for it)
    property bool hasCava: false
    property bool cavaFailed: false
    readonly property bool useCava: hasCava && !cavaFailed
    Component.onCompleted: Jobs.run("spectrum", ["sh", "-c", "command -v cava"], { timeout: 5000 }, ok => { sp.hasCava = ok; sp.checked = true })
    onActiveChanged: if (!active) values = []

    // ── cava ──
    Process {
        id: cava
        running: sp.active && sp.useCava
        // the config is generated per bands / fps in the runtime dir (private to the user; never a shared /tmp, where
        // the predictable name could be a link planted by someone else): cava has no command-line options for it
        command: ["sh", "-c",
            "[ -n \"$XDG_RUNTIME_DIR\" ] || { echo 'XDG_RUNTIME_DIR is not set' >&2; exit 1; }; f=\"$XDG_RUNTIME_DIR/qs-cava-$1-$2.conf\"; printf '%s\\n' '[general]' \"bars = $1\" \"framerate = $2\" "
            + "'[input]' 'method = pipewire' '[output]' 'method = raw' 'channels = mono' 'raw_target = /dev/stdout' "
            + "'data_format = ascii' 'ascii_max_range = 100' 'bar_delimiter = 59' 'frame_delimiter = 10' "
            + "'[smoothing]' 'noise_reduction = 70' > \"$f\" && exec cava -p \"$f\"",
            "sh", String(sp.bands), String(sp.fps)]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";"), out = []
                for (let i = 0; i < sp.bands; i++) out.push(Math.min(1, (parseInt(v[i]) || 0) / 100))
                sp.values = out
            }
        }
        stderr: StdioCollector { id: cavaErr }
        onExited: code => {
            if (!sp.active || !sp.useCava) return
            console.warn("[spectrum] cava exited", code, Jobs.firstLine(cavaErr.text), "- using the peak level instead")
            sp.cavaFailed = true
        }
    }

    // ── fallback: peak level shaped into bands ──
    PwNodePeakMonitor { id: peak; node: Pipewire.defaultAudioSink; enabled: sp.active && sp.checked && !sp.useCava }
    Timer {
        interval: Math.round(1000 / sp.fps); repeat: true
        running: peak.enabled
        property real t: 0
        onTriggered: {
            t += interval / 1000
            const p = Math.min(1, peak.peak * 1.4), out = []
            for (let i = 0; i < sp.bands; i++) {
                const shape = 1 - 0.6 * i / sp.bands                                   // more energy in the bass
                const wob = 0.55 + 0.45 * Math.abs(Math.sin(t * (2.1 + i * 0.37) + i * 1.7))
                out.push(p * shape * wob)
            }
            sp.values = out
        }
    }

    // ── bars ──
    readonly property int count: bands * 2 - 1
    // Nothing theme: each bar is a column of LEDs lit outwards from the centre line, mirrored up and down
    readonly property real ledW: Math.max(2, (sp.width - sp.gap * (sp.count - 1)) / sp.count)
    readonly property int rows: Math.max(3, Math.floor((sp.height + sp.gap) / (ledW + sp.gap)) | 1)    // odd: a middle LED
    Row {
        visible: Theme.nothing
        anchors.centerIn: parent
        spacing: sp.gap
        Repeater {
            model: Theme.nothing ? sp.count : 0
            delegate: Column {
                required property int index
                readonly property int band: Math.abs(index - (sp.bands - 1))
                readonly property real v: sp.values.length > band ? sp.values[band] : 0
                readonly property int reach: Math.round(v * (sp.rows - 1) / 2)          // LEDs lit each side of the middle
                spacing: sp.gap
                Repeater {
                    model: sp.rows
                    delegate: Led {
                        required property int index
                        width: sp.ledW; height: sp.ledW
                        lit: Math.abs(index - (sp.rows - 1) / 2) <= parent.reach
                        litColor: sp.color
                    }
                }
            }
        }
    }
    Row {
        visible: !Theme.nothing
        anchors.centerIn: parent
        spacing: sp.gap
        Repeater {
            model: Theme.nothing ? 0 : sp.count
            delegate: Rectangle {
                required property int index
                readonly property int band: Math.abs(index - (sp.bands - 1))          // bass in the middle
                readonly property real v: sp.values.length > band ? sp.values[band] : 0
                width: Math.max(2, (sp.width - sp.gap * (sp.count - 1)) / sp.count)
                height: Math.max(width, v * sp.height)
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: Qt.alpha(sp.color, 0.35 + 0.65 * v)
                Behavior on height { NumberAnimation { duration: Math.round(1500 / sp.fps) } }
            }
        }
    }
}
