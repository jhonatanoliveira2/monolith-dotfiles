pragma Singleton
import QtQuick
import Quickshell

// Visual identity: graphite + cyan, square corners, translucent black, thin near-transparent borders.
// Same palette, font and proportions as the previous Waybar (colors.css / style.css).
Singleton {
    readonly property color background: "#111111"
    readonly property color foreground: "#eeeeee"
    readonly property color white: "#ffffff"
    readonly property color grayLight: "#cccccc"
    readonly property color grayMid: "#888888"
    readonly property color grayDark: "#444444"
    readonly property color accent: "#cccccc"

    readonly property color line: Qt.rgba(200 / 255, 200 / 255, 200 / 255, 0.25)
    readonly property color barBg: Qt.rgba(0, 0, 0, 0.5)
    readonly property color panelBg: Qt.rgba(17 / 255, 17 / 255, 17 / 255, 0.65)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.08)
    readonly property color selected: Qt.rgba(1, 1, 1, 0.12)
    readonly property color selectedBorder: "#cccccc"
    readonly property color critical: Qt.rgba(1, 1, 1, 0.14)

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int small: 11
    readonly property int barHeight: 32
    readonly property int menuRadius: 12
    readonly property int gap: 3          // distance between the bar and a menu

    // Duration helper: 0 when animations are disabled in Config.
    function dur(ms) { return Config.animations ? ms : 0 }

    // Nerd Font glyphs (code points, so no private-use characters live in the sources).
    function g(cp) { return String.fromCodePoint(cp) }
    readonly property var glyph: ({
        arch: g(0xf303), note: "󰺢 ", pause: g(0xf04c), play: g(0xf04b), prev: g(0xf048), next: g(0xf051),
        cpu: " ", gpu: "󰾲 " , ram: " ",
        wifi: g(0xf05a9), wifiOff: g(0xf05aa), wired: g(0xf0318), wiredOff: g(0xf0319), offline: g(0xf092d),
        btOn: g(0xf00af), btConn: g(0xf00b1), btOff: g(0xf00b2),
        battery: [g(0xf244), g(0xf243), g(0xf242), g(0xf241), g(0xf240)], bolt: g(0xf0e7),
        backlight: g(0xf185), vol: "  ", volMuted: g(0xf466), headphone: g(0xf025), mic: g(0xf130), micOff: g(0xf131),
        bell: g(0xf0f3), bellOff: g(0xf1f6), saver: g(0xf06c), balanced: g(0xf24e), perf: g(0xf0e4),
        cog: g(0xf013), lock: g(0xf023), sleep: "󰒲", reboot: "󰑓", out: "", power: g(0xf011), moon: "󰖔", check: g(0xf00c), close: g(0xf00d),
        refresh: g(0xf021), left: g(0xf053), right: g(0xf054), calendar: g(0xf073), trash: g(0xf1f8), dot: "●", config: "", animations: "󱛽"
    })
}
