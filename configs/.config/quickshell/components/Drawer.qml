import QtQuick
import "../core"

// Collapsible group ("drawer"): a header row that slides the children open or closed.
// `summary` is shown on the right of the header (e.g. the current value while closed).
Column {
    id: root
    property string title: ""
    property string summary: ""
    property bool open: false
    default property alias content: inner.data
    spacing: 0

    Rectangle {
        width: parent.width; height: 32
        radius: Theme.radius
        color: ma.pressed ? Theme.pressed : ma.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.dur(100) } }
        Txt {
            id: chev
            x: 8; width: 14; height: parent.height
            verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
            text: Theme.g(0xf054); font.pixelSize: 10; color: Theme.grayMid
            rotation: root.open ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.dur(200); easing.type: Easing.OutCubic } }
        }
        Txt { anchors { left: chev.right; leftMargin: 8; right: sum.left; rightMargin: 8 } height: parent.height; verticalAlignment: Text.AlignVCenter; text: root.title }
        Txt {
            id: sum
            anchors { right: parent.right; rightMargin: 10 } height: parent.height; verticalAlignment: Text.AlignVCenter
            text: root.summary; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = !root.open }
    }
    Item {
        width: parent.width
        height: root.open ? inner.implicitHeight + 8 : 0
        visible: height > 0
        clip: true
        Behavior on height { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }
        Column {
            id: inner
            y: 6; width: parent.width; spacing: 4
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }
        }
    }
}
