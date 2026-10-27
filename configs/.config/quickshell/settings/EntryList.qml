import QtQuick
import "../core"
import "../components"

// All Registry entries of one page, with a heading (CatHeader) whenever the category changes.
Column {
    id: root
    property string page: ""
    property bool first: true            // false when the page draws something above the list
    width: parent ? parent.width : 400
    spacing: 4
    property var only: []                // categories to show ([] = all)
    property var except: []              // categories to leave out (drawn elsewhere by the page)
    readonly property var list: Registry.byPage(page).filter(e => (!only.length || only.indexOf(e.cat) >= 0) && except.indexOf(e.cat) < 0)
    Repeater {
        model: root.list
        delegate: Column {
            required property var modelData
            required property int index
            width: root.width
            spacing: 4
            CatHeader {
                readonly property var prev: index > 0 ? root.list[index - 1] : null
                visible: !!modelData.cat && (!prev || prev.cat !== modelData.cat)
                first: index === 0 && root.first
                width: parent.width; text: Labels.t("cat_" + modelData.cat)
            }
            SettingRow { entry: modelData; width: parent.width }
        }
    }
}
