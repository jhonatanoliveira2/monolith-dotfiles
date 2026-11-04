import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

// Settings > Widgets: show / arrange (Registry), the widget catalogue (adds to the focused monitor) and the
// widgets already on the desktop, each with a remove button (services/Widgets.qml).
Column {
    spacing: 8
    EntryList { page: "widgets"; width: parent.width }

    Section { width: parent.width; text: Labels.pick(["Adicionar widget", "Add a widget"]) }
    Repeater {
        model: Widgets.types
        delegate: ListRow {
            required property var modelData
            width: parent.width
            icon: Theme.g(modelData.glyph)
            title: Widgets.name(modelData)
            subtitle: modelData.desc[Settings.language === "en" ? 1 : 0]
            trailing: "+"
            onClicked: m => Widgets.add(modelData.id, Popups.focusedScreen())
        }
    }

    Section { width: parent.width; text: Labels.pick(["Na área de trabalho", "On the desktop"]) }
    Txt { visible: Widgets.list.length === 0; x: 10; text: Labels.pick(["Nenhum widget ainda", "No widgets yet"]); color: Theme.grayMid }
    Repeater {
        model: Widgets.list
        delegate: Item {
            required property var modelData
            readonly property var t: Widgets.type(modelData.type)
            width: parent.width; height: row.height
            ListRow {
                id: row
                anchors { left: parent.left; right: rm.left; rightMargin: 6 }
                icon: Theme.g(parent.t.glyph)
                title: Widgets.name(parent.t)
                subtitle: modelData.screen + "  ·  " + modelData.x + ", " + modelData.y
            }
            Btn { id: rm; anchors { right: parent.right; verticalCenter: parent.verticalCenter } compact: true; icon: Theme.glyph.trash; text: Labels.pick(["Remover", "Remove"]); onActivated: Widgets.remove(modelData.uid) }
        }
    }
}
