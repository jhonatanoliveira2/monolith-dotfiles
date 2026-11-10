pragma Singleton
import QtQuick
import Quickshell

// Greeter tokens: the same names and default values as the shell's core/Theme.qml (default Monolith palette),
// so the shell's components (Txt, Btn: copied in by nix/pkgs/greeter.nix) render exactly as they do in the bar.
// No settings file here: the greeter runs as the `greeter` user, before anyone logs in.
Singleton {
    readonly property color background: "#111111"
    readonly property color foreground: "#eeeeee"
    readonly property color white: "#ffffff"
    readonly property color grayLight: "#cccccc"
    readonly property color grayMid: "#888888"
    readonly property color grayDark: "#444444"
    readonly property color accent: "#ffffff"
    readonly property color line: Qt.rgba(0.784, 0.784, 0.784, 0.25)
    readonly property color panelBg: Qt.rgba(0.067, 0.067, 0.067, 0.72)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.08)
    readonly property color pressed: Qt.rgba(1, 1, 1, 0.16)
    readonly property color selected: Qt.rgba(1, 1, 1, 0.12)
    readonly property color critical: Qt.rgba(1, 1, 1, 0.14)

    // Nothing theme (monolith.nothingTheme, from the greeter config): Space Mono, Doto for the clock, red only
    // for a failed login; each font falls back when it is not installed
    property bool nothing: false
    readonly property var families: Qt.fontFamilies()
    function has(f) { return families.some(x => x === f || x.indexOf(f + " [") === 0) }
    readonly property string font: nothing && has("Space Mono") ? "Space Mono" : "JetBrainsMono Nerd Font"
    readonly property string fontDot: nothing && has("Doto") ? "Doto" : font
    readonly property bool dotClock: nothing && has("Doto")
    readonly property color alert: "#d71921"
    readonly property int fontSize: 13
    readonly property int small: 11
    readonly property int radius: 6
    readonly property int menuRadius: 12

    // set from the greeter config (monolith.greeter.animations)
    property bool animations: true
    function dur(ms) { return animations ? ms : 0 }

    function g(cp) { return String.fromCodePoint(cp) }
    readonly property var glyph: ({
        user: g(0xf007), lock: g(0xf023), left: g(0xf053), right: g(0xf054), power: g(0xf011), reboot: g(0xf0453),
        sleep: g(0xf04b2), keyboard: g(0xf11c), caps: g(0xf0632), session: g(0xf2d0), warn: g(0xf071), host: g(0xf108)
    })
}
