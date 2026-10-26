import QtQuick
import "../core"
import "../components"
import "../services"

// Sidebar (search + pages) and the page area.
Rectangle {
    id: app
    property string page: Popups.appPage
    property string query: ""
    readonly property bool searching: query.trim().length > 0
    readonly property var results: searching ? Registry.search(query) : []

    color: Theme.panelBg
    border.width: 1
    border.color: Theme.line
    focus: true
    function back() { if (searching) { query = ""; input.text = "" } else Popups.closeApp() }
    Keys.onEscapePressed: back()
    Shortcut { sequence: "Ctrl+F"; onActivated: input.forceActiveFocus() }
    Component.onCompleted: { input.forceActiveFocus(); Sys.refresh() }

    function pageFile(p) {
        return ({ system: "PageSystem", display: "PageDisplay", audio: "PageAudio", mic: "PageMic", notifications: "PageNotifications",
                  power: "PagePower", storage: "PageStorage", bluetooth: "PageBluetooth", network: "PageNetwork", update: "PageUpdate" })[p]
    }
    // a page that is not available here (e.g. Power on a desktop) falls back to System
    onPageChanged: { if (!Registry.pages.some(x => x.id === page)) page = "system"; flick.contentY = 0 }
    onSearchingChanged: flick.contentY = 0

    Rectangle {
        id: side
        width: 230
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        color: Qt.rgba(0, 0, 0, 0.35)
        Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.line }

        Txt { id: logo; x: 14; y: 14; height: 24; text: Theme.glyph.arch + "   MONOLITH"; color: Theme.white; font.pixelSize: 15 }

        Rectangle {
            id: box
            anchors { left: parent.left; right: parent.right; top: logo.bottom; margins: 12; topMargin: 12 }
            height: 30; color: "transparent"; border.width: 1; border.color: input.activeFocus ? Theme.white : Theme.line
            Txt { id: mag; x: 8; width: 16; height: parent.height; text: String.fromCodePoint(0xf002); color: Theme.grayMid }
            TextInput {
                id: input
                anchors { left: mag.right; right: parent.right; rightMargin: 8; top: parent.top; bottom: parent.bottom }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.small + 1; font.bold: true
                clip: true; selectByMouse: true
                onTextChanged: app.query = text
                Keys.onEscapePressed: app.back()
                Txt { visible: input.text === ""; anchors.fill: parent; text: Labels.t("searchPh"); color: Theme.grayMid; font.pixelSize: Theme.small }
            }
        }

        Flickable {
            anchors { left: parent.left; right: parent.right; top: box.bottom; topMargin: 10; bottom: parent.bottom; bottomMargin: 6 }
            contentHeight: nav.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Column {
                id: nav
                width: parent.width
                Repeater {
                    model: Registry.pages
                    delegate: ListRow {
                        required property var modelData
                        width: parent.width
                        icon: String.fromCodePoint(modelData.glyph)
                        title: Labels.t("page_" + modelData.id)
                        selected: !app.searching && app.page === modelData.id
                        onClicked: m => { app.query = ""; input.text = ""; app.page = modelData.id }
                    }
                }
            }
        }
    }

    Item {
        anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom }

        Item {
            id: head
            height: 52
            anchors { left: parent.left; right: parent.right; top: parent.top }
            Txt { x: 20; height: parent.height; font.pixelSize: 17; color: Theme.white
                  text: app.searching ? Labels.t("results") + " (" + app.results.length + ")" : Labels.t("page_" + app.page) }
            Btn { anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } compact: true; text: Theme.glyph.close; onActivated: Popups.closeApp() }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.line }
        }

        Flickable {
            id: flick
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; margins: 16 }
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Rectangle {
                visible: flick.contentHeight > flick.height
                anchors.right: parent.right
                y: flick.visibleArea.yPosition * flick.height; width: 2; height: flick.visibleArea.heightRatio * flick.height
                color: Theme.grayMid
            }
            Column {
                id: content
                width: flick.width - 8
                spacing: 8

                // search results
                Column {
                    visible: app.searching
                    width: parent.width; spacing: 4
                    Txt { visible: app.results.length === 0; text: Labels.t("noResults"); color: Theme.grayMid }
                    Repeater {
                        model: app.results
                        delegate: SettingRow { required property var modelData; entry: modelData; crumb: true; width: content.width
                            MouseArea { anchors.fill: parent; z: -1; onClicked: { app.query = ""; input.text = ""; app.page = modelData.page } } }
                    }
                }

                // regular page
                // pages with their own file; the size is reset explicitly so a previous page never leaves a gap
                Loader {
                    active: !!app.pageFile(app.page)
                    visible: active && !app.searching
                    width: parent.width
                    height: active && item ? item.implicitHeight : 0
                    source: active ? app.pageFile(app.page) + ".qml" : ""
                }
                EntryList { visible: !app.searching && !app.pageFile(app.page); page: app.page }
            }
        }
    }
}
