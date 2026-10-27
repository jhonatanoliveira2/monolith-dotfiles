import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"
import "../settings"

// Quick menu (Arch button): profile, quick switches, sliders, Hyprland options, shortcuts and session actions.
// Which sections show, their order and the buttons inside are chosen in Settings > Appearance.
MenuWindow {
    menu: "settings"
    panelWidth: 400
    maxHeight: 760

    Column {
        id: col
        width: parent.width
        spacing: 2
        Component.onCompleted: Sys.refresh()

        // sections in the order chosen in Settings > Appearance (services/QuickMenu.qml)
        Repeater {
            model: QuickMenu.sections.filter(s => s.on)
            delegate: Loader {
                required property var modelData
                width: col.width
                sourceComponent: ({ header: header, settings: settingsBtn, toggles: toggles, sliders: sliders,
                                    hyprland: hyprland, shortcuts: shortcuts, session: session })[modelData.id]
            }
        }

        Component {
            id: header
            Item {
                height: Settings.profileInMenu ? 58 : 36
                // profile card
                Row {
                    visible: Settings.profileInMenu
                    x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    Avatar { width: 40; height: 40; anchors.verticalCenter: parent.verticalCenter; source: Profile.avatar; initial: Profile.initial }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 2
                        Txt { text: Profile.name; color: Theme.white; font.pixelSize: 15 }
                        Txt { text: Profile.subtitle; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                    }
                }
                Row {
                    visible: !Settings.profileInMenu
                    x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Avatar { visible: Settings.profileAsLogo; width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter; source: Profile.avatar; initial: Profile.initial }
                    Txt { text: (Settings.profileAsLogo ? "" : Theme.glyph.arch + "   ") + "MONOLITH"; color: Theme.white; font.pixelSize: 15 }
                }
            }
        }
        Component {
            id: settingsBtn
            Btn { icon: Theme.glyph.cog; text: Labels.t("settingsTitle"); onActivated: Popups.openApp("system") }
        }
        Component {
            id: toggles
            Column {
                visible: QuickMenu.toggles.length > 0
                spacing: 2
                Section { width: parent.width; text: Strings.t("quick") }
                Repeater {
                    model: QuickMenu.toggles
                    delegate: ToggleRow {
                        required property var modelData
                        visible: !modelData.when || modelData.when()
                        width: parent.width; icon: modelData.icon; label: modelData.label()
                        checked: modelData.get(); onToggled: c => modelData.set(c)
                    }
                }
            }
        }
        Component {
            id: sliders
            Column {
                Item {
                    width: parent.width; height: 30
                    Txt { id: vi; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } width: 20; text: Audio.glyph(); font.pixelSize: 15; color: Theme.grayMid }
                    ThinSlider { anchors { left: vi.right; leftMargin: 8; right: vp.left; rightMargin: 10; verticalCenter: parent.verticalCenter } value: Audio.volume; onMoved: v => Audio.setVolume(v) }
                    Txt { id: vp; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } width: 40; horizontalAlignment: Text.AlignRight; text: Math.round(Audio.volume * 100) + "%" }
                }
                Item {
                    visible: Brightness.available
                    width: parent.width; height: 30
                    Txt { id: bi; anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } width: 20; text: Theme.glyph.backlight; font.pixelSize: 15; color: Theme.grayMid }
                    ThinSlider { anchors { left: bi.right; leftMargin: 8; right: bp.left; rightMargin: 10; verticalCenter: parent.verticalCenter } value: Brightness.fraction; onMoved: v => Brightness.set(v) }
                    Txt { id: bp; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } width: 40; horizontalAlignment: Text.AlignRight; text: Math.round(Brightness.fraction * 100) + "%" }
                }
            }
        }
        Component {
            id: hyprland
            Column {
                spacing: 2
                Section { width: parent.width; text: "Hyprland" }
                ToggleRow { width: parent.width; icon: Theme.glyph.animations; label: Strings.t("animations"); checked: !!Sys.values.animations; onToggled: c => Sys.setValue("animations", c ? 1 : 0) }
                ToggleRow { width: parent.width; icon: Theme.glyph.config; label: Strings.t("blur"); checked: !!Sys.values.blur; onToggled: c => Sys.setValue("blur", c ? 1 : 0) }
                ToggleRow { width: parent.width; icon: Theme.glyph.config; label: Strings.t("shadows"); checked: !!Sys.values.shadow; onToggled: c => Sys.setValue("shadow", c ? 1 : 0) }
                SettingSlider { width: parent.width; label: Strings.t("gapsIn"); from: 0; to: 30; value: Sys.values.gapsIn || 0; onCommit: v => Sys.setValue("gapsIn", v) }
                SettingSlider { width: parent.width; label: Strings.t("gapsOut"); from: 0; to: 60; value: Sys.values.gapsOut || 0; onCommit: v => Sys.setValue("gapsOut", v) }
                SettingSlider { width: parent.width; label: Strings.t("border"); from: 0; to: 8; value: Sys.values.borderSize || 0; suffix: "px"; onCommit: v => Sys.setValue("borderSize", v) }
                SettingSlider { width: parent.width; label: Strings.t("rounding"); from: 0; to: 20; value: Sys.values.rounding || 0; suffix: "px"; onCommit: v => Sys.setValue("rounding", v) }
            }
        }
        Component {
            id: shortcuts
            Column {
                visible: QuickMenu.shortcuts.length > 0
                spacing: 2
                Section { width: parent.width; text: Strings.t("desktop") }
                Flow {
                    width: parent.width; spacing: 4
                    Repeater {
                        model: QuickMenu.shortcuts
                        delegate: Btn { required property var modelData; compact: true; icon: QuickMenu.icon(modelData); text: QuickMenu.label(modelData); onActivated: QuickMenu.run(modelData) }
                    }
                }
            }
        }
        Component {
            id: session
            Column {
                visible: QuickMenu.session.length > 0
                spacing: 2
                Section { width: parent.width; text: Strings.t("session") }
                Flow {
                    width: parent.width; spacing: 4
                    Repeater {
                        model: QuickMenu.session
                        delegate: Btn { required property var modelData; compact: true; icon: modelData.icon; text: Strings.t(modelData.id); confirm: !!modelData.confirm; onActivated: modelData.run() }
                    }
                }
            }
        }
    }
}
