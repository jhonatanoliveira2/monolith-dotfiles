import QtQuick
import QtQuick.Effects
import Quickshell.Services.UPower
import "../core"
import "../services"
import "../settings"

// Karaoke lyrics of the current track (services/Lyrics.qml): the sung line kept near `anchorAt` of the height,
// filled word by word, with a short glow when it comes in; the others dimmed by distance. Used by the center
// menu's Player tab and the lyrics widget. While it exists it keeps Media and Lyrics running.
//
// Clock: the player's own position, nothing kept locally. Quickshell extrapolates it from the last D-Bus
// report, so every read is current: it is read once per frame while playing, and right away on every
// play / pause / seek / track event. No lead: the sung line never runs ahead of the music.
Item {
    id: kl
    property int fontSize: 19
    property int lineSpacing: 12
    property real anchorAt: 0.42                    // where the sung line sits, as a fraction of the height
    property bool seekOnClick: true
    // updates per second: 60 on a desktop (no battery) or in the performance profile, 30 in balanced / power saver
    property int maxFps: !Battery.present || PowerProfiles.profile === PowerProfile.Performance ? 60 : 30

    Component.onCompleted: {
        Media.consumers++; Lyrics.consumers++; Media.sync()
        shown = Lyrics.lines; swap.key = Lyrics.key
        pos = read(); settle.restart(); Qt.callLater(() => follow(false))
    }
    Component.onDestruction: { Media.consumers--; Lyrics.consumers-- }

    property real pos: 0
    function read() { const p = Media.player; return p ? (p.positionSupported ? p.position : Media.position) : 0 }
    function tick() {
        const p = read(), jump = Math.abs(p - pos) > 1.5
        pos = p
        // a jump (seek, track change, reopening): straight to the right verse, even after a manual scroll
        if (jump) { hold.stop(); settle.restart(); Qt.callLater(() => follow(false)) }
    }
    FrameAnimation {
        property real acc: 0
        running: Media.playing && Lyrics.timed && kl.shown.length > 0 && kl.visible
        onTriggered: {
            acc += frameTime
            if (kl.maxFps > 0 && acc < 1 / kl.maxFps) return
            acc = 0
            kl.tick()
        }
    }
    Connections {
        target: Media.player
        ignoreUnknownSignals: true
        function onPositionChanged() { kl.tick() }
        function onIsPlayingChanged() { kl.tick() }
        function onPlaybackStateChanged() { kl.tick() }
        function onPostTrackChanged() { kl.tick() }
    }
    Connections { target: Media; function onPlayingChanged() { kl.tick() } function onPlayerChanged() { kl.tick() } }
    // the line is looked up in the lines on screen (during a track swap they are still the old ones)
    readonly property int line: Lyrics.timed ? Lyrics.indexAt(pos, shown) : -1

    // keep the sung line at `anchorAt`, easing there
    onLineChanged: follow(true)
    NumberAnimation { id: scroll; target: lv; property: "contentY"; duration: Theme.dur(800); easing.type: Easing.OutCubic }
    Timer { id: hold; interval: 3500; onTriggered: kl.follow(true) }
    // right after (re)opening or a swap the delegates are still being laid out: re-centre as their sizes settle
    Timer { id: settle; interval: 900 }
    function follow(animate) {
        if (hold.running || !Lyrics.timed || !shown.length) return
        const i = Math.max(0, line), it = lv.itemAtIndex(i)
        if (!it) { lv.positionViewAtIndex(i, ListView.Center); return }
        const y = Math.max(lv.originY, Math.min(it.y + it.height / 2 - lv.height * anchorAt, lv.originY + lv.contentHeight - lv.height))
        scroll.stop()
        if (animate) { scroll.to = y; scroll.start() } else lv.contentY = y
    }

    // lines on screen; a new track fades the old ones out and the new ones in (never both at once)
    property var shown: []
    Connections { target: Lyrics; function onLinesChanged() { kl.swapIn() } }
    function swapIn() {
        // same track, re-timed (plain lyrics once the length is known): in place
        if (shown.length && Lyrics.lines.length === shown.length && swap.key === Lyrics.key) { shown = Lyrics.lines; return }
        swap.restart()
    }
    SequentialAnimation {
        id: swap
        property string key: ""
        ParallelAnimation {
            NumberAnimation { target: lv; property: "opacity"; to: 0; duration: Theme.dur(280); easing.type: Easing.InCubic }
            NumberAnimation { target: lv; property: "slide"; to: -20; duration: Theme.dur(280); easing.type: Easing.InCubic }
        }
        ScriptAction { script: { swap.key = Lyrics.key; kl.shown = Lyrics.lines; lv.slide = 24; hold.stop(); settle.restart(); Qt.callLater(() => kl.follow(false)) } }
        ParallelAnimation {
            NumberAnimation { target: lv; property: "opacity"; to: 1; duration: Theme.dur(450); easing.type: Easing.OutCubic }
            NumberAnimation { target: lv; property: "slide"; to: 0; duration: Theme.dur(560); easing.type: Easing.OutCubic }
        }
    }

    Txt {
        anchors.centerIn: parent
        width: parent.width; horizontalAlignment: Text.AlignHCenter
        opacity: kl.shown.length === 0 && !swap.running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(300) } }
        text: Media.player === null ? Labels.pick(["Nada tocando", "Nothing playing"])
            : Lyrics.loading ? Labels.pick(["Procurando letra…", "Looking for lyrics…"]) : Labels.pick(["Letra não encontrada", "No lyrics found"])
        color: Theme.grayMid
    }
    ListView {
        id: lv
        anchors.fill: parent
        clip: true
        model: kl.shown
        spacing: kl.lineSpacing
        cacheBuffer: 2000
        boundsBehavior: Flickable.StopAtBounds
        // room to bring the first and the last lines to the anchor
        header: Item { width: 1; height: lv.height * kl.anchorAt }
        footer: Item { width: 1; height: lv.height * (1 - kl.anchorAt) }
        property real slide: 0
        transform: Translate { y: lv.slide }
        // scrolling by hand pauses the follow for a moment
        onMovementStarted: hold.restart()
        onContentHeightChanged: if (settle.running) Qt.callLater(() => kl.follow(false))
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool timed: Lyrics.timed
            readonly property int dist: index - kl.line
            readonly property bool current: timed && dist === 0
            width: lv.width
            height: flow.implicitHeight
            opacity: !timed ? 0.9 : current ? 1 : Math.max(0.14, 0.66 - Math.abs(dist) * 0.13)
            Behavior on opacity { NumberAnimation { duration: Theme.dur(560); easing.type: Easing.InOutQuad } }
            scale: !timed || current ? 1 : 0.92
            transformOrigin: Item.Left
            Behavior on scale { NumberAnimation { duration: Theme.dur(600); easing.type: Easing.OutCubic } }
            // a short glow when the line comes in; the layer exists only while it lasts
            property real glow: 0
            onCurrentChanged: if (current) flare.restart()
            SequentialAnimation {
                id: flare
                NumberAnimation { target: row; property: "glow"; from: 0; to: 1; duration: Theme.dur(160); easing.type: Easing.OutQuad }
                NumberAnimation { target: row; property: "glow"; to: 0; duration: Theme.dur(1200); easing.type: Easing.InOutQuad }
            }
            layer.enabled: glow > 0.01
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: Theme.accent
                shadowBlur: 1.0; blurMax: 20
                shadowOpacity: row.glow
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                brightness: row.glow * 0.12
            }
            Flow {
                id: flow
                width: parent.width
                spacing: Math.round(kl.fontSize * 0.42)
                Repeater {
                    model: row.modelData.words
                    delegate: Item {
                        id: word
                        required property var modelData
                        // how much of the word has been sung, 0..1; only the sung line reads the clock
                        readonly property real f: !row.timed ? 1 : row.current
                            ? Math.max(0, Math.min(1, (kl.pos - modelData.a) / Math.max(0.05, modelData.b - modelData.a)))
                            : row.dist < 0 ? 1 : 0
                        width: base.implicitWidth; height: base.implicitHeight
                        Text {
                            id: base
                            text: word.modelData.s
                            color: Qt.alpha(Theme.white, 0.34)
                            font.family: Theme.font; font.pixelSize: kl.fontSize; font.bold: true
                        }
                        Item {
                            width: base.implicitWidth * word.f; height: parent.height
                            clip: true
                            Text {
                                text: word.modelData.s
                                color: Theme.white
                                font: base.font
                            }
                        }
                    }
                }
            }
            // click a line to jump there
            TapHandler { enabled: kl.seekOnClick && Lyrics.synced; onTapped: Media.seekTo(row.modelData.t) }
        }
    }
    HoverScrollBar { flick: lv; visible: kl.shown.length > 0 }
}
