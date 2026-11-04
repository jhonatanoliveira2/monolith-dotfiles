import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../services"
import "../components"
import "../settings"

// Center menu: opens while the pointer rests on the middle of the bar (Bar.qml, Settings > Bar > center menu)
// and closes when it leaves both. Clock and date, weather, CPU / RAM / GPU and the player, with small entry
// animations. Created only while open (MenuSlot): nothing here runs or polls while it is closed, and it asks
// the Stats sampler and the media position to run only for as long as it exists.
MenuWindow {
    id: win
    menu: "center"
    panelWidth: 560
    hoverKeep: true

    Column {
        id: col
        width: parent.width
        spacing: 8
        readonly property var loc: Qt.locale(Settings.language === "en" ? "en_US" : "pt_BR")
        property date now: new Date()
        Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: col.now = new Date() }
        Component.onCompleted: { Stats.demand++; Media.consumers++; Media.sync(); Weather.refresh(false); uptime.reload() }
        Component.onDestruction: { Stats.demand--; Media.consumers-- }

        FileView { id: uptime; path: "/proc/uptime" }
        Timer { interval: 60000; repeat: true; running: true; onTriggered: uptime.reload() }
        function uptimeText() {
            const s = Number(String(uptime.text()).split(" ")[0]) || 0
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
            return (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "min"
        }

        // a card that slides and fades in, `order` steps after the menu opens
        component Card: Rectangle {
            id: card
            property int order: 0
            radius: Theme.radius
            color: Theme.tint(0.04)
            border.width: 1; border.color: Theme.line
            opacity: 0
            property real lift: 10
            transform: Translate { y: card.lift }
            Component.onCompleted: intro.start()
            SequentialAnimation {
                id: intro
                PauseAnimation { duration: Theme.dur(40 + card.order * 55) }
                ParallelAnimation {
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.dur(260); easing.type: Easing.OutCubic }
                    NumberAnimation { target: card; property: "lift"; to: 0; duration: Theme.dur(320); easing.type: Easing.OutCubic }
                }
            }
        }

        // ── clock + weather ──
        Row {
            width: parent.width; spacing: 8
            Card {
                order: 0
                width: (parent.width - 8) * 0.56; height: 132
                Column {
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Txt { text: (Settings.language === "en" ? ["Good night", "Good morning", "Good afternoon", "Good evening"] : ["Boa madrugada", "Bom dia", "Boa tarde", "Boa noite"])[Math.floor(col.now.getHours() / 6)]; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                    Row {
                        spacing: 2
                        Txt { id: big; text: Qt.formatTime(col.now, Settings.clock24 ? "HH:mm" : "h:mm"); font.pixelSize: 44; color: Theme.white }
                        Txt { y: big.baselineOffset - baselineOffset; text: Qt.formatTime(col.now, ":ss"); font.pixelSize: 18; color: Theme.grayMid }
                    }
                    Txt { text: col.loc.toString(col.now, "dddd, d MMMM yyyy"); color: Theme.foreground; font.bold: false }
                }
                // seconds: a bar that sweeps the bottom of the card once a minute
                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 1 }
                    height: 2; radius: 1; color: Theme.accent
                    width: (parent.width - 2) * (col.now.getSeconds() + 1) / 60
                    Behavior on width { enabled: col.now.getSeconds() !== 0; NumberAnimation { duration: Theme.dur(950) } }
                }
            }
            Card {
                order: 1
                width: (parent.width - 8) * 0.44; height: 132
                Txt {
                    id: wIcon
                    x: 14; y: 16 + bob
                    property real bob: 0
                    text: Weather.ok ? Weather.glyph : Theme.g(0xf0590); font.pixelSize: 40; color: Theme.white
                    SequentialAnimation on bob {
                        running: Weather.ok; loops: Animation.Infinite
                        NumberAnimation { to: -4; duration: Theme.dur(1600); easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: Theme.dur(1600); easing.type: Easing.InOutSine }
                    }
                }
                Column {
                    anchors { left: wIcon.right; leftMargin: 14; right: parent.right; rightMargin: 12; top: parent.top; topMargin: 14 }
                    spacing: 1
                    Txt { visible: Weather.ok; text: Weather.temp + "°C"; font.pixelSize: 28; color: Theme.white }
                    Txt { width: parent.width; text: Weather.ok ? Weather.desc : Weather.loading ? Labels.pick(["Carregando…", "Loading…"]) : Labels.pick(["Clima indisponível", "Weather unavailable"]); color: Theme.foreground; font.bold: false; elide: Text.ElideRight }
                    Txt { visible: Weather.ok; text: Labels.pick(["Sensação ", "Feels "]) + Weather.feels + "°  ·  " + Weather.tmin + "° / " + Weather.tmax + "°"; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                }
                Txt {
                    anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 10 }
                    visible: Weather.ok
                    text: Theme.g(0xf041) + " " + Weather.place + "   " + Theme.g(0xf043) + " " + Weather.humidity + "%   " + Theme.g(0xf072e) + " " + Weather.wind + " km/h"
                    color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false; elide: Text.ElideRight
                }
                MouseArea { anchors.fill: parent; onClicked: Weather.refresh(true) }
            }
        }

        // ── performance ──
        Card {
            order: 2
            width: parent.width; height: 118
            Row {
                id: rings
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 14
                component Gauge: Column {
                    property string label: ""
                    property real value: 0
                    property string detail: ""
                    spacing: 4
                    Ring {
                        width: 66; height: 66; value: parent.value
                        color: parent.value >= 0.85 ? Theme.white : Theme.accent
                        Txt { anchors.centerIn: parent; text: Math.round(parent.parent.value * 100) + "%"; font.pixelSize: 13; color: Theme.white }
                    }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: parent.label + (parent.detail ? "  " + parent.detail : ""); color: Theme.grayMid; font.pixelSize: 10; font.bold: false }
                }
                Gauge { label: "CPU"; value: Math.max(0, Stats.cpu) / 100; detail: Stats.cpuTemp >= 0 ? Stats.cpuTemp + "°" : "" }
                Gauge { label: "RAM"; value: Stats.ramPct / 100; detail: Stats.ramUsed + "G" }
                Gauge { visible: Stats.gpu >= 0; label: "GPU"; value: Math.max(0, Stats.gpu) / 100; detail: Stats.gpuTemp >= 0 ? Stats.gpuTemp + "°" : "" }
            }
            // CPU history
            Item {
                anchors { left: rings.right; leftMargin: 18; right: parent.right; rightMargin: 14; top: parent.top; topMargin: 14; bottom: parent.bottom; bottomMargin: 14 }
                Txt { text: Labels.pick(["Histórico da CPU", "CPU history"]); color: Theme.grayMid; font.pixelSize: 10; font.bold: false }
                Row {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: parent.height - 18
                    spacing: 1
                    Repeater {
                        model: Stats.cpuHistory
                        delegate: Rectangle {
                            required property var modelData
                            anchors.bottom: parent.bottom
                            width: Math.max(1, (parent.width - (Stats.historyLength - 1)) / Stats.historyLength)
                            height: Math.max(1, parent.height * modelData / 100)
                            radius: 1
                            color: modelData >= 85 ? Theme.white : Theme.accent
                            opacity: 0.35 + 0.65 * modelData / 100
                            Behavior on height { NumberAnimation { duration: Theme.dur(300) } }
                        }
                    }
                }
            }
        }

        // ── player ──
        Card {
            order: 3
            visible: Media.player !== null
            width: parent.width; height: 72
            CoverArt { id: cover; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 52; height: 52; size: 104; source: Media.art }
            Column {
                anchors { left: cover.right; leftMargin: 12; right: ctl.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 2
                Txt { width: parent.width; text: Media.title; color: Theme.white; elide: Text.ElideRight }
                Txt { width: parent.width; text: Media.artist; color: Theme.grayMid; font.bold: false; elide: Text.ElideRight }
                Rectangle {
                    width: parent.width; height: 3; radius: 1.5; color: Theme.grayDark
                    Rectangle { width: parent.width * Media.progress; height: parent.height; radius: 1.5; color: Theme.accent
                                Behavior on width { NumberAnimation { duration: Theme.dur(400) } } }
                }
            }
            Row {
                id: ctl
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 4
                Btn { compact: true; icon: Theme.glyph.prev; onActivated: Media.previous() }
                Btn { compact: true; icon: Media.playing ? Theme.glyph.pause : Theme.glyph.play; active: Media.playing; onActivated: Media.toggle() }
                Btn { compact: true; icon: Theme.glyph.next; onActivated: Media.next() }
            }
        }

        // ── footer ──
        Card {
            order: 4
            width: parent.width; height: 34
            Txt {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: Theme.g(0xf017) + "  " + Labels.pick(["Ligado há ", "Up "]) + col.uptimeText()
                color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
            }
            Txt {
                visible: Battery.present
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: (Battery.charging ? Theme.glyph.bolt + " " : "") + Math.round(Battery.pct) + "%"
                color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
            }
        }
    }
}
