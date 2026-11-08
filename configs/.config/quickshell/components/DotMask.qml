import QtQuick
import "../core"

// LED-matrix mask over a picture (Nothing theme): `color` everywhere except round holes on a grid, so the
// picture shows through as dots (album covers, wallpaper previews). Painted once per size.
Canvas {
    id: m
    property real pitch: 5
    property real hole: 0.78                // hole diameter / pitch
    property color color: "#000000"
    renderStrategy: Canvas.Cooperative
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPitchChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (!visible || width <= 0 || height <= 0) return
        ctx.fillStyle = m.color
        ctx.fillRect(0, 0, width, height)
        ctx.globalCompositeOperation = "destination-out"
        const r = pitch * hole / 2, ox = (width % pitch) / 2 + pitch / 2, oy = (height % pitch) / 2 + pitch / 2
        ctx.beginPath()
        for (let y = oy; y < height; y += pitch)
            for (let x = ox; x < width; x += pitch) {
                ctx.moveTo(x + r, y)
                ctx.arc(x, y, r, 0, 2 * Math.PI)
            }
        ctx.fill()
    }
}
