pragma Singleton
import QtQuick
import Quickshell

// Visual identity: monochrome (white to black), translucent black, thin near-transparent borders.
// Same palette, font and proportions as the previous Waybar (colors.css / style.css).
Singleton {
    // Colours come from the active theme (core/Palettes.qml, Settings > Themes); the default theme is the
    // original palette below, unchanged: #111111 / #eeeeee / #ffffff / #cccccc / #888888 / #444444.
    readonly property var p: Palettes.active
    readonly property color background: p.background
    readonly property color foreground: p.foreground
    readonly property color white: p.white
    readonly property color grayLight: p.grayLight
    readonly property color grayMid: p.grayMid
    readonly property color grayDark: p.grayDark
    readonly property color accent: p.accent
    readonly property color onAccent: p.onAccent          // text over an accent / white fill
    readonly property color onForeground: p.onForeground  // text over a foreground fill

    readonly property color line: Palettes.alpha(p.line, 0.25)
    readonly property color barBg: Palettes.alpha(p.bar, Config.barOpacity)
    readonly property color panelBg: Palettes.alpha(p.panel, Config.menuOpacity)
    readonly property color hover: tint(0.08)
    readonly property color pressed: tint(0.16)
    readonly property color selected: Palettes.alpha(p.accent, 0.12)
    readonly property color selectedBorder: grayLight
    readonly property color critical: tint(0.14)
    // translucent light overlay (white on the default theme)
    function tint(a) { return Palettes.alpha(p.tint, a) }

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 13
    readonly property int small: 11
    readonly property int barHeight: 32
    readonly property int barSize: Settings.barVertical ? 42 : barHeight   // thickness of the bar on any edge
    readonly property int barIcon: Settings.barVertical ? 17 : fontSize     // module glyphs (larger on a side bar, which has no text)
    readonly property int menuRadius: 12
    readonly property int radius: 6        // buttons, rows, cards inside menus
    readonly property int gap: 3           // distance between the bar and a menu

    // Duration helper: 0 when animations are disabled in Config.
    function dur(ms) { return Config.animations ? Math.round(ms * Config.animationScale) : 0 }

    // Nerd Font glyphs (code points, so no private-use characters live in the sources).
    function g(cp) { return String.fromCodePoint(cp) }
    readonly property var glyph: ({
        arch: g(0xf303), note: g(0xf0ea2), pause: g(0xf04c), play: g(0xf04b), prev: g(0xf048), next: g(0xf051),
        shuffle: g(0xf074), repeat: g(0xf01e), repeatOne: g(0xf0458), search: g(0xf002), history: g(0xf1da),
        cpu: g(0xf4bc), gpu: g(0xf0fb2), ram: g(0xefc5),
        wifi: g(0xf05a9), wifiOff: g(0xf05aa), wired: g(0xf0318), wiredOff: g(0xf0319), offline: g(0xf092d),
        btOn: g(0xf00af), btConn: g(0xf00b1), btOff: g(0xf00b2),
        battery: [g(0xf244), g(0xf243), g(0xf242), g(0xf241), g(0xf240)], bolt: g(0xf0e7),
        backlight: g(0xf185), vol: g(0xf028), volLow: g(0xf027), volMuted: g(0xf466), headphone: g(0xf025),
        mic: g(0xf130), micOff: g(0xf131),
        bell: g(0xf0f3), bellOff: g(0xf1f6), saver: g(0xf06c), balanced: g(0xf24e), perf: g(0xf0e4),
        cog: g(0xf013), lock: g(0xf023), sleep: g(0xf04b2), reboot: g(0xf0453), out: g(0xf08b), power: g(0xf011),
        moon: g(0xf0594), check: g(0xf00c), close: g(0xf00d), config: g(0xe615), animations: g(0xf16fd),
        refresh: g(0xf021), left: g(0xf053), right: g(0xf054), calendar: g(0xf073), trash: g(0xf1f8), dot: "●",
        window: g(0xf2d0)
    })
}
