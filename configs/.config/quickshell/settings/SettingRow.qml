import QtQuick
import "../core"
import "../components"

// Renders one Registry entry. `crumb` shows the page name (used by search results).
Rectangle {
    id: row
    required property var entry
    property bool crumb: false
    readonly property bool isSlider: entry.type === "slider"
    property var drag: null                        // value while dragging (null = not dragging)
    readonly property var cur: drag !== null ? drag : (entry.get ? entry.get() : 0)

    width: parent ? parent.width : 400
    height: 44
    color: hov.hovered ? Theme.hover : "transparent"
    border.width: 1
    border.color: Theme.line
    HoverHandler { id: hov }

    Column {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        Txt { text: Registry.text(row.entry); color: Theme.foreground; width: row.width * 0.45 }
        Txt { visible: row.crumb; text: Labels.t("page_" + row.entry.page); color: Theme.grayMid; font.pixelSize: Theme.small; width: row.width * 0.45 }
    }

    Loader {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        sourceComponent: ({ toggle: tg, slider: sl, choice: ch, button: bt, text: tx })[row.entry.type]
    }

    Component { id: tg; Toggle { checked: !!row.cur; onToggled: c => row.entry.set(c) } }
    Component {
        id: bt
        Btn { compact: true; text: Labels.t("run"); confirm: !!row.entry.confirm; onActivated: row.entry.run() }
    }
    Component {
        id: ch
        Row {
            spacing: 4
            Repeater {
                model: row.entry.options
                delegate: Btn { required property var modelData; compact: true; text: modelData.l; active: row.cur === modelData.v; onActivated: row.entry.set(modelData.v) }
            }
        }
    }
    Component {
        id: sl
        Row {
            spacing: 10
            ThinSlider {
                width: 220; anchors.verticalCenter: parent.verticalCenter
                value: (row.cur - row.entry.min) / (row.entry.max - row.entry.min)
                step: row.entry.step / (row.entry.max - row.entry.min)
                onMoved: v => row.drag = Math.round((row.entry.min + v * (row.entry.max - row.entry.min)) / row.entry.step) * row.entry.step
                onReleased: v => { if (row.drag !== null) { row.entry.set(row.drag); row.drag = null } }
            }
            Txt { width: 54; horizontalAlignment: Text.AlignRight; color: Theme.grayMid
                  text: Number(row.cur).toFixed(row.entry.step >= 1 ? 0 : row.entry.step >= 0.1 ? 1 : 2) + row.entry.suffix }
        }
    }
    Component {
        id: tx
        Rectangle {
            width: 180; height: 26; color: "transparent"; border.width: 1; border.color: input.activeFocus ? Theme.white : Theme.line
            TextInput {
                id: input
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
                text: String(row.cur); clip: true; selectByMouse: true
                echoMode: row.entry.secret ? TextInput.Password : TextInput.Normal
                onAccepted: { row.entry.set(text); focus = false }
            }
        }
    }
}
