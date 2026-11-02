import QtQuick
import "../core"
import "../services"
import "../components"

// Equalizer card for an effect chain (`fx`: services/MicFx.qml or services/AudioFx.qml): vertical band sliders
// over an animated response curve, presets in a drawer. Drag a knob, scroll over a band (±1 dB) or double-click
// it (0 dB); the chain is updated on release. `level` (0..1, a live peak) makes the curve breathe.
Rectangle {
    id: root
    required property var fx
    property real level: 0
    readonly property real maxDb: fx.maxDb
    readonly property var gains: fx.gains()
    readonly property string preset: fx.presetOf()
    readonly property var presetEntry: fx.presetList.find(p => p[0] === preset)
    // gains when the page was opened: "Undo changes" goes back to them
    property var initial: []
    Component.onCompleted: initial = fx.gains()
    readonly property bool changed: initial.length > 0 && initial.some((v, i) => v !== gains[i])

    height: col.implicitHeight + 24
    radius: Theme.radius
    color: Theme.tint(0.03)
    border.width: 1; border.color: Theme.line

    Column {
        id: col
        x: 12; y: 12; width: parent.width - 24
        spacing: 10

        // presets (drawer: the current one is shown while closed)
        Drawer {
            width: parent.width
            title: Labels.pick(["Predefinições", "Presets"])
            summary: root.presetEntry ? Labels.pick([root.presetEntry[1], root.presetEntry[2]]) : Labels.pick(["Personalizado", "Custom"])
            Flow {
                width: parent.width; spacing: 4
                Repeater {
                    model: root.fx.presetList
                    delegate: Btn {
                        required property var modelData
                        compact: true
                        text: Labels.pick([modelData[1], modelData[2]])
                        active: root.preset === modelData[0]
                        onActivated: root.fx.setPreset(modelData[0])
                    }
                }
            }
        }

        Item {
            id: plot
            width: parent.width; height: 170
            readonly property int gutter: 30
            readonly property int pad: 12                 // keeps the knob inside at ±12 dB
            readonly property real colW: (width - gutter) / bands.count
            function yOf(db) { return pad + (1 - (db + root.maxDb) / (2 * root.maxDb)) * (height - 2 * pad) }
            function dbOf(y) { return Math.max(-root.maxDb, Math.min(root.maxDb, Math.round(root.maxDb - (y - pad) / (height - 2 * pad) * 2 * root.maxDb))) }

            // grid + dB scale
            Repeater {
                model: [12, 6, 0, -6, -12]
                delegate: Item {
                    required property int modelData
                    width: plot.width; height: 1
                    y: plot.yOf(modelData)
                    Txt { anchors.verticalCenter: parent.verticalCenter; width: plot.gutter - 6; horizontalAlignment: Text.AlignRight
                          text: (modelData > 0 ? "+" : "") + modelData; color: Theme.grayMid; font.pixelSize: 9; font.bold: false }
                    Rectangle { x: plot.gutter; width: parent.width - plot.gutter; height: 1
                                color: modelData === 0 ? Theme.tint(0.22) : Theme.tint(0.07) }
                }
            }

            // response curve: Catmull-Rom through the (animated) band values, filled towards 0 dB
            Canvas {
                id: curve
                x: plot.gutter; width: plot.width - plot.gutter; height: plot.height
                property real glow: 0
                Behavior on glow { NumberAnimation { duration: Theme.dur(90) } }
                onGlowChanged: requestPaint()
                onWidthChanged: requestPaint()
                Connections { target: Theme; function onAccentChanged() { curve.requestPaint() } }
                function rgba(c, a) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")" }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const pts = []
                    for (let i = 0; i < bands.count; i++) {
                        const it = bands.itemAt(i)
                        if (!it) return
                        pts.push({ x: (i + 0.5) * plot.colW, y: plot.yOf(it.shown) })
                    }
                    const all = [{ x: 0, y: pts[0].y }].concat(pts, [{ x: width, y: pts[pts.length - 1].y }])
                    const path = () => {
                        ctx.moveTo(all[0].x, all[0].y)
                        for (let i = 0; i < all.length - 1; i++) {
                            const p0 = all[Math.max(0, i - 1)], p1 = all[i], p2 = all[i + 1], p3 = all[Math.min(all.length - 1, i + 2)]
                            ctx.bezierCurveTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6, p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6, p2.x, p2.y)
                        }
                    }
                    const zero = plot.yOf(0)
                    const grad = ctx.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, rgba(Theme.accent, 0.30 + glow * 0.25))
                    grad.addColorStop(0.5, rgba(Theme.accent, 0.04))
                    grad.addColorStop(1, rgba(Theme.accent, 0.30 + glow * 0.25))
                    ctx.beginPath(); path(); ctx.lineTo(width, zero); ctx.lineTo(0, zero); ctx.closePath()
                    ctx.fillStyle = grad; ctx.fill()
                    ctx.beginPath(); path()
                    ctx.lineWidth = 2 + glow * 1.5
                    ctx.strokeStyle = rgba(Theme.accent, 0.75 + glow * 0.25)
                    ctx.stroke()
                }
            }
            Timer { interval: 60; repeat: true; running: root.visible; onTriggered: curve.glow = Math.min(1, root.level * 1.6) }

            // bands
            Repeater {
                id: bands
                model: root.fx.bands
                delegate: Item {
                    id: band
                    required property var modelData
                    required property int index
                    readonly property real gain: root.gains[index] !== undefined ? root.gains[index] : 0
                    property bool dragging: false
                    property real dragValue: 0
                    readonly property real value: dragging ? dragValue : gain
                    property real shown: value
                    Behavior on shown { enabled: !band.dragging; NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
                    onShownChanged: curve.requestPaint()
                    readonly property bool hot: ma.containsMouse || dragging

                    x: plot.gutter + index * plot.colW; width: plot.colW; height: plot.height

                    Rectangle { anchors.fill: parent; anchors.margins: 2; radius: Theme.radius; color: Theme.hover; opacity: band.hot ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } } }
                    // track
                    Rectangle {
                        id: track
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: plot.pad; width: 4; height: plot.height - 2 * plot.pad; radius: 2
                        color: Theme.grayDark
                    }
                    // fill from 0 dB to the knob
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: band.hot ? 6 : 4; radius: width / 2
                        y: Math.min(plot.yOf(0), plot.yOf(band.shown))
                        height: Math.max(2, Math.abs(plot.yOf(band.shown) - plot.yOf(0)))
                        gradient: Gradient {
                            GradientStop { position: 0; color: band.shown >= 0 ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) }
                            GradientStop { position: 1; color: band.shown >= 0 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) : Theme.accent }
                        }
                        Behavior on width { NumberAnimation { duration: Theme.dur(120) } }
                    }
                    // knob
                    Rectangle {
                        id: knob
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: plot.yOf(band.shown) - height / 2
                        width: 14; height: 14; radius: 7
                        color: band.dragging ? Theme.accent : Theme.white
                        border.width: 2; border.color: Theme.accent
                        scale: band.dragging ? 1.3 : band.hot ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                    }
                    // value bubble
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.max(0, knob.y - height - 8)
                        width: bubble.implicitWidth + 10; height: 18; radius: 4
                        color: Theme.accent
                        opacity: band.hot ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.dur(120) } }
                        Txt { id: bubble; anchors.centerIn: parent; text: (band.value > 0 ? "+" : "") + band.value + " dB"; color: Theme.onAccent; font.pixelSize: 10 }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true          // the settings page Flickable must not take the drag
                        cursorShape: Qt.SizeVerCursor
                        onPressed: m => { band.dragValue = plot.dbOf(m.y); band.dragging = true }
                        onPositionChanged: m => { if (band.dragging) band.dragValue = plot.dbOf(m.y) }
                        onReleased: { band.dragging = false; if (band.dragValue !== band.gain) root.fx.setGain(band.index, band.dragValue) }
                        onCanceled: band.dragging = false
                        onDoubleClicked: root.fx.setGain(band.index, 0)
                        onWheel: w => {
                            w.accepted = true          // scroll changes the band, not the page
                            const v = Math.max(-root.maxDb, Math.min(root.maxDb, band.gain + (w.angleDelta.y > 0 ? 1 : -1)))
                            if (v !== band.gain) root.fx.setGain(band.index, v)
                        }
                    }
                }
            }
        }

        // frequencies + gains
        Row {
            x: plot.gutter
            Repeater {
                model: root.fx.bands
                delegate: Column {
                    required property var modelData
                    required property int index
                    width: plot.colW
                    Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Theme.small
                          text: modelData.freq >= 1000 ? modelData.freq / 1000 + "k" : modelData.freq; color: Theme.foreground }
                    Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 10; font.bold: false; color: Theme.grayMid
                          text: { const g = root.gains[index] || 0; return (g > 0 ? "+" : "") + g + " dB" } }
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 4
            Btn {
                compact: true
                icon: Theme.g(0xf0e2)
                text: Labels.pick(["Desfazer alterações", "Undo changes"])
                enabled: root.changed
                opacity: root.changed ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: Theme.dur(150) } }
                onActivated: { console.log("[" + root.fx.tag + "] eq: undo changes ->", JSON.stringify(root.initial)); root.fx.setGains(root.initial) }
            }
            Btn {
                compact: true
                text: Labels.pick(["Zerar", "Reset"])
                enabled: root.preset !== "flat"
                opacity: enabled ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: Theme.dur(150) } }
                onActivated: root.fx.setPreset("flat")
            }
        }
    }
}
