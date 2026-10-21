import QtQuick
import Quickshell
import "../core"
import "../components"

MenuWindow {
    menu: "calendar"
    panelWidth: 300

    Column {
        id: col
        width: parent.width
        spacing: 4
        property date shown: new Date()
        readonly property date today: new Date()
        readonly property int first: (new Date(shown.getFullYear(), shown.getMonth(), 1).getDay() + 6) % 7   // Monday first
        readonly property int days: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()
        Component.onCompleted: shown = new Date()

        Item {
            width: parent.width; height: 32
            Txt { id: prev; anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: 30; horizontalAlignment: Text.AlignHCenter; text: Theme.glyph.left
                MouseArea { anchors.fill: parent; onClicked: col.shown = new Date(col.shown.getFullYear(), col.shown.getMonth() - 1, 1) } }
            Txt { anchors.centerIn: parent; text: Qt.formatDate(col.shown, "MMMM yyyy"); color: Theme.foreground
                MouseArea { anchors.fill: parent; onClicked: col.shown = new Date() } }
            Txt { anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 30; horizontalAlignment: Text.AlignHCenter; text: Theme.glyph.right
                MouseArea { anchors.fill: parent; onClicked: col.shown = new Date(col.shown.getFullYear(), col.shown.getMonth() + 1, 1) } }
        }
        Grid {
            width: parent.width
            columns: 7
            Repeater {
                model: Strings.weekdays()
                delegate: Txt { required property string modelData; width: col.width / 7; height: 24; horizontalAlignment: Text.AlignHCenter; text: modelData; color: Theme.grayMid; font.pixelSize: Theme.small }
            }
            Repeater {
                model: 42
                delegate: Item {
                    required property int index
                    readonly property int day: index - col.first + 1
                    readonly property bool valid: day >= 1 && day <= col.days
                    readonly property bool isToday: valid && col.shown.getMonth() === col.today.getMonth() && col.shown.getFullYear() === col.today.getFullYear() && day === col.today.getDate()
                    width: col.width / 7; height: 28
                    Rectangle { anchors.centerIn: parent; width: 26; height: 24; visible: isToday; color: Theme.selected; border.width: 1; border.color: Theme.accent }
                    Txt { anchors.centerIn: parent; text: valid ? day : ""; color: isToday ? Theme.white : Theme.grayLight; font.bold: isToday }
                }
            }
        }
    }
}
