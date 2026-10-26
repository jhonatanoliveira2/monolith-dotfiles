import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../core"
import "../services"
import "../components"

// Full player: cover preview (crossfade), seekable progress, transport, shuffle/loop, volume, player switcher,
// and track search (recent tracks + the music service of the current player).
MenuWindow {
    menu: "media"
    panelWidth: 400
    maxHeight: 700

    Column {
        id: col
        width: parent.width
        spacing: 8
        readonly property var p: Media.player
        property real dragPos: -1          // seconds while dragging the progress bar (-1 = not dragging)
        property string query: ""
        readonly property var results: Media.search(query)

        Component.onCompleted: { Media.consumers++; Media.sync() }
        Component.onDestruction: Media.consumers--

        Txt {
            visible: col.p === null
            width: parent.width; topPadding: 30; bottomPadding: 30
            horizontalAlignment: Text.AlignHCenter
            text: Strings.t("noPlayer"); color: Theme.grayMid; font.bold: false
        }

        // ── now playing ─────────────────────────────────────────────────
        Item {
            visible: col.p !== null
            width: parent.width; height: 132

            Image {   // dim backdrop made from the cover (no blur shader: costs nothing)
                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 64; sourceSize.height: 64
                smooth: true
                asynchronous: true
                opacity: status === Image.Ready ? 0.16 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur(400) } }
            }
            CoverArt {
                id: cover
                x: 6; anchors.verticalCenter: parent.verticalCenter
                width: 120; height: 120; size: 240
                source: Media.art
                scale: coverHover.hovered ? 1.03 : 1
                Behavior on scale { NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutCubic } }
                HoverHandler { id: coverHover }
                TapHandler { onTapped: if (col.p && col.p.canRaise) { Popups.close(); col.p.raise() } }
            }
            Column {
                anchors { left: cover.right; leftMargin: 14; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 4
                Txt {   // size follows the title length: short titles stand out, long ones still fit in two lines
                    width: parent.width; text: Media.title; color: Theme.white; maximumLineCount: 2; wrapMode: Text.Wrap
                    font.pixelSize: text.length <= 18 ? 18 : text.length <= 32 ? 16 : text.length <= 56 ? 14 : 12
                }
                Txt { width: parent.width; visible: text !== ""; text: Media.artist; color: Theme.grayLight; font.bold: false }
                Txt { width: parent.width; visible: text !== ""; text: Media.album; color: Theme.grayMid; font.bold: false; font.pixelSize: Theme.small }
                Row {
                    spacing: 8
                    topPadding: 4
                    Equalizer { running: Media.playing; level: Media.level; height: 10; color: Theme.grayMid; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: col.p ? String(col.p.identity || "") : ""; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                }
            }
        }

        // ── progress (drag or click to seek) ─────────────────────────────
        Item {
            visible: col.p !== null && Media.length > 0
            width: parent.width; height: 34
            ThinSlider {
                id: seek
                anchors { left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6; top: parent.top }
                enabled: col.p !== null && col.p.canSeek
                value: col.dragPos >= 0 ? col.dragPos / Media.length : Media.progress
                step: Media.length > 0 ? 5 / Media.length : 0.02
                onMoved: v => col.dragPos = v * Media.length
                onReleased: v => { if (col.dragPos >= 0) { Media.seekTo(col.dragPos); col.dragPos = -1 } }
            }
            Txt { anchors { left: parent.left; leftMargin: 6; bottom: parent.bottom } text: Media.fmt(col.dragPos >= 0 ? col.dragPos : Media.position); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
            Txt { anchors { right: parent.right; rightMargin: 6; bottom: parent.bottom } text: "-" + Media.fmt(Media.length - (col.dragPos >= 0 ? col.dragPos : Media.position)); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
        }

        // ── transport ───────────────────────────────────────────────────
        Row {
            visible: col.p !== null
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            component Ctl: Rectangle {
                id: c
                property string g: ""
                property bool on: false
                property bool big: false
                property bool usable: true
                signal hit()
                width: big ? 46 : 34; height: width; radius: width / 2
                opacity: usable ? 1 : 0.35
                color: m.pressed ? Theme.pressed : big ? Qt.rgba(1, 1, 1, m.containsMouse ? 0.2 : 0.12) : m.containsMouse ? Theme.hover : "transparent"
                border.width: on ? 1 : 0
                border.color: Theme.grayLight
                scale: m.pressed ? 0.92 : 1
                Behavior on scale { NumberAnimation { duration: Theme.dur(90) } }
                Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                Txt { anchors.centerIn: parent; text: c.g; font.pixelSize: c.big ? 18 : 13; color: c.on || m.containsMouse || c.big ? Theme.white : Theme.grayLight }
                MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; enabled: c.usable; onClicked: c.hit() }
            }
            Ctl { anchors.verticalCenter: parent.verticalCenter; g: Theme.glyph.shuffle; usable: Media.canShuffle; on: Media.shuffle; onHit: Media.setShuffle(!Media.shuffle) }
            Ctl { anchors.verticalCenter: parent.verticalCenter; g: Theme.glyph.prev; usable: !!col.p && (col.p.canGoPrevious || col.p.canSeek); onHit: Media.previous() }
            Ctl { anchors.verticalCenter: parent.verticalCenter; big: true; g: Media.playing ? Theme.glyph.pause : Theme.glyph.play; usable: !!col.p && col.p.canTogglePlaying; onHit: Media.toggle() }
            Ctl { anchors.verticalCenter: parent.verticalCenter; g: Theme.glyph.next; usable: !!col.p && col.p.canGoNext; onHit: Media.next() }
            Ctl {
                anchors.verticalCenter: parent.verticalCenter
                g: Media.loop === "track" ? Theme.glyph.repeatOne : Theme.glyph.repeat
                usable: Media.canLoop
                on: Media.loop !== "none"
                onHit: Media.cycleLoop()
            }
        }

        Txt {   // YouTube Music without its API server: say why shuffle / repeat are disabled
            visible: col.p !== null && Media.useYtm && !Media.ytmOk
            width: parent.width; leftPadding: 10; rightPadding: 10
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; elide: Text.ElideNone
            text: (Media.ytmError ? Media.ytmError + " — " : "") + Strings.t("ytmHint"); color: Theme.grayMid; font.bold: false; font.pixelSize: Theme.small
        }

        // ── volume ──────────────────────────────────────────────────────
        Item {
            visible: col.p !== null && Media.hasVolume
            width: parent.width; height: 30
            Txt { id: vi; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } width: 20; text: Media.volume < 0.01 ? Theme.glyph.volMuted : Theme.glyph.vol; color: Theme.grayMid }
            ThinSlider { anchors { left: vi.right; leftMargin: 8; right: vp.left; rightMargin: 10; verticalCenter: parent.verticalCenter } value: Media.volume; onMoved: v => Media.setVolume(v) }
            Txt { id: vp; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } width: 40; horizontalAlignment: Text.AlignRight; text: Math.round(Media.volume * 100) + "%"; color: Theme.grayMid }
        }

        // ── players ─────────────────────────────────────────────────────
        Flow {
            visible: Media.players.length > 1
            width: parent.width; spacing: 4
            Repeater {
                model: Media.players
                delegate: Btn {
                    required property var modelData
                    compact: true
                    icon: modelData.isPlaying ? Theme.glyph.play : ""
                    text: String(modelData.identity || "?")
                    active: modelData === Media.player
                    onActivated: Media.choose(modelData)
                }
            }
        }

        // ── search ──────────────────────────────────────────────────────
        Rectangle {
            width: parent.width; height: 32; radius: Theme.radius
            color: "transparent"; border.width: 1; border.color: q.activeFocus ? Theme.grayLight : Theme.line
            Behavior on border.color { ColorAnimation { duration: Theme.dur(120) } }
            Txt { id: mag; x: 10; width: 16; height: parent.height; text: Theme.glyph.search; color: Theme.grayMid }
            TextInput {
                id: q
                anchors { left: mag.right; leftMargin: 6; right: parent.right; rightMargin: 10; top: parent.top; bottom: parent.bottom }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.white; selectionColor: Theme.grayMid
                font.family: Theme.font; font.pixelSize: Theme.fontSize
                clip: true; selectByMouse: true
                onTextChanged: col.query = text
                Keys.onReturnPressed: { Media.searchProvider(text); Popups.close() }
                Keys.onEscapePressed: { if (text !== "") text = ""; else Popups.close() }
                Txt { visible: q.text === ""; anchors.fill: parent; text: Strings.t("searchTracks"); color: Theme.grayMid; font.bold: false }
            }
        }
        Section { width: parent.width; text: col.query ? Strings.t("results") : Strings.t("recent"); visible: col.results.length > 0 }
        Txt {
            visible: col.query !== "" && col.results.length === 0
            width: parent.width; leftPadding: 10
            text: Strings.t("searchHint"); color: Theme.grayMid; font.bold: false; font.pixelSize: Theme.small; wrapMode: Text.Wrap
        }
        Repeater {
            model: col.results.slice(0, 8)
            delegate: Rectangle {
                required property var modelData
                width: col.width; height: 40; radius: Theme.radius
                color: rm.pressed ? Theme.pressed : rm.containsMouse ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.dur(100) } }
                CoverArt { id: th; x: 6; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; size: 60; source: modelData.cover || modelData.art || "" }
                Column {
                    anchors { left: th.right; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    Txt { width: parent.width; text: modelData.title; color: modelData.title === Media.title ? Theme.white : Theme.grayLight }
                    Txt { width: parent.width; text: [modelData.artist, modelData.player].filter(x => x).join("  ·  "); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; onClicked: Media.replay(modelData) }
            }
        }
    }
}
