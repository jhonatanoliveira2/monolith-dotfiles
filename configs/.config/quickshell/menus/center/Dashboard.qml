import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"
import "../../services"
import "../../components"
import "../../settings"

// Dashboard tab: clock, calendar, profile, weather, mini performance and mini player.
Column {
    id: dash
    spacing: 8
    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: dash.now = new Date() }
    Component.onCompleted: { Stats.demand++; Media.consumers++; Media.sync(); Weather.refresh(false); session.running = true }
    Component.onDestruction: { Stats.demand--; Media.consumers-- }
    readonly property var loc: Qt.locale(Settings.language === "en" ? "en_US" : "pt_BR")
    readonly property bool en: Settings.language === "en"

    // how long this Hyprland session has been running (read once; the clock tick advances it)
    property real sessionStart: 0
    Process {
        id: session
        command: ["sh", "-c", "ps -o etimes= -p \"$(pgrep -o -x Hyprland || pgrep -o -x hyprland)\""]
        stdout: StdioCollector { onStreamFinished: { const s = Number(text.trim()); if (s > 0) dash.sessionStart = Date.now() - s * 1000 } }
    }
    function sessionText() {
        if (sessionStart <= 0) return "—"
        const s = Math.max(0, (now.getTime() - sessionStart) / 1000)
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "min"
    }

    readonly property int gap: 8
    readonly property int rowH: 216
    Row {
        width: parent.width; spacing: dash.gap

        // ── clock: hours, three dots, minutes ──
        Card {
            id: clock
            order: 0
            width: 104; height: dash.rowH
            topColor: Qt.alpha(Theme.accent, 0.16); bottomColor: Theme.tint(0.03)
            readonly property string hh: Qt.formatTime(dash.now, Settings.clock24 ? "HH" : "hh")
            Column {
                anchors.centerIn: parent
                spacing: 2
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: clock.hh; font.pixelSize: 50; color: Theme.white
                      font.family: Theme.fontDot; font.weight: Theme.nothing ? Font.Black : Font.Bold }
                // the three dots light up in turn, one per second
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 7
                    Repeater {
                        model: 3
                        delegate: Led {
                            required property int index
                            width: 7; height: 7
                            lit: dash.now.getSeconds() % 3 === index
                            litColor: Theme.accent; offColor: Theme.nothing ? Nothing.off : Theme.grayDark
                            Behavior on color { ColorAnimation { duration: Theme.dur(300) } }
                        }
                    }
                }
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(dash.now, "mm"); font.pixelSize: 50; color: Theme.grayLight
                      font.family: Theme.fontDot; font.weight: Theme.nothing ? Font.Black : Font.Bold }
            }
            Txt {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
                visible: !Settings.clock24
                text: Qt.formatTime(dash.now, "AP"); color: Theme.grayMid; font.pixelSize: Theme.small
            }
        }

        // ── calendar ──
        Card {
            id: cal
            order: 1
            width: 252; height: dash.rowH
            property int month: dash.now.getMonth()
            property int year: dash.now.getFullYear()
            function shift(d) { let m = month + d, y = year; if (m < 0) { m = 11; y-- } else if (m > 11) { m = 0; y++ } month = m; year = y }
            readonly property int first: new Date(year, month, 1).getDay()           // weekday of the 1st (0 = Sunday)
            readonly property int days: new Date(year, month + 1, 0).getDate()
            readonly property int prevDays: new Date(year, month, 0).getDate()
            Item {
                id: calHead
                x: 12; y: 8; width: parent.width - 24; height: 26
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: { const s = dash.loc.standaloneMonthName(cal.month, Locale.LongFormat); const t = s.charAt(0).toUpperCase() + s.slice(1) + "  " + cal.year; return Theme.nothing ? t.toUpperCase() : t }
                    color: Theme.white; font.letterSpacing: Theme.nothing ? 1.5 : 0
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Repeater {
                        model: [{ g: 0xf053, d: -1 }, { g: 0xf111, d: 0 }, { g: 0xf054, d: 1 }]
                        delegate: Rectangle {
                            required property var modelData
                            width: 22; height: 22; radius: 11
                            color: navHov.hovered ? Theme.hover : "transparent"
                            Txt { anchors.centerIn: parent; text: Theme.g(modelData.g); font.pixelSize: modelData.d === 0 ? 6 : 10; color: Theme.grayMid }
                            HoverHandler { id: navHov }
                            TapHandler { onTapped: { if (modelData.d === 0) { cal.month = dash.now.getMonth(); cal.year = dash.now.getFullYear() } else cal.shift(modelData.d) } }
                        }
                    }
                }
            }
            Grid {
                id: calGrid
                anchors { top: calHead.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
                columns: 7; columnSpacing: 2; rowSpacing: 0
                Repeater {
                    model: dash.en ? ["S", "M", "T", "W", "T", "F", "S"] : ["D", "S", "T", "Q", "Q", "S", "S"]
                    delegate: Txt { required property var modelData; width: 32; height: 20; horizontalAlignment: Text.AlignHCenter; text: modelData; color: Theme.grayMid; font.pixelSize: 10 }
                }
                Repeater {
                    model: 42
                    delegate: Item {
                        required property int index
                        readonly property int day: index - cal.first + 1
                        readonly property bool inMonth: day >= 1 && day <= cal.days
                        readonly property bool today: inMonth && day === dash.now.getDate() && cal.month === dash.now.getMonth() && cal.year === dash.now.getFullYear()
                        width: 32; height: 22
                        Rectangle {
                            anchors.centerIn: parent
                            width: 26; height: 21; radius: 10.5
                            color: parent.today && !Theme.nothing ? Theme.accent : "transparent"
                            border.width: parent.today && Theme.nothing ? 1 : 0; border.color: Theme.white
                            scale: parent.today ? 1 : 0.6
                            Behavior on scale { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutBack } }
                        }
                        Txt {
                            anchors.centerIn: parent
                            text: parent.inMonth ? parent.day : parent.day < 1 ? cal.prevDays + parent.day : parent.day - cal.days
                            color: parent.today ? (Theme.nothing ? Theme.white : Theme.onAccent) : parent.inMonth ? Theme.foreground : Theme.grayDark
                            font.pixelSize: 11; font.bold: parent.today
                        }
                    }
                }
            }
        }

        // ── profile + weather ──
        Column {
            width: parent.width - clock.width - cal.width - perf.width - 3 * dash.gap
            spacing: dash.gap
            Card {
                order: 2
                width: parent.width; height: (dash.rowH - dash.gap) / 2
                Avatar { id: pfp; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 58; height: 58; source: Profile.avatar; initial: Profile.initial }
                Column {
                    anchors { left: pfp.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    Txt { width: parent.width; text: Profile.name; color: Theme.white; font.pixelSize: 15 }
                    Txt { width: parent.width; text: Profile.subtitle; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                    Row {
                        spacing: 10
                        Txt { text: Theme.glyph.distro; color: Theme.accent; font.pixelSize: 15 }
                        Txt { text: Theme.g(0xf359); color: Theme.accent; font.pixelSize: 15 }
                        Txt { text: Theme.g(0xf017) + " " + dash.sessionText(); color: Theme.foreground; font.pixelSize: Theme.small; font.bold: false }
                    }
                }
            }
            Card {
                order: 3
                width: parent.width; height: (dash.rowH - dash.gap) / 2
                Txt {
                    id: wIcon
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    text: Weather.ok ? Weather.glyph : Theme.g(0xf0590); font.pixelSize: 38; color: Theme.white
                }
                Column {
                    anchors { left: wIcon.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Row {
                        spacing: 8
                        Txt { text: Weather.ok ? Weather.temp + "°" : "—"; font.pixelSize: 26; color: Theme.white; font.family: Theme.fontDot }
                        Txt { anchors.bottom: parent.bottom; anchors.bottomMargin: 5; visible: Weather.ok; text: Weather.tmax + "° / " + Weather.tmin + "°"; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                    }
                    Txt { width: parent.width; text: Weather.ok ? Weather.desc : Weather.loading ? Labels.pick(["Carregando…", "Loading…"]) : Labels.pick(["Clima indisponível", "Weather unavailable"]); color: Theme.foreground; font.bold: false }
                    Txt { width: parent.width; visible: Weather.ok; text: Theme.g(0xf041) + " " + Weather.place; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                }
                TapHandler { onTapped: Settings.centerTab = 2 }
            }
        }

        // ── mini performance: vertical meters ──
        Card {
            id: perf
            order: 4
            width: 96; height: dash.rowH
            Row {
                anchors.centerIn: parent
                spacing: 10
                Repeater {
                    model: [
                        { k: "CPU", v: Math.max(0, Stats.cpu) },
                        { k: "GPU", v: Math.max(0, Stats.gpu) },
                        { k: "RAM", v: Stats.ramPct }
                    ]
                    delegate: Column {
                        required property var modelData
                        spacing: 6
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.v); color: Theme.white; font.pixelSize: 10 }
                        DotMeter {
                            visible: Theme.nothing
                            anchors.horizontalCenter: parent.horizontalCenter
                            vertical: true; width: 7; height: 140; dot: 7; gap: 3
                            value: modelData.v / 100
                        }
                        Rectangle {
                            visible: !Theme.nothing
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 12; height: 140; radius: 6
                            color: Theme.grayDark
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width; radius: 6
                                height: Math.max(width, parent.height * modelData.v / 100)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: modelData.v >= 85 ? Theme.white : Theme.accent }
                                    GradientStop { position: 1; color: Qt.alpha(Theme.accent, 0.45) }
                                }
                                Behavior on height { NumberAnimation { duration: Theme.dur(500); easing.type: Easing.OutCubic } }
                            }
                        }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.k; color: Theme.grayMid; font.pixelSize: 9 }
                    }
                }
            }
            TapHandler { onTapped: Settings.centerTab = 1 }
        }
    }

    // ── mini player ──
    Card {
        order: 5
        visible: Media.player !== null
        width: parent.width; height: 78
        CoverArt { id: cover; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 58; height: 58; size: 116; source: Media.art }
        Column {
            anchors { left: cover.right; leftMargin: 12; right: ctl.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 3
            Txt { width: parent.width; text: Media.title; color: Theme.white }
            Txt { width: parent.width; text: Media.artist; color: Theme.grayMid; font.bold: false }
            DotMeter { visible: Theme.nothing; width: parent.width; dot: 4; value: Media.progress }
            Rectangle {
                visible: !Theme.nothing
                width: parent.width; height: 3; radius: 1.5; color: Theme.grayDark
                Rectangle { width: parent.width * Media.progress; height: parent.height; radius: 1.5; color: Theme.accent
                            Behavior on width { NumberAnimation { duration: Theme.dur(400) } } }
            }
        }
        Row {
            id: ctl
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 4
            Btn { compact: true; icon: Theme.glyph.prev; onActivated: Media.previous() }
            Btn { compact: true; icon: Media.playing ? Theme.glyph.pause : Theme.glyph.play; active: Media.playing; onActivated: Media.toggle() }
            Btn { compact: true; icon: Theme.glyph.next; onActivated: Media.next() }
            Btn { compact: true; icon: Theme.g(0xf0c9); onActivated: Settings.centerTab = 3 }
        }
    }
}
