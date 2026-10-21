import QtQuick
import Quickshell.Services.Mpris
import "../core"
import "../components"

// Collapsed: "<symbol> title". On hover it expands: previous / play-pause / next + progress and time.
Item {
    id: root

    readonly property var player: pick()
    readonly property bool expanded: hover.hovered
    readonly property bool playing: player !== null && player.isPlaying

    // Local values used by the UI (protect against the length == position fallback)
    property real displayPosition: 0
    property real displayLength: 0

    function pick() {
        const l = Mpris.players.values
        let paused = null
        for (let i = 0; i < l.length; i++) {
            if (l[i].isPlaying)
                return l[i]
            if (!paused && l[i].playbackState === MprisPlaybackState.Paused)
                paused = l[i]
        }
        return paused
    }

    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    function bar(pos, len) {
        const cells = 8
        let idx = Math.min(cells - 1, Math.floor(pos * cells / len))
        let out = ""
        for (let i = 0; i < cells; i++)
            out += i < idx ? "━" : i === idx ? "●" : "─"
        return out
    }

    // Safely update position + length
    function sync() {
        if (!player) {
            displayPosition = 0
            displayLength = 0
            return
        }

        const pos = player.position
        const len = player.length

        displayPosition = pos

        // Only accept length if it is reasonable.
        // After seek many players set lengthSupported=false and length
        // starts returning the current position → 0:34/0:34.
        if (len > pos + 1.0) {
            displayLength = len
        } else if (displayLength <= 0 && len > 0) {
            // first time / track without length yet
            displayLength = len
        }
        // otherwise keep the last good length
    }

    readonly property string title: {
        if (!player)
            return ""
        const t = String(player.trackTitle || player.identity || "")
        return t.length > Config.titleMax
            ? t.slice(0, Config.titleMax - 1) + "…"
            : t
    }

    readonly property string progress: {
        if (!player)
            return ""
        const pos = displayPosition
        const len = displayLength
        return len > 0
            ? bar(pos, len) + "  " + fmt(pos) + "/" + fmt(len)
            : fmt(pos)
    }

    // Reset cache when the player changes
    onPlayerChanged: sync()

    // Also reset when the track changes (title changes)
    onTitleChanged: {
        displayLength = 0          // force accepting the next good length
        sync()
    }

    visible: Config.showPlayer && player !== null
    implicitHeight: parent ? parent.height : Theme.barHeight
    implicitWidth: lead.implicitWidth + ctl.width

    HoverHandler {
        id: hover
    }

    WheelHandler {
        enabled: root.player !== null && root.player.canSeek
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            if (!root.player || !root.player.canSeek)
                return

            const delta = event.angleDelta.y
            if (delta === 0)
                return

            root.player.seek(delta > 0 ? 5 : -5)

            // Update the UI on the next frame (after Seeked arrives)
            Qt.callLater(root.sync)

            event.accepted = true
        }
    }

    // Continuous update (only reads, never emits signals)
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.expanded && root.playing && root.player !== null
        onTriggered: root.sync()
    }

    BarItem {
        id: lead
        height: parent.height

        onClicked: m => {
            if (root.player && root.player.canTogglePlaying)
                root.player.togglePlaying()
        }

        Txt {
            text: root.playing ? Theme.glyph.note : Theme.glyph.pause
            color: root.playing ? Theme.grayLight : Theme.grayMid
        }

        Txt {
            text: root.title
            color: root.playing ? Theme.grayLight : Theme.grayMid
        }
    }

    Item {
        id: ctl
        anchors.left: lead.right
        height: parent.height
        width: root.expanded ? ctlRow.implicitWidth + 6 : 0
        clip: true
        opacity: root.expanded ? 1 : 0

        Behavior on width {
            NumberAnimation {
                duration: Theme.dur(180)
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.dur(140)
            }
        }

        Row {
            id: ctlRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: [
                    { g: Theme.glyph.prev, act: 0 },
                    { g: root.playing ? Theme.glyph.pause : Theme.glyph.play, act: 1 },
                    { g: Theme.glyph.next, act: 2 }
                ]

                delegate: Item {
                    required property var modelData
                    width: 24
                    height: 22

                    Rectangle {
                        anchors.fill: parent
                        color: m.containsMouse ? Theme.hover : "transparent"
                    }

                    Txt {
                        anchors.centerIn: parent
                        text: modelData.g
                        color: m.containsMouse ? Theme.foreground : Theme.grayMid
                    }

                    MouseArea {
                        id: m
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            if (!root.player)
                                return
                            if (modelData.act === 0)
                                root.player.previous()
                            else if (modelData.act === 1)
                                root.player.togglePlaying()
                            else
                                root.player.next()
                        }
                    }
                }
            }

            Txt {
                text: root.progress
                color: Theme.grayMid
                leftPadding: 6
            }
        }
    }
}
