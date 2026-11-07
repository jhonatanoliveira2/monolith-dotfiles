import QtQuick
import "../core"
import "../services"
import "../components"

// Weather widget (services/Weather.qml, Open-Meteo): refreshed every 20 minutes while it exists; click to refresh.
Item {
    id: root
    property real k: 1                  // size factor (WidgetHost: small / medium / large)
    Component.onCompleted: Weather.refresh(false)
    Timer { interval: 20 * 60 * 1000; repeat: true; running: true; onTriggered: Weather.refresh(true) }
    Txt {
        id: icon
        x: Math.round(4 * root.k); anchors.verticalCenter: parent.verticalCenter
        text: Weather.ok ? Weather.glyph : Theme.g(0xf0590); font.pixelSize: Math.round(46 * root.k); color: Theme.white
    }
    Column {
        anchors { left: icon.right; leftMargin: Math.round(16 * root.k); right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 2
        Txt { visible: Weather.ok; text: Weather.temp + "°C"; font.pixelSize: Math.round(30 * root.k); color: Theme.white; font.family: Theme.fontDot }
        Txt { width: parent.width; text: Weather.ok ? Weather.desc : Weather.loading ? "…" : (Settings.language === "en" ? "Unavailable" : "Indisponível"); color: Theme.foreground; font.pixelSize: Math.round(Theme.fontSize * root.k); font.bold: false; elide: Text.ElideRight }
        Txt { visible: Weather.ok; width: parent.width; text: Weather.place + "  ·  " + Weather.tmin + "° / " + Weather.tmax + "°"; color: Theme.grayMid; font.pixelSize: Math.round(Theme.small * root.k); font.bold: false; elide: Text.ElideRight }
    }
    MouseArea { anchors.fill: parent; onClicked: Weather.refresh(true) }
}
