import QtQuick
import "../core"
import "../services"
import "../components"

// Bar player. Collapsed: cover + equalizer + the track title (artists only in the media menu) with a thin progress line (click opens the media
// menu, middle click plays/pauses, right click skips, scroll seeks). Hovering slides out the miniplayer next to
// the title: elapsed / total time, shuffle, previous, play-pause, next and repeat. The miniplayer is its own
// item (outside the button's mouse area) so its controls receive their clicks; it is independent of MediaMenu.
Item {
    id: root
    property string screenName: ""
    // a vertical bar only has room for the cover and the equalizer (the title and the miniplayer are hidden)
    readonly property bool vertical: Settings.barVertical
    visible: Media.player !== null
    implicitWidth: vertical ? Theme.barSize : lead.implicitWidth + mini.width
    implicitHeight: vertical ? lead.implicitHeight : Theme.barSize

    readonly property bool menuOpen: lead.active
    // stays open briefly after the pointer leaves, so moving between title and controls never flickers
    property bool expanded: false
    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered && !root.vertical) { closeMini.stop(); openMini.restart() }
            else { openMini.stop(); closeMini.restart() }
        }
    }
    Timer { id: openMini; interval: 120; onTriggered: root.expanded = true }
    Timer { id: closeMini; interval: 450; onTriggered: root.expanded = false }

    Component.onCompleted: Media.consumers++
    Component.onDestruction: Media.consumers--

    MenuButton {
        id: lead
        menu: "media"
        screenName: root.screenName
        pad: 4
        spacing: 6

        onAlt: m => {
            if (m.button === Qt.MiddleButton) Media.toggle()
            else if (m.button === Qt.RightButton) Media.next()
        }
        property real acc: 0
        onScrolled: w => {
            acc += w.angleDelta.y
            while (Math.abs(acc) >= 120) { Media.seekBy(acc > 0 ? 5 : -5); acc -= acc > 0 ? 120 : -120 }
        }

        CoverArt {
            width: 20; height: 20; size: 40
            source: Media.art
            opacity: Media.playing ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: Theme.dur(200) } }
        }

        Item {
            width: Settings.showEqualizer ? eq.implicitWidth : glyph.implicitWidth
            height: root.vertical ? 16 : Theme.barSize
            Equalizer {
                id: eq
                visible: Settings.showEqualizer
                anchors.centerIn: parent
                height: 12
                running: Media.playing
                level: Media.level
                color: Theme.grayLight
            }
            Txt {
                id: glyph
                visible: !Settings.showEqualizer
                anchors.centerIn: parent
                text: Media.playing ? Theme.glyph.note : Theme.glyph.pause
                color: Media.playing ? Theme.grayLight : Theme.grayMid
            }
        }

        Item {
            visible: !root.vertical
            width: label.width
            height: Theme.barSize
            TextMetrics { id: cw; font: label.font; text: "0" }
            Txt {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                // follows the text, clamped to the min / max characters set in Settings › Bar
                width: Math.max(Config.titleMin * cw.advanceWidth, Math.min(implicitWidth, Config.titleMax * cw.advanceWidth))
                text: Media.title
                color: Media.playing || root.expanded ? Theme.grayLight : Theme.grayMid
                Behavior on color { ColorAnimation { duration: Theme.dur(200) } }
            }
            Rectangle {   // progress line
                visible: Media.length > 0
                anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 6 }
                width: parent.width; height: 1
                color: Theme.grayDark
                Rectangle {
                    width: parent.width * Media.progress; height: 1
                    color: Theme.grayLight
                    Behavior on width { NumberAnimation { duration: Theme.dur(900); easing.type: Easing.Linear } }
                }
            }
        }
    }

    // ── miniplayer (hover) ─────────────────────────────────────────────
    Item {
        id: mini
        visible: !root.vertical
        anchors.left: lead.right
        height: parent.height
        width: root.expanded && !root.menuOpen ? box.width + 4 : 0
        clip: true
        Behavior on width { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }

        Rectangle {
            id: box
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            width: ctl.implicitWidth + 12
            height: parent.height - 10
            radius: 4
            // light glass over the bar (follows its opacity setting); the bright controls keep it readable
            color: Palettes.alpha(Theme.p.panel, Math.min(0.5, Config.barOpacity * 0.6))
            border.width: 1
            border.color: Theme.line
            opacity: root.expanded && !root.menuOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }
            transform: Translate {
                x: root.expanded && !root.menuOpen ? 0 : -10
                Behavior on x { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }
            }

            Row {
                id: ctl
                anchors.centerIn: parent
                spacing: 0
                component Ctl: Item {
                    id: c
                    property string g: ""
                    property bool on: false
                    property bool usable: true
                    signal hit()
                    visible: usable
                    width: 22; height: 22
                    Rectangle { anchors.fill: parent; radius: 4; color: m.pressed ? Theme.pressed : m.containsMouse ? Theme.hover : "transparent"
                                border.width: c.on ? 1 : 0; border.color: Theme.accent }
                    Txt { anchors.centerIn: parent; text: c.g; color: m.containsMouse || c.on ? Theme.white : Theme.grayLight; font.pixelSize: 13
                          scale: m.pressed ? 0.88 : 1; Behavior on scale { NumberAnimation { duration: Theme.dur(90) } } }
                    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: c.hit() }
                }
                Txt {
                    visible: Media.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 6
                    text: Media.fmt(Media.position) + " / " + Media.fmt(Media.length)
                    color: Theme.foreground; font.pixelSize: Theme.small
                }
                Ctl { g: Theme.glyph.shuffle; usable: Media.canShuffle; on: Media.shuffle; onHit: Media.setShuffle(!Media.shuffle) }
                Ctl { g: Theme.glyph.prev; onHit: Media.previous() }
                Ctl { g: Media.playing ? Theme.glyph.pause : Theme.glyph.play; onHit: Media.toggle() }
                Ctl { g: Theme.glyph.next; onHit: Media.next() }
                Ctl { g: Media.loop === "track" ? Theme.glyph.repeatOne : Theme.glyph.repeat; usable: Media.canLoop; on: Media.loop !== "none"; onHit: Media.cycleLoop() }
            }
        }
    }
}
