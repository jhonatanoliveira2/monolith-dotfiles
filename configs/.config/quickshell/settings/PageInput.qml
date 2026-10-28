import QtQuick
import "../core"
import "../components"
import "../services"

// Keyboard / mouse / touchpad options (Registry) + the Hyprland key binds by category (services/Binds.qml).
// Each bind: modifier switches + the key name (Enter applies, empty = off); changes reload Hyprland.
Column {
    id: root
    width: parent ? parent.width : 600
    spacing: 4
    function tr(pt, en) { return Config.language === "en" ? en : pt }

    EntryList { page: "input"; width: parent.width }

    Txt {
        visible: !Binds.available
        width: parent.width
        topPadding: 18
        text: root.tr("~/.config/hypr/modules/bind-defaults.lua não encontrado: os atalhos não podem ser editados.",
                      "~/.config/hypr/modules/bind-defaults.lua not found: binds can't be edited.")
        color: Theme.grayMid
    }

    Repeater {
        model: Binds.available ? Binds.categories : []
        delegate: Column {
            id: cat
            required property var modelData
            required property int index
            width: root.width
            spacing: 4
            CatHeader { width: parent.width; text: modelData.label[Config.language === "en" ? 1 : 0] }

            // hint + reset all, once above the first category
            Item {
                visible: cat.index === 0
                width: parent.width
                height: visible ? 34 : 0
                Txt {
                    anchors { left: parent.left; right: resetAll.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: root.tr("Nome da tecla: A, Return, comma, F1, XF86AudioMute, mouse:272…  ·  vazio desativa",
                                  "Key name: A, Return, comma, F1, XF86AudioMute, mouse:272…  ·  empty turns it off")
                    color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
                }
                Btn {
                    id: resetAll
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    compact: true
                    confirm: true
                    visible: Object.keys(Binds.overrides).length > 0
                    icon: Theme.glyph.refresh
                    text: root.tr("Restaurar todos", "Reset all")
                    onActivated: Binds.resetAll()
                }
            }

            Repeater {
                model: Binds.inCategory(cat.modelData.id)
                delegate: Rectangle {
                    id: row
                    required property string modelData
                    readonly property string bid: modelData
                    readonly property var parts: Binds.split(Binds.combo(bid))
                    readonly property var clash: Binds.conflicts(bid)
                    width: cat.width
                    height: 44
                    color: hov.hovered ? Theme.hover : "transparent"
                    border.width: 1
                    border.color: Theme.line
                    HoverHandler { id: hov }

                    function apply(mods, key) { Binds.set(bid, Binds.join(mods, key)) }
                    function toggleMod(m) {
                        const mods = parts.mods.slice()
                        const i = mods.indexOf(m)
                        if (i >= 0) mods.splice(i, 1); else mods.push(m)
                        apply(mods, parts.key)
                    }

                    Column {
                        anchors { left: parent.left; leftMargin: 12; right: controls.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        Txt {
                            width: parent.width
                            text: Binds.label(row.bid) + (Binds.changed(row.bid) ? "  " + Theme.glyph.dot : "")
                            color: Theme.foreground
                        }
                        Txt {
                            visible: row.clash.length > 0 || row.parts.key === ""
                            width: parent.width
                            text: row.parts.key === "" ? root.tr("Desativado", "Off")
                                : root.tr("Conflito: ", "Conflict: ") + row.clash.map(x => Binds.label(x)).join(", ")
                            color: row.parts.key === "" ? Theme.grayDark : Theme.accent
                            font.pixelSize: Theme.small
                        }
                    }

                    Row {
                        id: controls
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Repeater {
                            model: Binds.modNames
                            delegate: Btn {
                                required property string modelData
                                compact: true
                                text: modelData.charAt(0) + modelData.slice(1).toLowerCase()
                                active: row.parts.mods.indexOf(modelData) >= 0
                                onActivated: row.toggleMod(modelData)
                            }
                        }
                        Rectangle {
                            width: 150; height: 26
                            color: "transparent"
                            border.width: 1
                            border.color: !Binds.validKey(input.text.trim()) ? Theme.accent : input.activeFocus ? Theme.white : Theme.line
                            TextInput {
                                id: input
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
                                text: row.parts.key
                                clip: true; selectByMouse: true
                                function commit() {
                                    const k = text.trim()
                                    if (Binds.validKey(k) && k !== row.parts.key) row.apply(row.parts.mods, k)
                                    text = Qt.binding(() => row.parts.key)
                                }
                                onAccepted: { commit(); focus = false }
                                onActiveFocusChanged: if (!activeFocus) commit()
                                Keys.onEscapePressed: event => { text = Qt.binding(() => row.parts.key); focus = false; event.accepted = true }
                            }
                            Txt {
                                visible: input.text === "" && !input.activeFocus
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                text: "—"; color: Theme.grayDark
                            }
                        }
                        Btn {
                            compact: true
                            width: 30
                            opacity: Binds.changed(row.bid) ? 1 : 0.3
                            enabled: Binds.changed(row.bid)
                            text: Theme.glyph.refresh
                            onActivated: Binds.reset(row.bid)
                        }
                    }
                }
            }
        }
    }
}
