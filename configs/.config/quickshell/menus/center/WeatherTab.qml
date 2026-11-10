import QtQuick
import "../../core"
import "../../services"
import "../../components"
import "../../settings"

// Weather tab: now, next 24 hours, 7 days, and rain / wind / atmosphere / UV / sun / air quality tiles.
// Everything comes from one cached Weather fetch (20 min); nothing polls while the tab is closed.
Column {
    id: tab
    spacing: 8
    Component.onCompleted: Weather.refresh(false)
    readonly property var loc: Qt.locale(Settings.language === "en" ? "en_US" : "pt_BR")
    property date now: new Date()
    Timer { interval: 60000; repeat: true; running: true; onTriggered: tab.now = new Date() }

    function dayName(iso, i) {
        if (i === 0) return Labels.pick(["Hoje", "Today"])
        const p = String(iso).split("-"), d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]))
        const s = loc.dayName(d.getDay(), Locale.ShortFormat).replace(".", "")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }
    function mins(hm) { const p = String(hm).split(":"); return Number(p[0]) * 60 + Number(p[1]) }
    readonly property real dayProgress: Weather.sunrise && Weather.sunset
        ? Math.max(0, Math.min(1, (now.getHours() * 60 + now.getMinutes() - mins(Weather.sunrise)) / Math.max(1, mins(Weather.sunset) - mins(Weather.sunrise)))) : 0
    readonly property string uvText: { const u = Weather.uv; return Labels.pick(u < 3 ? ["Baixo", "Low"] : u < 6 ? ["Moderado", "Moderate"] : u < 8 ? ["Alto", "High"] : u < 11 ? ["Muito alto", "Very high"] : ["Extremo", "Extreme"]) }
    readonly property string windName: { const n = Settings.language === "en" ? ["N", "NE", "E", "SE", "S", "SW", "W", "NW"] : ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]; return n[Math.round(Weather.windDir / 45) % 8] }

    // a tile: icon + title, a big value and a detail line, with optional content (bars, arrows) on the right
    component Tile: Card {
        id: t
        property string icon: ""
        property string title: ""
        property string value: ""
        property string detail: ""
        default property alias extra: side.data
        height: 84
        Txt { x: 12; y: 10; text: t.icon + "  " + t.title; color: Theme.grayMid; font.pixelSize: Theme.small }
        Txt { x: 12; y: 30; width: parent.width - side.width - 24; text: t.value; color: Theme.white; font.pixelSize: 19 }
        Txt { x: 12; y: 58; width: parent.width - side.width - 24; text: t.detail; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
        Item { id: side; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } width: childrenRect.width; height: parent.height - 24 }
    }

    // ── now ──
    Card {
        order: 0
        width: parent.width; height: 150
        topColor: Weather.isDay ? Qt.alpha(Theme.accent, 0.22) : Theme.tint(0.10)
        bottomColor: Theme.tint(0.02)
        Txt {
            id: icon
            x: 22; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: bob
            property real bob: 0
            text: Weather.ok ? Weather.glyph : Theme.g(0xf0590); font.pixelSize: 76; color: Theme.white
            // the only looping animation of the tab, a slow float
            SequentialAnimation on bob {
                running: Weather.ok; loops: Animation.Infinite
                NumberAnimation { to: -5; duration: Theme.dur(1800); easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: Theme.dur(1800); easing.type: Easing.InOutSine }
            }
        }
        Column {
            anchors { left: icon.right; leftMargin: 22; verticalCenter: parent.verticalCenter }
            spacing: 2
            Row {
                spacing: 6
                Txt { text: Weather.ok ? Weather.temp + "°" : "—"; font.pixelSize: 56; color: Theme.white; font.family: Theme.fontDot }
                Txt { anchors.top: parent.top; anchors.topMargin: 12; text: "C"; font.pixelSize: 18; color: Theme.grayMid }
            }
            Txt { text: Weather.ok ? Weather.desc : Weather.loading ? Labels.pick(["Carregando…", "Loading…"]) : (Weather.error === "place" ? Labels.pick(["Defina a cidade em Configurações › Barra", "Set the city in Settings › Bar"]) : Labels.pick(["Clima indisponível", "Weather unavailable"])); color: Theme.foreground; font.pixelSize: 15 }
            Txt { visible: Weather.ok; text: Labels.pick(["Sensação ", "Feels like "]) + Weather.feels + "°   ·   " + Theme.g(0xf062) + " " + Weather.tmax + "°  " + Theme.g(0xf063) + " " + Weather.tmin + "°"; color: Theme.grayMid; font.bold: false }
        }
        Column {
            anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 14 }
            spacing: 4
            Txt { anchors.right: parent.right; text: Theme.g(0xf041) + "  " + Weather.place; color: Theme.white }
            Txt {
                anchors.right: parent.right
                text: Weather.fetchedAt > 0 ? Labels.pick(["Atualizado ", "Updated "]) + Qt.formatTime(new Date(Weather.fetchedAt), "HH:mm") : ""
                color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
            }
        }
        Btn {
            anchors { right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 12 }
            compact: true; icon: Theme.glyph.refresh; active: Weather.loading
            onActivated: Weather.refresh(true)
        }
    }

    // ── next 24 hours ──
    Card {
        order: 1
        width: parent.width; height: 118
        readonly property int lo: Weather.hourly.length ? Math.min.apply(null, Weather.hourly.map(h => h.temp)) : 0
        readonly property int hi: Weather.hourly.length ? Math.max.apply(null, Weather.hourly.map(h => h.temp)) : 1
        id: hours
        Flickable {
            id: hf
            anchors { fill: parent; margins: 8 }
            contentWidth: hrow.width; contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            // the wheel scrolls sideways
            WheelHandler { onWheel: e => hf.contentX = Math.max(0, Math.min(hf.contentWidth - hf.width, hf.contentX - e.angleDelta.y)) }
            Row {
                id: hrow
                height: parent.height
                Repeater {
                    model: Weather.hourly
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: 56; height: hrow.height
                        Rectangle { anchors.fill: parent; radius: Theme.radius; visible: index === 0; color: Qt.alpha(Theme.accent, 0.12) }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; y: 4; text: index === 0 ? Labels.pick(["Agora", "Now"]) : modelData.hour + "h"; color: Theme.grayMid; font.pixelSize: 10 }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; y: 20; text: Weather.glyphOf(modelData.code, modelData.day); color: Theme.white; font.pixelSize: 20 }
                        // temperature as a dot on a small scale of the day's range
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 50 + 14 * (1 - (modelData.temp - hours.lo) / Math.max(1, hours.hi - hours.lo))
                            width: 6; height: 6; radius: 3; color: Theme.accent
                        }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; y: 70; text: modelData.temp + "°"; color: Theme.white; font.pixelSize: Theme.small }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; y: 86; visible: modelData.prob > 0; text: Theme.g(0xf043) + modelData.prob + "%"; color: Theme.grayMid; font.pixelSize: 9; font.bold: false }
                    }
                }
            }
        }
    }

    Row {
        width: parent.width; spacing: 8
        // ── 7 days ──
        Card {
            id: week
            order: 2
            width: (parent.width - 8) * 0.48; height: tiles.height
            readonly property int lo: Weather.daily.length ? Math.min.apply(null, Weather.daily.map(d => d.min)) : 0
            readonly property int hi: Weather.daily.length ? Math.max.apply(null, Weather.daily.map(d => d.max)) : 1
            Column {
                x: 12; y: 10; width: parent.width - 24
                spacing: 0
                Txt { height: 22; text: Theme.g(0xf073) + "  " + Labels.pick(["Próximos dias", "Next days"]); color: Theme.grayMid; font.pixelSize: Theme.small }
                Repeater {
                    model: Weather.daily
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: parent.width; height: (week.height - 42) / 7
                        Txt { width: 46; anchors.verticalCenter: parent.verticalCenter; text: tab.dayName(modelData.date, index); color: index === 0 ? Theme.white : Theme.foreground }
                        Txt { x: 48; width: 24; anchors.verticalCenter: parent.verticalCenter; text: Weather.glyphOf(modelData.code, true); color: Theme.white; font.pixelSize: 16 }
                        Txt { x: 76; width: 40; anchors.verticalCenter: parent.verticalCenter; text: modelData.prob > 0 ? modelData.prob + "%" : ""; color: Theme.grayMid; font.pixelSize: 10; font.bold: false }
                        Txt { x: 116; width: 30; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: modelData.min + "°"; color: Theme.grayMid; font.pixelSize: Theme.small }
                        // the day's range on the week's scale
                        Rectangle {
                            id: track
                            x: 152; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 152 - 36; height: 5; radius: 2.5
                            color: Theme.nothing ? "transparent" : Theme.grayDark
                            DotMeter {
                                visible: Theme.nothing; anchors.fill: parent; dot: 5
                                readonly property real span: Math.max(1, week.hi - week.lo)
                                from: (modelData.min - week.lo) / span
                                value: (modelData.max - week.lo) / span
                            }
                            Rectangle {
                                visible: !Theme.nothing
                                readonly property real span: Math.max(1, week.hi - week.lo)
                                x: track.width * (modelData.min - week.lo) / span
                                width: Math.max(5, track.width * (modelData.max - modelData.min) / span)
                                height: parent.height; radius: 2.5
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.45) }
                                    GradientStop { position: 1; color: Theme.accent }
                                }
                            }
                        }
                        Txt { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: modelData.max + "°"; color: Theme.white; font.pixelSize: Theme.small }
                    }
                }
            }
        }

        // ── details ──
        Grid {
            id: tiles
            width: (parent.width - 8) * 0.52
            columns: 2; spacing: 8
            readonly property real tw: (width - 8) / 2
            Tile {
                order: 3; width: tiles.tw
                icon: Theme.g(0xf043); title: Labels.pick(["Chuva", "Rain"])
                value: Weather.rainProb + "%"; detail: Weather.rainSum.toFixed(1) + Labels.pick([" mm hoje", " mm today"])
                Rectangle {
                    width: 8; height: parent.height; radius: 4; color: Theme.grayDark
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 4; height: parent.height * Weather.rainProb / 100; color: Theme.accent }
                }
            }
            Tile {
                order: 4; width: tiles.tw
                icon: Theme.g(0xf059d); title: Labels.pick(["Vento", "Wind"])
                value: Weather.wind + " km/h"; detail: tab.windName + "  ·  " + Labels.pick(["rajadas ", "gusts "]) + Weather.gusts
                Rectangle {
                    width: 40; height: 40; radius: 20; anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"; border.width: 1; border.color: Theme.line
                    // points where the wind blows to
                    Txt { anchors.centerIn: parent; text: Theme.g(0xf062); color: Theme.accent; font.pixelSize: 16; rotation: Weather.windDir + 180
                          Behavior on rotation { NumberAnimation { duration: Theme.dur(600); easing.type: Easing.OutCubic } } }
                }
            }
            Tile {
                order: 5; width: tiles.tw
                icon: Theme.g(0xf058e); title: Labels.pick(["Atmosfera", "Atmosphere"])
                value: Weather.humidity + "%"; detail: Weather.pressure + " hPa"
                Rectangle {
                    width: 8; height: parent.height; radius: 4; color: Theme.grayDark
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 4; height: parent.height * Weather.humidity / 100; color: Theme.accent }
                }
            }
            Tile {
                order: 6; width: tiles.tw
                icon: Theme.g(0xf0599); title: Labels.pick(["Índice UV", "UV index"])
                value: Weather.uv.toFixed(1) + "  " + tab.uvText; detail: Labels.pick(["Máx. hoje ", "Today's max "]) + Weather.uvMax.toFixed(1)
                Rectangle {
                    width: 8; height: parent.height; radius: 4; color: Theme.grayDark
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 4; height: parent.height * Math.min(1, Weather.uv / 11); color: Weather.uv >= 8 ? Theme.white : Theme.accent }
                }
            }
            Tile {
                order: 7; width: tiles.tw
                icon: Theme.g(0xf059c); title: Labels.pick(["Sol", "Sun"])
                value: Theme.g(0xf062) + " " + Weather.sunrise; detail: Theme.g(0xf063) + " " + Weather.sunset
                // the day as an arc: the sun moves along it from sunrise to sunset
                Item {
                    width: 56; height: 30; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 56; height: 56; radius: 28; color: "transparent"; border.width: 1; border.color: Theme.line; clip: false }
                    Rectangle {
                        readonly property real a: Math.PI * (1 - tab.dayProgress)
                        x: 28 + 28 * Math.cos(a) - 4; y: 28 - 28 * Math.sin(a) - 4
                        width: 8; height: 8; radius: 4; color: tab.dayProgress > 0 && tab.dayProgress < 1 ? Theme.accent : Theme.grayMid
                    }
                    clip: true
                }
            }
            Tile {
                order: 8; width: tiles.tw
                icon: Theme.g(0xf096f); title: Labels.pick(["Qualidade do ar", "Air quality"])
                value: Weather.aqi >= 0 ? Weather.aqi + " AQI" : "—"
                detail: Weather.aqiText + "  ·  PM2.5 " + Weather.pm25.toFixed(0)
                Column {
                    spacing: 2; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: 6
                        delegate: Rectangle {
                            required property int index
                            width: 8; height: 6; radius: 2
                            color: 5 - index <= Weather.aqiLevel ? (Weather.aqiLevel >= 3 ? Theme.white : Theme.accent) : Theme.grayDark
                        }
                    }
                }
            }
        }
    }
}
