pragma Singleton
import QtQuick
import Quickshell

// Colours for the bar's modules. They match Theme except in frame style, whose opaque background goes from black
// to the theme tint (Settings > Bar > frame tone): there the ink follows the background, each token pushed to a
// minimum contrast so the modules stay legible at any tone, and keeping the theme's hues. On a dark background
// the theme colours are lightened (as everywhere in the shell); on a light one the ink is built from the theme's
// accent and panel colours and darkened as a shade of the same hue, never plain grey or black.
// (Menus keep using Theme: their background does not change.)
Singleton {
    id: root
    readonly property var p: Theme.p
    readonly property bool framed: Theme.barStyle === "frame"
    readonly property string bg: Theme.barSolidHex
    // dark ink when black reads better than white on the background
    readonly property bool light: framed && Palettes.contrast(bg, "#000000") > Palettes.contrast(bg, "#ffffff")

    // a darker shade of c (same hue) with at least `min` contrast against the light background
    function shade(c, min) {
        let t = 0, out = c
        while (Palettes.contrast(out, bg) < min && t < 1) { t += 0.04; out = Palettes.mix(c, "#000000", t) }
        return out
    }
    // light background: ink from the theme (accent toward the panel colour), shaded to the contrast it needs;
    // the dimmer tokens blend it with the background first, so they read as lighter shades of the same colour
    readonly property string base: Palettes.mix(p.accent, p.panel, 0.35)
    function dark(blend, min) { return shade(Palettes.mix(base, bg, blend), min) }

    readonly property color white: !framed ? p.white : light ? dark(0, 8) : Palettes.legible(p.white, bg, 9)
    readonly property color foreground: !framed ? p.foreground : light ? dark(0.08, 6.5) : Palettes.legible(p.foreground, bg, 7)
    readonly property color grayLight: !framed ? p.grayLight : light ? dark(0.15, 5.5) : Palettes.legible(p.grayLight, bg, 6)
    readonly property color grayMid: !framed ? p.grayMid : light ? dark(0.35, 3.2) : Palettes.legible(p.grayMid, bg, 3.5)
    readonly property color grayDark: !framed ? p.grayDark : Palettes.mix(bg, light ? base : p.foreground, 0.25)
    readonly property color accent: !framed ? p.accent : light ? shade(p.accent, 3.2) : Palettes.legible(p.accent, bg, 3)
    readonly property color onForeground: !framed ? p.onForeground : bg
    function tint(a) { return light ? Palettes.alpha(Palettes.mix(base, "#000000", 0.3), a * 1.2) : Theme.tint(a) }
    readonly property color hover: tint(0.08)
    readonly property color pressed: tint(0.16)
    readonly property color critical: Theme.nothing ? Theme.critical : tint(0.14)
    readonly property color selected: Palettes.alpha(light ? shade(p.accent, 3.2) : p.accent, light ? 0.18 : 0.12)
    readonly property color line: light ? Palettes.alpha(base, 0.35) : Theme.line
}
