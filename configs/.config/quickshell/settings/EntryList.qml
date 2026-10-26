import QtQuick
import "../core"
import "../components"

// All Registry entries of one page, with a heading whenever the category changes.
Column {
    id: root
    property string page: ""
    width: parent ? parent.width : 400
    spacing: 4
    readonly property var list: Registry.byPage(page)
    Repeater {
        model: root.list
        delegate: Column {
            required property var modelData
            required property int index
            width: root.width
            spacing: 4
            Section {
                readonly property var prev: index > 0 ? root.list[index - 1] : null
                visible: !!modelData.cat && (!prev || prev.cat !== modelData.cat)
                width: parent.width; text: Labels.t("cat_" + modelData.cat)
            }
            SettingRow { entry: modelData; width: parent.width }
        }
    }
}
