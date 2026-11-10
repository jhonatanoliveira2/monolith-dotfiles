import QtQuick
import "../../core"
import "../../services"
import "../../components"
import "../../settings"

// Player tab: large cover, track details, seek bar, controls and karaoke lyrics (components/KaraokeLyrics.qml).
Column {
    id: tab
    spacing: 8
    Component.onCompleted: { Media.consumers++; Media.sync() }
    Component.onDestruction: Media.consumers--


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
                        width: parent.width; height: drag.containsMouse || drag.pressed ? 6 : 4; radius: height / 2
                        color: Theme.nothing ? "transparent" : Theme.grayDark
                        Behavior on height { NumberAnimation { duration: Theme.dur(120) } }
                        DotMeter { visible: Theme.nothing; anchors.fill: parent; dot: 5; value: seek.shown }
                        Rectangle {
                            visible: !Theme.nothing
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
                    spacing: 10
                    Btn { compact: true; visible: Media.canShuffle; icon: Theme.glyph.shuffle; active: Media.shuffle; onActivated: Media.setShuffle(!Media.shuffle) }
                    Btn { compact: true; icon: Theme.glyph.prev; onActivated: Media.previous() }
                    // play / pause: a lit disc inside a thin ring that shows the track progress
                    Item {
                        id: play
                        width: 60; height: 60
                        anchors.verticalCenter: parent.verticalCenter
                        scale: playHov.pressed ? 0.92 : playHov.containsMouse ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutBack } }
                        // halo while playing (static: no looping animation)
                        Rectangle {
                            anchors.centerIn: parent
                            width: 58; height: 58; radius: 29
                            color: Qt.alpha(Theme.accent, Media.playing ? 0.16 : 0)
                            Behavior on color { ColorAnimation { duration: Theme.dur(400) } }
                        }
                        Ring {
                            anchors.fill: parent
                            thickness: 2.5
                            value: Media.progress
                            color: Theme.accent
                            trackColor: Qt.alpha(Theme.white, 0.08)
                        }
                        // depth: a soft shadow under the disc
                        Rectangle { x: 9; y: 11; width: 42; height: 42; radius: 21; color: "#000000"; opacity: 0.28 }
                        Rectangle {
                            id: disc
                            anchors.centerIn: parent
                            width: 44; height: 44; radius: 22
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.lighter(Theme.accent, playHov.containsMouse ? 1.35 : 1.22) }
                                GradientStop { position: 1; color: Theme.accent }
                            }
                            // sheen on the upper half
                            Rectangle {
                                x: 4; y: 2; width: parent.width - 8; height: parent.height * 0.5; radius: height / 2
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.alpha(Theme.white, 0.28) }
                                    GradientStop { position: 1; color: Qt.alpha(Theme.white, 0) }
                                }
                            }
                            // the two glyphs cross-fade with a small turn
                            Txt {
                                anchors.centerIn: parent; anchors.horizontalCenterOffset: 2
                                text: Theme.glyph.play; color: Theme.onAccent; font.pixelSize: 17
                                opacity: Media.playing ? 0 : 1; scale: Media.playing ? 0.5 : 1; rotation: Media.playing ? -90 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.dur(200) } }
                                Behavior on scale { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutBack } }
                                Behavior on rotation { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
                            }
                            Txt {
                                anchors.centerIn: parent
                                text: Theme.glyph.pause; color: Theme.onAccent; font.pixelSize: 17
                                opacity: Media.playing ? 1 : 0; scale: Media.playing ? 1 : 0.5; rotation: Media.playing ? 0 : 90
                                Behavior on opacity { NumberAnimation { duration: Theme.dur(200) } }
                                Behavior on scale { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutBack } }
                                Behavior on rotation { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
                            }
                        }
                        MouseArea { id: playHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Media.toggle() }
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
            KaraokeLyrics {
                anchors { fill: parent; topMargin: 38; bottomMargin: 8; leftMargin: 18; rightMargin: 18 }
            }
        }
    }
}
