import QtQuick
import QtQuick.Effects
import "../../core"
import "../../services"
import "../../components"
import "../../settings"

// Player tab: large cover, track details, seek bar, controls and lyrics (synced when available, Lyrics service).
Column {
    id: tab
    spacing: 8
    Component.onCompleted: {
        Media.consumers++; Lyrics.consumers++; Media.sync()
        shown = Lyrics.lines; swap.key = Lyrics.key
        pos = read(); settle.restart(); Qt.callLater(() => follow(false))
    }
    Component.onDestruction: { Media.consumers--; Lyrics.consumers-- }

    // Lyrics clock: the player's own position, nothing kept locally. Quickshell extrapolates it from the last
    // D-Bus report, so every read is current: it is read once per frame while playing, and right away on every
    // play / pause / seek / track event. No lead: the sung line never runs ahead of the music.
    property real pos: 0
    function read() { const p = Media.player; return p ? (p.positionSupported ? p.position : Media.position) : 0 }
    function tick() {
        const p = read(), jump = Math.abs(p - pos) > 1.5
        pos = p
        // a jump (seek, track change, reopening): straight to the right verse, even after a manual scroll
        if (jump) { hold.stop(); settle.restart(); Qt.callLater(() => follow(false)) }
    }
    FrameAnimation { running: Media.playing && Lyrics.timed && tab.shown.length > 0; onTriggered: tab.tick() }
    Connections {
        target: Media.player
        ignoreUnknownSignals: true
        function onPositionChanged() { tab.tick() }
        function onIsPlayingChanged() { tab.tick() }
        function onPlaybackStateChanged() { tab.tick() }
        function onPostTrackChanged() { tab.tick() }
    }
    Connections { target: Media; function onPlayingChanged() { tab.tick() } function onPlayerChanged() { tab.tick() } }
    // the line is looked up in the lines on screen (during a track swap they are still the old ones)
    readonly property int line: Lyrics.timed ? Lyrics.indexAt(pos, shown) : -1

    // keep the sung line a little above the middle, easing there
    onLineChanged: follow(true)
    NumberAnimation { id: scroll; target: lv; property: "contentY"; duration: Theme.dur(800); easing.type: Easing.OutCubic }
    Timer { id: hold; interval: 3500; onTriggered: tab.follow(true) }
    // right after (re)opening or a swap the delegates are still being laid out: re-centre as their sizes settle
    Timer { id: settle; interval: 900 }
    function follow(animate) {
        if (hold.running || !Lyrics.timed || !shown.length) return
        const i = Math.max(0, line), it = lv.itemAtIndex(i)
        if (!it) { lv.positionViewAtIndex(i, ListView.Center); return }
        const y = Math.max(lv.originY, Math.min(it.y + it.height / 2 - lv.height * 0.42, lv.originY + lv.contentHeight - lv.height))
        scroll.stop()
        if (animate) { scroll.to = y; scroll.start() } else lv.contentY = y
    }

    // lines on screen; a new track fades the old ones out and the new ones in (never both at once)
    property var shown: []
    Connections { target: Lyrics; function onLinesChanged() { tab.swapIn() } }
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
        ScriptAction { script: { swap.key = Lyrics.key; tab.shown = Lyrics.lines; lv.slide = 24; hold.stop(); settle.restart(); Qt.callLater(() => tab.follow(false)) } }
        ParallelAnimation {
            NumberAnimation { target: lv; property: "opacity"; to: 1; duration: Theme.dur(450); easing.type: Easing.OutCubic }
            NumberAnimation { target: lv; property: "slide"; to: 0; duration: Theme.dur(560); easing.type: Easing.OutCubic }
        }
    }

    readonly property var md: Media.player ? (Media.player.metadata || {}) : ({})
    function meta(k) { const v = md[k]; return v === undefined || v === null ? "" : Array.isArray(v) ? v.join(", ") : String(v) }
    readonly property var extra: [
        Media.player ? Theme.g(0xf144) + "  " + String(Media.player.identity || "") : "",
        meta("xesam:genre") ? Theme.g(0xf02b) + "  " + meta("xesam:genre") : "",
        meta("xesam:contentCreated") ? Theme.g(0xf073) + "  " + meta("xesam:contentCreated").slice(0, 4) : "",
        meta("xesam:trackNumber") ? "#  " + meta("xesam:trackNumber") : ""
    ].filter(s => s)

    Card {
        visible: Media.player === null
        order: 0
        width: parent.width; height: 160
        Column {
            anchors.centerIn: parent
            spacing: 8
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Theme.glyph.note; font.pixelSize: 40; color: Theme.grayMid }
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Labels.pick(["Nada tocando", "Nothing playing"]); color: Theme.foreground }
        }
    }

    Row {
        visible: Media.player !== null
        width: parent.width; spacing: 8
        readonly property int h: 470

        // ── now playing ──
        Card {
            order: 0
            width: 300; height: parent.h
            topColor: Qt.alpha(Theme.accent, 0.18); bottomColor: Theme.tint(0.03)
            CoverArt {
                id: cover
                anchors.horizontalCenter: parent.horizontalCenter
                y: 16; width: 236; height: 236; size: 472; source: Media.art
                // breathes a little while playing
                scale: Media.playing ? 1 : 0.94
                Behavior on scale { NumberAnimation { duration: Theme.dur(420); easing.type: Easing.OutBack } }
            }
            Column {
                anchors { top: cover.bottom; topMargin: 16; left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 18 }
                spacing: 3
                Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Media.title; color: Theme.white; font.pixelSize: 16 }
                Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Media.artist; color: Theme.foreground; font.bold: false }
                Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; visible: Media.album !== ""; text: Media.album; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                Item { width: 1; height: 8 }
                // seek bar: click or drag
                Item {
                    id: seek
                    width: parent.width; height: 14
                    readonly property real shown: drag.pressed ? drag.f : Media.progress
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: drag.containsMouse || drag.pressed ? 6 : 4; radius: height / 2; color: Theme.grayDark
                        Behavior on height { NumberAnimation { duration: Theme.dur(120) } }
                        Rectangle {
                            width: parent.width * seek.shown; height: parent.height; radius: parent.radius
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.5) }
                                GradientStop { position: 1; color: Theme.accent }
                            }
                        }
                    }
                    Rectangle {
                        visible: drag.containsMouse || drag.pressed
                        x: seek.width * seek.shown - 6; anchors.verticalCenter: parent.verticalCenter
                        width: 12; height: 12; radius: 6; color: Theme.white
                    }
                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: Media.length > 0
                        property real f: 0
                        onPressed: m => f = Math.max(0, Math.min(1, m.x / width))
                        onPositionChanged: m => { if (pressed) f = Math.max(0, Math.min(1, m.x / width)) }
                        onReleased: Media.seekTo(f * Media.length)
                    }
                }
                Item {
                    width: parent.width; height: 16
                    Txt { text: Media.fmt(drag.pressed ? drag.f * Media.length : Media.position); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                    Txt { anchors.right: parent.right; text: Media.length > 0 ? Media.fmt(Media.length) : "--:--"; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                }
                Item { width: 1; height: 4 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Btn { compact: true; visible: Media.canShuffle; icon: Theme.glyph.shuffle; active: Media.shuffle; onActivated: Media.setShuffle(!Media.shuffle) }
                    Btn { compact: true; icon: Theme.glyph.prev; onActivated: Media.previous() }
                    // play / pause: the big round one
                    Rectangle {
                        width: 44; height: 44; radius: 22
                        anchors.verticalCenter: parent.verticalCenter
                        color: playHov.pressed ? Qt.alpha(Theme.accent, 0.7) : Theme.accent
                        scale: playHov.containsMouse ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.dur(140) } }
                        Txt { anchors.centerIn: parent; anchors.horizontalCenterOffset: Media.playing ? 0 : 2; text: Media.playing ? Theme.glyph.pause : Theme.glyph.play; color: Theme.onAccent; font.pixelSize: 16 }
                        MouseArea { id: playHov; anchors.fill: parent; hoverEnabled: true; onClicked: Media.toggle() }
                    }
                    Btn { compact: true; icon: Theme.glyph.next; onActivated: Media.next() }
                    Btn { compact: true; visible: Media.canLoop; icon: Media.loop === "track" ? Theme.glyph.repeatOne : Theme.glyph.repeat; active: Media.loop !== "none"; onActivated: Media.cycleLoop() }
                }
            }
            // extra details: player, genre, year, track number
            Flow {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
                spacing: 12
                Repeater {
                    model: tab.extra
                    delegate: Txt { required property var modelData; text: modelData; color: Theme.grayMid; font.pixelSize: 10; font.bold: false }
                }
            }
        }

        // ── lyrics: karaoke fill word by word, the sung line centred and lit, the others dimmed by distance ──
        Card {
            order: 1
            width: parent.width - 308; height: parent.h
            clip: true
            Txt { x: 14; y: 12; text: Theme.g(0xf0c9) + "  " + Labels.pick(["Letra", "Lyrics"]); color: Theme.white }
            Txt {
                anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 12 }
                text: Lyrics.found ? Lyrics.source + (Lyrics.synced ? Labels.pick([" · sincronizada", " · synced"])
                                                   : Lyrics.estimated ? Labels.pick([" · tempo estimado", " · estimated timing"]) : "") : ""
                color: Theme.grayMid; font.pixelSize: 10; font.bold: false
            }
            Txt {
                anchors.centerIn: parent
                opacity: tab.shown.length === 0 && !swap.running ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur(300) } }
                text: Lyrics.loading ? Labels.pick(["Procurando letra…", "Looking for lyrics…"]) : Labels.pick(["Letra não encontrada", "No lyrics found"])
                color: Theme.grayMid
            }
            ListView {
                id: lv
                anchors { fill: parent; topMargin: 38; bottomMargin: 8; leftMargin: 18; rightMargin: 18 }
                clip: true
                model: tab.shown
                spacing: 12
                cacheBuffer: 2000
                boundsBehavior: Flickable.StopAtBounds
                // room to centre the first and the last lines
                header: Item { width: 1; height: lv.height * 0.4 }
                footer: Item { width: 1; height: lv.height * 0.5 }
                property real slide: 0
                transform: Translate { y: lv.slide }
                // scrolling by hand pauses the follow for a moment
                onMovementStarted: hold.restart()
                onContentHeightChanged: if (settle.running) Qt.callLater(() => tab.follow(false))
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool timed: Lyrics.timed
                    readonly property int dist: index - tab.line
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
                        spacing: 8
                        Repeater {
                            model: row.modelData.words
                            delegate: Item {
                                id: word
                                required property var modelData
                                // how much of the word has been sung, 0..1; only the sung line reads the clock
                                readonly property real f: !row.timed ? 1 : row.current
                                    ? Math.max(0, Math.min(1, (tab.pos - modelData.a) / Math.max(0.05, modelData.b - modelData.a)))
                                    : row.dist < 0 ? 1 : 0
                                width: base.implicitWidth; height: base.implicitHeight
                                Text {
                                    id: base
                                    text: word.modelData.s
                                    color: Qt.alpha(Theme.white, 0.34)
                                    font.family: Theme.font; font.pixelSize: 19; font.bold: true
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
                    TapHandler { enabled: Lyrics.synced; onTapped: Media.seekTo(row.modelData.t) }
                }
            }
            HoverScrollBar { flick: lv; visible: tab.shown.length > 0 }
        }
    }
}
