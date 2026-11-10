import QtQuick
import "../core"

// Faint grid of unlit LEDs behind a surface (Nothing theme): the dot-matrix texture of cards and widgets.
// Painted once per size (a Canvas, no per-dot items).
Canvas {
    id: grid
    property real pitch: 9
    property real dot: 1.6
    property color color: Theme.white
    property real strength: 0.07
    visible: Theme.nothing
    opacity: strength
    renderStrategy: Canvas.Cooperative
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (!visible) return
        ctx.fillStyle = grid.color
        const r = dot / 2, ox = (width % pitch) / 2 + pitch / 2, oy = (height % pitch) / 2 + pitch / 2
        for (let y = oy; y < height; y += pitch)
            for (let x = ox; x < width; x += pitch) {
                ctx.beginPath(); ctx.arc(x, y, r, 0, 2 * Math.PI); ctx.fill()
            }
    }
}
