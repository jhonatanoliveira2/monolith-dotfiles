pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Current weather from wttr.in (curl, no API key). Fetched only on demand (the center menu or a weather widget
// asks with refresh()) and cached for 20 minutes; Settings.weatherLocation = "" locates by IP.
Singleton {
    id: root
    property bool ok: false
    property bool loading: false
    property string error: ""
    property double fetchedAt: 0
    property int temp: 0
    property int feels: 0
    property int tmin: 0
    property int tmax: 0
    property int humidity: 0
    property int wind: 0            // km/h
    property int code: 0
    property string desc: ""
    property string place: ""
    readonly property string glyph: glyphOf(code)

    function glyphOf(c) {
        if (c === 113) return Theme.g(0xf0599)                                           // sunny
        if (c === 116) return Theme.g(0xf0595)                                           // partly cloudy
        if (c === 119 || c === 122) return Theme.g(0xf0590)                              // cloudy
        if ([143, 248, 260].indexOf(c) >= 0) return Theme.g(0xf0591)                     // fog
        if ([200, 386, 389, 392, 395].indexOf(c) >= 0) return Theme.g(0xf0593)           // thunder
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 374, 377, 350].indexOf(c) >= 0) return Theme.g(0xf0598)   // snow / ice
        if ([176, 182, 185, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 317, 320, 353, 356, 359, 362, 365].indexOf(c) >= 0) return Theme.g(0xf0597)   // rain / drizzle
        return Theme.g(0xf0591)                                                          // haze, smoke, anything else
    }

    function refresh(force) {
        if (proc.running) return
        if (!force && ok && Date.now() - fetchedAt < 20 * 60 * 1000) return
        const loc = encodeURIComponent(Settings.weatherLocation.trim())
        const lang = Settings.language === "en" ? "en" : "pt"
        loading = true
        proc.command = ["curl", "-fsS", "--max-time", "10", "https://wttr.in/" + loc + "?format=j1&lang=" + lang]
        console.log("[weather] fetching", loc || "<ip location>")
        proc.running = true
    }
    // a new place: fetch again next time
    Connections { target: Settings; function onWeatherLocationChanged() { root.fetchedAt = 0 } }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                try {
                    const j = JSON.parse(text)
                    const c = j.current_condition[0], d = j.weather[0], a = (j.nearest_area || [])[0]
                    root.temp = Number(c.temp_C); root.feels = Number(c.FeelsLikeC)
                    root.humidity = Number(c.humidity); root.wind = Number(c.windspeedKmph); root.code = Number(c.weatherCode)
                    const ld = c["lang_" + (Settings.language === "en" ? "en" : "pt")]
                    root.desc = String((ld && ld[0] ? ld[0].value : c.weatherDesc[0].value) || "").trim()
                    root.tmin = Number(d.mintempC); root.tmax = Number(d.maxtempC)
                    root.place = a ? String(a.areaName[0].value) : Settings.weatherLocation
                    root.ok = true; root.error = ""; root.fetchedAt = Date.now()
                    console.log("[weather]", root.place, root.temp + "°C", root.desc)
                } catch (e) {
                    root.error = "parse"
                    console.warn("[weather] bad response:", String(e))
                }
            }
        }
        onExited: code => { if (code !== 0) { root.loading = false; root.error = "net"; console.warn("[weather] curl failed with exit code", code) } }
    }
}
