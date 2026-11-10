pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Weather from Open-Meteo (scripts/weather.sh: curl, no API key): now, next 24 h, 7 days and air quality.
// Fetched only on demand (the center menu or a weather widget asks with refresh()) and cached for 20 minutes;
// Settings.weatherLocation = "" locates by IP. The coordinates are looked up once and kept.
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
    property int windDir: 0         // degrees, where it blows from
    property int gusts: 0
    property int pressure: 0        // hPa, sea level
    property real uv: 0
    property real uvMax: 0
    property real precip: 0         // mm now
    property int rainProb: 0        // today's max %
    property real rainSum: 0        // today's mm
    property string sunrise: ""     // "05:18"
    property string sunset: ""
    property int aqi: -1            // US AQI
    property real pm25: 0
    property real pm10: 0
    property int code: 0            // WMO weather code
    property bool isDay: true
    property string place: ""
    property var hourly: []         // [{ hour, temp, code, prob, day }]
    property var daily: []          // [{ date, code, min, max, prob, sum }]
    readonly property string desc: describe(code)
    readonly property string glyph: glyphOf(code, isDay)
    property string lat: ""
    property string lon: ""

    function glyphOf(c, day) {
        if (c === 0) return Theme.g(day ? 0xf0599 : 0xf0594)                     // clear
        if (c === 1 || c === 2) return Theme.g(day ? 0xf0595 : 0xf0f31)          // partly cloudy
        if (c === 3) return Theme.g(0xf0590)                                     // overcast
        if (c === 45 || c === 48) return Theme.g(0xf0591)                        // fog
        if (c >= 95) return Theme.g(0xf0593)                                     // thunder
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return Theme.g(0xf0598) // snow
        if (c === 65 || c === 82) return Theme.g(0xf0596)                        // heavy rain
        if (c >= 51) return Theme.g(0xf0597)                                     // drizzle / rain
        return Theme.g(0xf0591)
    }
    function describe(c) {
        const pt = Settings.language !== "en"
        const t = c === 0 ? ["Céu limpo", "Clear sky"] : c === 1 ? ["Predomínio de sol", "Mainly clear"] : c === 2 ? ["Parcialmente nublado", "Partly cloudy"]
            : c === 3 ? ["Nublado", "Overcast"] : c === 45 || c === 48 ? ["Neblina", "Fog"] : c >= 51 && c <= 57 ? ["Garoa", "Drizzle"]
            : c === 61 || c === 80 ? ["Chuva fraca", "Light rain"] : c === 63 || c === 81 ? ["Chuva", "Rain"] : c === 65 || c === 82 ? ["Chuva forte", "Heavy rain"]
            : c === 66 || c === 67 ? ["Chuva congelante", "Freezing rain"] : (c >= 71 && c <= 77) || c === 85 || c === 86 ? ["Neve", "Snow"]
            : c >= 95 ? ["Tempestade", "Thunderstorm"] : ["—", "—"]
        return t[pt ? 0 : 1]
    }
    // US AQI band 0..5 and its name
    readonly property int aqiLevel: aqi < 0 ? -1 : aqi <= 50 ? 0 : aqi <= 100 ? 1 : aqi <= 150 ? 2 : aqi <= 200 ? 3 : aqi <= 300 ? 4 : 5
    readonly property string aqiText: aqiLevel < 0 ? "—" : (Settings.language === "en"
        ? ["Good", "Moderate", "Unhealthy for sensitive", "Unhealthy", "Very unhealthy", "Hazardous"]
        : ["Boa", "Moderada", "Ruim p/ sensíveis", "Ruim", "Muito ruim", "Perigosa"])[aqiLevel]

    function refresh(force) {
        if (proc.running) return
        if (!force && ok && Date.now() - fetchedAt < 20 * 60 * 1000) return
        // no city and locating by IP turned off: nothing is requested
        if (needsPlace) { loading = false; ok = false; error = "place"; return }
        loading = true
        proc.command = ["bash", Quickshell.shellPath("scripts/weather.sh"), Settings.weatherLocation.trim(), lat, lon, place,
                        Settings.language === "en" ? "en" : "pt", Settings.weatherByIp ? "1" : "0"]
        console.log("[weather] fetching", Settings.weatherLocation.trim() || "<ip location>")
        proc.running = true
    }
    readonly property bool needsPlace: Settings.weatherLocation.trim() === "" && !Settings.weatherByIp
    // a new place: look it up again next time
    Connections {
        target: Settings
        function onWeatherLocationChanged() { root.fetchedAt = 0; root.lat = ""; root.lon = "" }
        // turned off while the place came from the IP: forget it
        function onWeatherByIpChanged() { if (Settings.weatherLocation.trim() === "") { root.fetchedAt = 0; root.lat = ""; root.lon = ""; root.place = ""; if (!Settings.weatherByIp) root.ok = false } }
    }

    function hm(iso) { return String(iso || "").slice(11, 16) }
    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                if (text.trim() === "") return          // the request failed: onExited reports it
                try {
                    const lines = text.trim().split("\n")
                    const loc = lines[0].split("\t"), j = JSON.parse(lines[1]), a = JSON.parse(lines[2] || "{}")
                    root.place = loc[0]; root.lat = loc[1]; root.lon = loc[2]
                    const c = j.current, d = j.daily, h = j.hourly
                    root.temp = Math.round(c.temperature_2m); root.feels = Math.round(c.apparent_temperature)
                    root.humidity = c.relative_humidity_2m; root.code = c.weather_code; root.isDay = c.is_day === 1
                    root.wind = Math.round(c.wind_speed_10m); root.windDir = c.wind_direction_10m; root.gusts = Math.round(c.wind_gusts_10m)
                    root.pressure = Math.round(c.pressure_msl); root.uv = c.uv_index || 0; root.precip = c.precipitation || 0
                    root.tmin = Math.round(d.temperature_2m_min[0]); root.tmax = Math.round(d.temperature_2m_max[0])
                    root.rainProb = d.precipitation_probability_max[0] || 0; root.rainSum = d.precipitation_sum[0] || 0
                    root.uvMax = d.uv_index_max[0] || 0
                    root.sunrise = root.hm(d.sunrise[0]); root.sunset = root.hm(d.sunset[0])
                    root.hourly = h.time.map((t, i) => ({ hour: t.slice(11, 13), temp: Math.round(h.temperature_2m[i]), code: h.weather_code[i],
                                                           prob: h.precipitation_probability[i] || 0, day: h.is_day[i] === 1 }))
                    root.daily = d.time.map((t, i) => ({ date: t, code: d.weather_code[i], min: Math.round(d.temperature_2m_min[i]),
                                                          max: Math.round(d.temperature_2m_max[i]), prob: d.precipitation_probability_max[i] || 0,
                                                          sum: d.precipitation_sum[i] || 0 }))
                    const q = a.current || {}
                    root.aqi = q.us_aqi !== undefined && q.us_aqi !== null ? q.us_aqi : -1
                    root.pm25 = q.pm2_5 || 0; root.pm10 = q.pm10 || 0
                    root.ok = true; root.error = ""; root.fetchedAt = Date.now()
                    console.log("[weather]", root.place, root.temp + "°C", root.desc)
                } catch (e) {
                    root.error = "parse"
                    console.warn("[weather] bad response:", String(e))
                }
            }
        }
        onExited: code => { if (code !== 0) { root.loading = false; root.error = "net"; console.warn("[weather] fetch failed with exit code", code) } }
    }
}
