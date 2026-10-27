pragma Singleton
import QtQuick
import Quickshell

// Colour themes (Settings > Themes). "default" is the original Monolith palette, verbatim. Presets and the
// dynamic palette (wpgtk, services/Themes.qml) are 16 terminal colours + background / foreground that
// derive() turns into the same tokens, keeping the shell dark and every text above a minimum contrast.
Singleton {
    id: root

    readonly property var monolith: ({
        id: "default", background: "#111111", foreground: "#eeeeee", white: "#ffffff", grayLight: "#cccccc",
        grayMid: "#888888", grayDark: "#444444", accent: "#ffffff", line: "#c8c8c8", bar: "#000000", panel: "#111111",
        tint: "#ffffff", onAccent: "#000000", onForeground: "#101010", ansi: null
    })

    // accent: index of the colour used as accent (none = the most vivid one)
    readonly property var presets: [
        { id: "nord", name: "Nord", accent: 6, background: "#2e3440", foreground: "#d8dee9",
          colors: ["#3b4252", "#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#88c0d0", "#e5e9f0",
                   "#4c566a", "#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#8fbcbb", "#eceff4"] },
        { id: "gruvbox", name: "Gruvbox", accent: 11, background: "#282828", foreground: "#ebdbb2",
          colors: ["#282828", "#cc241d", "#98971a", "#d79921", "#458588", "#b16286", "#689d6a", "#a89984",
                   "#928374", "#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c", "#ebdbb2"] },
        { id: "catppuccin", name: "Catppuccin", accent: 12, background: "#1e1e2e", foreground: "#cdd6f4",
          colors: ["#45475a", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#bac2de",
                   "#585b70", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#a6adc8"] },
        { id: "tokyonight", name: "Tokyo Night", accent: 12, background: "#1a1b26", foreground: "#c0caf5",
          colors: ["#15161e", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#a9b1d6",
                   "#414868", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff", "#c0caf5"] },
        { id: "rosepine", name: "Rosé Pine", accent: 5, background: "#191724", foreground: "#e0def4",
          colors: ["#26233a", "#eb6f92", "#31748f", "#f6c177", "#9ccfd8", "#c4a7e7", "#ebbcba", "#e0def4",
                   "#6e6a86", "#eb6f92", "#31748f", "#f6c177", "#9ccfd8", "#c4a7e7", "#ebbcba", "#e0def4"] },
        { id: "everforest", name: "Everforest", accent: 2, background: "#2d353b", foreground: "#d3c6aa",
          colors: ["#475258", "#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092", "#d3c6aa",
                   "#475258", "#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092", "#d3c6aa"] },
        { id: "dracula", name: "Dracula", accent: 4, background: "#282a36", foreground: "#f8f8f2",
          colors: ["#21222c", "#ff5555", "#50fa7b", "#f1fa8c", "#bd93f9", "#ff79c6", "#8be9fd", "#f8f8f2",
                   "#6272a4", "#ff6e6e", "#69ff94", "#ffffa5", "#d6acff", "#ff92df", "#a4ffff", "#ffffff"] },
        { id: "kanagawa", name: "Kanagawa", accent: 4, background: "#1f1f28", foreground: "#dcd7ba",
          colors: ["#16161d", "#c34043", "#76946a", "#c0a36e", "#7e9cd8", "#957fb8", "#6a9589", "#c8c093",
                   "#727169", "#e82424", "#98bb6c", "#e6c384", "#7fb4ca", "#938aa9", "#7aa89f", "#dcd7ba"] }
    ]

    function preset(id) { return presets.find(p => p.id === id) || null }
    // a dynamic palette is usable only when it has every colour (the settings file can be edited by hand)
    function valid(s) {
        const hex = c => typeof c === "string" && /^#[0-9a-fA-F]{6}$/.test(c)
        // (after a reload from settings.json the list is a sequence wrapper, not a JS array)
        return !!s && hex(s.background) && hex(s.foreground) && !!s.colors && s.colors.length === 16 && Array.from(s.colors).every(hex)
    }

    // the palette in use: a dynamic theme without a valid palette (never generated, or wpgtk failed the
    // first time) falls back to the default colours, so the shell always stays usable
    readonly property var active: {
        if (Settings.themeMode === "preset") { const p = preset(Settings.themePreset); if (p) return derive(p) }
        if (Settings.themeMode === "dynamic" && valid(Settings.themePalette)) return derive(Settings.themePalette)
        return monolith
    }

    // ── colour helpers (hex "#rrggbb" <-> { r, g, b } in 0..1) ──
    function rgb(h) { return { r: parseInt(h.substr(1, 2), 16) / 255, g: parseInt(h.substr(3, 2), 16) / 255, b: parseInt(h.substr(5, 2), 16) / 255 } }
    function hex(c) {
        const x = v => ("0" + Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)).slice(-2)
        return "#" + x(c.r) + x(c.g) + x(c.b)
    }
    function alpha(h, a) { const c = rgb(h); return Qt.rgba(c.r, c.g, c.b, a) }
    function mix(a, b, t) { const x = rgb(a), y = rgb(b); return hex({ r: x.r + (y.r - x.r) * t, g: x.g + (y.g - x.g) * t, b: x.b + (y.b - x.b) * t }) }
    function lum(h) {
        const c = rgb(h), f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    function contrast(a, b) { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05) }
    // lighten c toward white until it reaches `min` contrast against the (dark) background bg
    function legible(c, bg, min) {
        let t = 0, out = c
        while (contrast(out, bg) < min && t < 1) { t += 0.05; out = mix(c, "#ffffff", t) }
        return out
    }
    function vivid(h) { const c = rgb(h), mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b); return (mx - mn) * (0.4 + mx) }

    // tokens of a { background, foreground, colors[16], accent? } palette
    function derive(s) {
        // the shell is translucent dark glass: darken light or mid backgrounds (luminance <= 0.03)
        let panel = s.background, k = 0
        while (lum(panel) > 0.03 && k < 1) { k += 0.05; panel = mix(s.background, "#000000", k) }
        const c = Array.from(s.colors)
        let acc = s.accent !== undefined ? c[s.accent] : null
        if (!acc) {
            acc = c[1]
            for (const i of [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14]) if (vivid(c[i]) > vivid(acc)) acc = c[i]
        }
        const fg = legible(s.foreground, panel, 11)
        const accent = legible(acc, panel, 4.5)
        const ansi = c.map((x, i) => i === 0 ? panel : legible(x, panel, i === 8 ? 3 : 4.5))
        return {
            id: Settings.themeMode, background: panel, foreground: fg, white: legible(mix(fg, "#ffffff", 0.6), panel, 13),
            grayLight: legible(mix(fg, panel, 0.2), panel, 7), grayMid: legible(mix(fg, panel, 0.48), panel, 4.5),
            grayDark: mix(mix(fg, accent, 0.25), panel, 0.72), accent: accent, line: mix(fg, accent, 0.35),
            bar: mix(panel, "#000000", 0.55), panel: panel, tint: mix(fg, accent, 0.3),
            onAccent: contrast(accent, "#000000") >= contrast(accent, "#ffffff") ? "#000000" : "#ffffff",
            onForeground: mix(panel, "#000000", 0.4), ansi: ansi
        }
    }
}
