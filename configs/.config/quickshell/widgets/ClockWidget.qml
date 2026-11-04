import QtQuick
import "../core"
import "../components"

// Clock widget: time (seconds smaller) and the full date.
Item {
    id: root
    property date now: new Date()
    readonly property var loc: Qt.locale(Settings.language === "en" ? "en_US" : "pt_BR")
    Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    Column {
        anchors.verticalCenter: parent.verticalCenter
        x: 6
        spacing: 2
        Row {
            spacing: 2
            Txt { id: big; text: Qt.formatTime(root.now, Settings.clock24 ? "HH:mm" : "h:mm"); font.pixelSize: 52; color: Theme.white }
            Txt { y: big.baselineOffset - baselineOffset; text: Qt.formatTime(root.now, ":ss"); font.pixelSize: 20; color: Theme.grayMid }
        }
        Txt { text: root.loc.toString(root.now, "dddd, d MMMM"); color: Theme.foreground; font.bold: false }
    }
}
