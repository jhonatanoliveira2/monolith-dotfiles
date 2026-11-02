import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../core"
import "../services"
import "../components"

// Microphone: input device, volume, mute, a live level meter (only while this page is open), noise suppression and
// equalizer (services/MicFx.qml) and the apps recording.
Column {
    id: root
    spacing: 8
    Component.onCompleted: MicFx.check()   // picks up a plugin installed from this page

    PwNodePeakMonitor { id: peak; node: Audio.source; enabled: Audio.source !== null && !Audio.micMuted }
    Item {
        width: parent.width; height: 34
        Txt { id: mi; x: 10; width: 24; height: parent.height; text: Audio.micMuted ? Theme.glyph.micOff : Theme.glyph.mic; font.pixelSize: 16 }
        Rectangle {
            anchors { left: mi.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            height: 6; radius: 3; color: Theme.grayDark
            Rectangle {
                width: parent.width * Math.min(1, peak.peak * 1.4); height: parent.height; radius: 3
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.grayMid } GradientStop { position: 1; color: test.on ? Theme.accent : Theme.white } }
                Behavior on width { NumberAnimation { duration: 80 } }
            }
        }
    }
    Txt { visible: Audio.source === null; x: 10; text: Labels.t("noMic"); color: Theme.grayMid }
    EntryList { page: "mic"; width: parent.width }
    EqCard {
        fx: MicFx
        width: parent.width
        level: peak.peak
        visible: opacity > 0
        opacity: Settings.micEq ? 1 : 0
        scale: Settings.micEq ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: Theme.dur(200) } }
        Behavior on scale { NumberAnimation { duration: Theme.dur(200); easing.type: Easing.OutCubic } }
    }
    Txt { visible: MicFx.active; x: 10; width: parent.width - 20; text: Labels.t("micFxActive"); color: Theme.grayMid; font.pixelSize: Theme.small; wrapMode: Text.Wrap }
    Txt { visible: MicFx.error !== ""; x: 10; width: parent.width - 20; text: MicFx.error; color: Theme.foreground; font.pixelSize: Theme.small; wrapMode: Text.Wrap }

    // ── mic test: pw-loopback plays the default input on the default output (so the effects are heard too) ──
    Section { width: parent.width; text: Labels.t("micTest") }
    Item {
        id: test
        property real delay: 0
        readonly property bool on: loop.running
        width: parent.width; height: 34
        Btn {
            id: testBtn
            anchors.verticalCenter: parent.verticalCenter
            enabled: Audio.source !== null
            icon: test.on ? Theme.g(0xf04d) : Theme.glyph.mic
            text: test.on ? Labels.t("micTestStop") : Labels.t("micTestStart")
            active: test.on
            onActivated: loop.running = !loop.running
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 4
            Txt { height: 26; verticalAlignment: Text.AlignVCenter; rightPadding: 4; text: Labels.t("micTestDelay"); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
            Repeater {
                model: [0, 0.3, 1]
                delegate: Btn {
                    required property real modelData
                    compact: true
                    text: modelData === 0 ? "0" : modelData + " s"
                    active: test.delay === modelData
                    onActivated: {
                        if (test.delay === modelData) return
                        test.delay = modelData
                        if (loop.running) { console.log("[mictest] delay ->", modelData, "s, restarting"); loop.running = false; restart.start() }
                    }
                }
            }
        }
        Timer { id: restart; interval: 150; onTriggered: loop.running = true }
        Timer { interval: 120000; running: loop.running; onTriggered: { console.log("[mictest] auto-stop after 2 min"); loop.running = false } }
        Process {
            id: loop
            command: ["pw-loopback", "-n", "monolith_mictest", "-d", String(test.delay),
                      "--capture-props", "node.description=\"Monolith mic test\" media.name=\"Mic test\"",
                      "--playback-props", "node.description=\"Monolith mic test\" media.name=\"Mic test\" media.role=Communication"]
            onRunningChanged: console.log("[mictest]", running ? "started (delay " + test.delay + " s, source " + (Audio.source ? Audio.source.name : "?") + ")" : "stopped")
            onExited: code => { if (code !== 0 && code !== 15) console.warn("[mictest] pw-loopback exited with code", code) }
            stderr: SplitParser { onRead: l => console.warn("[mictest]", l) }
        }
        Component.onDestruction: loop.running = false
    }
    // listening: a pulsing hint
    Txt {
        id: hint
        x: 10; width: parent.width - 20
        text: test.on ? Labels.t("micTestOn") : Labels.t("micTestHint")
        color: test.on ? Theme.accent : Theme.grayMid
        font.pixelSize: Theme.small; font.bold: false; wrapMode: Text.Wrap
        SequentialAnimation on opacity {
            running: test.on; loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: Theme.dur(700); easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: Theme.dur(700); easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) hint.opacity = 1
        }
    }

    Section { width: parent.width; text: Labels.t("inputs") }
    Repeater {
        model: Audio.sources
        delegate: ListRow {
            required property var modelData
            width: parent.width
            icon: Theme.glyph.mic; title: Audio.label(modelData)
            selected: Audio.isCurrent(modelData)
            onClicked: m => Audio.setDefault(modelData)   // with the effects on this retargets the chain
        }
    }
    Section { width: parent.width; text: Labels.t("recording") }
    Txt { visible: Audio.recorders.length === 0; x: 10; text: Labels.t("noRecording"); color: Theme.grayMid }
    Repeater {
        model: Audio.recorders
        delegate: ListRow { required property var modelData; width: parent.width; icon: Theme.glyph.mic; title: Audio.appName(modelData) }
    }
}
