import QtQuick
import "../core"
import "../services"
import "../components"

// Media widget: cover, title / artist, progress and controls of the current player.
Item {
    Component.onCompleted: { Media.consumers++; Media.sync() }
    Component.onDestruction: Media.consumers--
    Txt { visible: Media.player === null; anchors.centerIn: parent; text: Settings.language === "en" ? "Nothing playing" : "Nada tocando"; color: Theme.grayMid }
    CoverArt { id: cover; visible: Media.player !== null; anchors.verticalCenter: parent.verticalCenter; width: 72; height: 72; size: 144; source: Media.art }
    Column {
        visible: Media.player !== null
        anchors { left: cover.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 4
        Txt { width: parent.width; text: Media.title; color: Theme.white; elide: Text.ElideRight }
        Txt { width: parent.width; text: Media.artist; color: Theme.grayMid; font.bold: false; elide: Text.ElideRight }
        Rectangle {
            width: parent.width; height: 3; radius: 1.5; color: Theme.grayDark
            Rectangle { width: parent.width * Media.progress; height: parent.height; radius: 1.5; color: Theme.accent }
        }
        Row {
            spacing: 4
            Btn { compact: true; icon: Theme.glyph.prev; onActivated: Media.previous() }
            Btn { compact: true; icon: Media.playing ? Theme.glyph.pause : Theme.glyph.play; active: Media.playing; onActivated: Media.toggle() }
            Btn { compact: true; icon: Theme.glyph.next; onActivated: Media.next() }
        }
    }
}
