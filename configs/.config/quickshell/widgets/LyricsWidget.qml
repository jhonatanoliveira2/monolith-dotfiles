import QtQuick
import "../core"
import "../services"
import "../components"

// Lyrics widget: the karaoke lyrics of the center menu's Player tab (components/KaraokeLyrics.qml) under a
// small line with the cover, title and artist. Media and Lyrics run only while it exists.
Item {
    id: root
    property real k: 1                  // size factor (WidgetHost: small / medium / large)

    Row {
        id: head
        width: parent.width
        spacing: Math.round(8 * root.k)
        visible: Media.player !== null
        CoverArt { id: cover; width: Math.round(26 * root.k); height: width; size: 96; source: Media.art }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - cover.width - parent.spacing
            text: Media.title + (Media.artist ? "  ·  " + Media.artist : "")
            color: Theme.grayMid; font.pixelSize: Math.round(Theme.small * root.k); font.bold: false
        }
    }
    KaraokeLyrics {
        anchors { fill: parent; topMargin: head.visible ? head.height + Math.round(6 * root.k) : 0 }
        fontSize: Math.round(17 * root.k)
        lineSpacing: Math.round(8 * root.k)
        anchorAt: 0.34
        // on the desktop a click would move the music by accident; seeking stays in the Player tab
        seekOnClick: false
    }
}
