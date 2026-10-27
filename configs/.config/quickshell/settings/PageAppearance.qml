import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

// Quick menu editor (sections: order and visibility; switches; shortcuts: built-in, app command or Settings
// page; session buttons) and the bar clock (Registry entries + live preview). Data: services/QuickMenu.qml.
Column {
    id: root
    spacing: 4
    property string addKind: "builtin"

    // a framed one-line text input with a placeholder
    component Field: Rectangle {
        property alias text: inp.text
        property string hint: ""
        signal accepted()
        height: 30; color: "transparent"; border.width: 1; border.color: inp.activeFocus ? Theme.white : Theme.line
        TextInput {
            id: inp
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize
            clip: true; selectByMouse: true
            onAccepted: parent.accepted()
            Txt { visible: inp.text === ""; anchors.fill: parent; text: parent.parent.hint; color: Theme.grayMid; font.bold: false }
        }
    }
    // a row with a title and controls on the right
    component Line: Rectangle {
        default property alias controls: ctl.data
        property string title: ""
        property string glyph: ""
        width: parent ? parent.width : 600; height: 44
        color: "transparent"; border.width: 1; border.color: Theme.line
        Txt { id: gl; visible: text !== ""; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 20; text: parent.glyph; color: Theme.grayMid }
        Txt { anchors { left: gl.visible ? gl.right : parent.left; leftMargin: gl.visible ? 8 : 12; right: ctl.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
              text: parent.title; color: Theme.foreground }
        Row { id: ctl; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } spacing: 4 }
    }

    // ── sections ──
    CatHeader { first: true; width: parent.width; text: Labels.t("cat_quickSections") }
    Repeater {
        model: QuickMenu.sections
        delegate: Line {
            required property var modelData
            required property int index
            title: Labels.t("qs_" + modelData.id)
            Btn { compact: true; text: Theme.g(0xf077); enabled: index > 0; onActivated: QuickMenu.moveSection(index, -1) }
            Btn { compact: true; text: Theme.g(0xf078); enabled: index < QuickMenu.sections.length - 1; onActivated: QuickMenu.moveSection(index, 1) }
            Toggle { anchors.verticalCenter: parent.verticalCenter; checked: modelData.on; onToggled: c => QuickMenu.setSection(modelData.id, c) }
        }
    }

    // ── quick switches ──
    CatHeader { width: parent.width; text: Labels.t("cat_quickToggles") }
    Flow {
        width: parent.width; spacing: 4
        Repeater {
            model: QuickMenu.toggleCatalog.filter(t => !t.when || t.when())
            delegate: Btn {
                required property var modelData
                compact: true; icon: modelData.icon; text: modelData.label()
                active: Array.from(Settings.quickToggles || []).indexOf(modelData.id) >= 0
                onActivated: QuickMenu.flip("quickToggles", modelData.id)
            }
        }
    }

    // ── shortcuts ──
    CatHeader { width: parent.width; text: Labels.t("cat_quickShortcuts") }
    Txt { visible: QuickMenu.shortcuts.length === 0; x: 12; text: Labels.t("qNone"); color: Theme.grayMid }
    Repeater {
        model: QuickMenu.shortcuts
        delegate: Line {
            required property var modelData
            required property int index
            glyph: QuickMenu.icon(modelData)
            title: QuickMenu.label(modelData) + "   ·   " + Labels.t(modelData.k === "builtin" ? "qkBuiltin" : modelData.k === "page" ? "qkPage" : "qkApp")
                   + (modelData.k === "app" ? ": " + modelData.v : "")
            Btn { compact: true; text: Theme.g(0xf077); enabled: index > 0; onActivated: QuickMenu.moveShortcut(index, -1) }
            Btn { compact: true; text: Theme.g(0xf078); enabled: index < QuickMenu.shortcuts.length - 1; onActivated: QuickMenu.moveShortcut(index, 1) }
            Btn { compact: true; text: Theme.glyph.close; onActivated: QuickMenu.removeShortcut(index) }
        }
    }
    // add a shortcut
    Rectangle {
        width: parent.width; height: add.implicitHeight + 20
        color: "transparent"; border.width: 1; border.color: Theme.line
        Column {
            id: add
            x: 10; y: 10; width: parent.width - 20; spacing: 8
            Row {
                spacing: 4
                Txt { anchors.verticalCenter: parent.verticalCenter; text: Labels.t("qAdd") + "  "; color: Theme.grayLight }
                Repeater {
                    model: ["builtin", "app", "page"]
                    delegate: Btn { required property string modelData; compact: true; active: root.addKind === modelData
                                    text: Labels.t(modelData === "builtin" ? "qkBuiltin" : modelData === "page" ? "qkPage" : "qkApp"); onActivated: root.addKind = modelData }
                }
            }
            // built-ins not in the menu yet
            Flow {
                visible: root.addKind === "builtin"
                width: parent.width; spacing: 4
                Repeater {
                    model: QuickMenu.builtins.filter(b => !QuickMenu.shortcuts.some(s => s.k === "builtin" && s.v === b.id))
                    delegate: Btn { required property var modelData; compact: true; icon: modelData.icon; text: QuickMenu.label({ k: "builtin", v: modelData.id })
                                    onActivated: QuickMenu.addShortcut("builtin", modelData.id, "") }
                }
            }
            // an app: name + shell command
            Row {
                visible: root.addKind === "app"
                width: parent.width; spacing: 6
                Field { id: appName; width: (parent.width - 90) * 0.35; hint: Labels.t("qLabel") }
                Field { id: appCmd; width: (parent.width - 90) * 0.65; hint: Labels.t("qCommand"); onAccepted: appAdd.activated() }
                Btn { id: appAdd; compact: true; width: 72; text: Labels.t("qAddBtn")
                      onActivated: { QuickMenu.addShortcut("app", appCmd.text, appName.text); appCmd.text = ""; appName.text = "" } }
            }
            // a Settings page
            Flow {
                visible: root.addKind === "page"
                width: parent.width; spacing: 4
                Repeater {
                    model: Registry.pages
                    delegate: Btn { required property var modelData; compact: true; icon: String.fromCodePoint(modelData.glyph); text: Labels.t("page_" + modelData.id)
                                    onActivated: QuickMenu.addShortcut("page", modelData.id, Labels.t("page_" + modelData.id)) }
                }
            }
        }
    }

    // ── session ──
    CatHeader { width: parent.width; text: Labels.t("cat_quickSession") }
    Flow {
        width: parent.width; spacing: 4
        Repeater {
            model: QuickMenu.sessionCatalog
            delegate: Btn {
                required property var modelData
                compact: true; icon: modelData.icon; text: Strings.t(modelData.id)
                active: Array.from(Settings.quickSession || []).indexOf(modelData.id) >= 0
                onActivated: QuickMenu.flip("quickSession", modelData.id)
            }
        }
    }
    Item { width: 1; height: 4 }
    Row {
        spacing: 6
        Btn { compact: true; icon: Theme.g(0xf0c9); text: Labels.t("qOpen"); onActivated: { Popups.closeApp(); Popups.toggleFocused("settings") } }
        Btn { compact: true; text: Labels.t("qReset"); confirm: true; onActivated: QuickMenu.reset() }
    }

    // ── clock ──
    EntryList { page: "appearance"; first: false; width: parent.width }
    Line {
        SystemClock { id: clk; precision: SystemClock.Seconds }
        title: Labels.t("clockPreview")
        Txt { anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDateTime(clk.date, Settings.clockPattern); color: Theme.white }
    }
    Txt { x: 12; width: parent.width - 24; wrapMode: Text.Wrap; elide: Text.ElideNone; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
          text: Labels.t("clockHelp") }
}
