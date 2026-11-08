import QtQuick
import QtQuick.Effects
import "../core"

// Album art with a crossfade between covers: the new image loads in the back layer and fades in once ready.
// Falls back to a music glyph. `size` is the decode size (keeps memory low for big covers).
Item {
    id: root
    property string source: ""
    property int size: 64
    property string fallback: Theme.glyph.note
    property bool frontIsA: true
    readonly property Image front: frontIsA ? a : b
    readonly property Image back: frontIsA ? b : a
    readonly property bool hasArt: front.status === Image.Ready && String(front.source) !== ""

    onSourceChanged: {
        if (source === String(front.source)) return
        back.source = source
        if (source === "") swap()
    }
    function swap() { frontIsA = !frontIsA }
    function settled(img) { if (img === back && (img.status === Image.Ready || img.status === Image.Error)) swap() }

    Rectangle {
        anchors.fill: parent
        color: Theme.tint(0.06)
        Text {
            anchors.centerIn: parent
            visible: !root.hasArt
            text: root.fallback
            color: Theme.grayMid
            font.family: Theme.font
            font.pixelSize: Math.max(10, root.height * 0.42)
        }
    }

    // Nothing theme: the art in greys (monochrome) and, on large covers, seen through a matrix of LEDs
    property bool dots: Theme.nothing && width >= 48
    Item {
        id: art
        anchors.fill: parent
        layer.enabled: Theme.nothing && Nothing.monochrome
        layer.effect: MultiEffect { saturation: -1; contrast: 0.1 }
    Image {
        id: a
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.size
        sourceSize.height: root.size
        opacity: root.frontIsA && status === Image.Ready ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(320); easing.type: Easing.InOutQuad } }
        onStatusChanged: root.settled(a)
    }
    Image {
        id: b
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.size
        sourceSize.height: root.size
        opacity: !root.frontIsA && status === Image.Ready ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(320); easing.type: Easing.InOutQuad } }
        onStatusChanged: root.settled(b)
    }
    }
    DotMask {
        anchors.fill: parent
        visible: root.dots && root.hasArt
        pitch: Math.max(3, Math.round(root.width / 28))
        color: Theme.p.panel
    }

    Rectangle {   // hairline frame on top of the art
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Theme.line
    }
}
