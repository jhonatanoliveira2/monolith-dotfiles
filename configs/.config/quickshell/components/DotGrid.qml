import QtQuick
import "../core"

// Faint grid of unlit LEDs behind a surface (Nothing theme): the dot-matrix texture of cards and widgets.
// One pitch x pitch tile (an SVG dot, rasterised once and shared by every grid with the same look) repeated by
// the scene graph: no per-dot items, and nothing is painted again when the surface resizes or animates (the
// old Canvas drew every dot in JavaScript on each size change, ~10 000 arcs for the wallpaper picker, on every
// frame of its open animation). As before, the leftover space is split evenly, so the grid stays centred.
// `pitch` is meant to be a whole number of pixels (the tile is an image of that size).
Item {
    id: grid
    property real pitch: 9
    property real dot: 1.6
    property color color: Theme.white
    property real strength: 0.07
    visible: Theme.nothing
    opacity: strength

    // the dot's centre on a pixel corner (4, 4 in a 9 px tile): a 1.6 px dot then lights 2 x 2 pixels evenly, as
    // the Canvas did, instead of one bright pixel with a faint cross around it
    readonly property int centre: Math.floor(pitch / 2)
    readonly property string tile: "<svg xmlns='http://www.w3.org/2000/svg' width='" + pitch + "' height='" + pitch + "'>"
        + "<circle cx='" + centre + "' cy='" + centre + "' r='" + dot / 2 + "' fill='rgb("
        + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255)
        + ")' fill-opacity='" + color.a + "'/></svg>"

    Image {
        // whole tiles only, from the top left corner (the default alignment would centre a tile instead)
        x: Math.round((grid.width % grid.pitch) / 2)
        y: Math.round((grid.height % grid.pitch) / 2)
        width: Math.max(0, Math.floor(grid.width / grid.pitch) * grid.pitch)
        height: Math.max(0, Math.floor(grid.height / grid.pitch) * grid.pitch)
        fillMode: Image.Tile
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        sourceSize: Qt.size(grid.pitch, grid.pitch)
        source: grid.visible ? "data:image/svg+xml;utf8," + encodeURIComponent(grid.tile) : ""
    }
}
