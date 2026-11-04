import QtQuick
import "../core"
import "../services"
import "../components"

// Weather widget (services/Weather.qml, wttr.in): refreshed every 20 minutes while it exists; click to refresh.
Item {
    Component.onCompleted: Weather.refresh(false)
    Timer { interval: 20 * 60 * 1000; repeat: true; running: true; onTriggered: Weather.refresh(true) }
    Txt {
        id: icon
        x: 4; anchors.verticalCenter: parent.verticalCenter
        text: Weather.ok ? Weather.glyph : Theme.g(0xf0590); font.pixelSize: 46; color: Theme.white
    }
    Column {
        anchors { left: icon.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 2
        Txt { visible: Weather.ok; text: Weather.temp + "°C"; font.pixelSize: 30; color: Theme.white }
        Txt { width: parent.width; text: Weather.ok ? Weather.desc : Weather.loading ? "…" : (Settings.language === "en" ? "Unavailable" : "Indisponível"); color: Theme.foreground; font.bold: false; elide: Text.ElideRight }
        Txt { visible: Weather.ok; width: parent.width; text: Weather.place + "  ·  " + Weather.tmin + "° / " + Weather.tmax + "°"; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false; elide: Text.ElideRight }
    }
    MouseArea { anchors.fill: parent; onClicked: Weather.refresh(true) }
}
