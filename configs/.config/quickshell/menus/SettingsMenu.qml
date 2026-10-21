import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

// System menu: quick switches, sliders, Hyprland runtime options, shortcuts and session actions.
MenuWindow {
    menu: "settings"
    panelWidth: 400
    maxHeight: 760

    Column {
        id: col
        width: parent.width
        spacing: 2
        Component.onCompleted: Sys.refresh()
        function launch(cmd) { Popups.close(); Quickshell.execDetached(cmd) }

        Item {
            width: parent.width; height: 36
            Txt { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter } text: Theme.glyph.arch + "   MONOLITH"; color: Theme.white; font.pixelSize: 15 }
        }

        // ── quick switches ──
        Section { width: parent.width; text: Strings.t("quick") }
        ToggleRow { width: parent.width; icon: Theme.glyph.wifi; label: "Wi-Fi"; checked: Net.wifiEnabled; onToggled: c => Net.setWifi(c) }
        ToggleRow { width: parent.width; icon: Theme.glyph.bellOff; label: Strings.t("dnd"); checked: Settings.dnd; onToggled: c => Settings.dnd = c }
        ToggleRow { width: parent.width; icon: Theme.glyph.power; label: Strings.t("keepAwake"); checked: Settings.keepAwake; onToggled: c => Settings.keepAwake = c }
        ToggleRow { width: parent.width; icon: Theme.glyph.moon; label: Strings.t("darkMode"); checked: Sys.darkMode; onToggled: c => Sys.setDark(c) }

        // ── volume / brightness ──
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

        // ── Hyprland ──
        Section { width: parent.width; text: "Hyprland" }
        ToggleRow { width: parent.width; icon: Theme.glyph.animations; label: Strings.t("animations"); checked: !!Sys.values.animations; onToggled: c => Sys.setValue("animations", c ? 1 : 0) }
        ToggleRow { width: parent.width; icon: Theme.glyph.config; label: Strings.t("blur"); checked: !!Sys.values.blur; onToggled: c => Sys.setValue("blur", c ? 1 : 0) }
        ToggleRow { width: parent.width; icon: Theme.glyph.config; label: Strings.t("shadows"); checked: !!Sys.values.shadow; onToggled: c => Sys.setValue("shadow", c ? 1 : 0) }
        ToggleRow { width: parent.width; icon: Theme.glyph.config; label: "New Render Scheduling"; checked: !!Sys.values.newRenderScheduling; onToggled: c => Sys.setValue("newRenderScheduling", c ? 1 : 0) }
        SettingSlider { width: parent.width; label: Strings.t("gapsIn"); from: 0; to: 30; value: Sys.values.gapsIn || 0; onCommit: v => Sys.setValue("gapsIn", v) }
        SettingSlider { width: parent.width; label: Strings.t("gapsOut"); from: 0; to: 60; value: Sys.values.gapsOut || 0; onCommit: v => Sys.setValue("gapsOut", v) }
        SettingSlider { width: parent.width; label: Strings.t("border"); from: 0; to: 8; value: Sys.values.borderSize || 0; suffix: "px"; onCommit: v => Sys.setValue("borderSize", v) }
        SettingSlider { width: parent.width; label: Strings.t("rounding"); from: 0; to: 20; value: Sys.values.rounding || 0; suffix: "px"; onCommit: v => Sys.setValue("rounding", v) }

        // ── shortcuts ──
        Section { width: parent.width; text: Strings.t("desktop") }
        Flow {
            width: parent.width; spacing: 4
            Btn { compact: true; text: Strings.t("wallpaper"); onActivated: col.launch(Config.wallpaperCommand) }
            Btn { compact: true; text: Strings.t("mixer"); onActivated: col.launch(["pavucontrol"]) }
            Btn { compact: true; text: Strings.t("network"); onActivated: col.launch(["nm-connection-editor"]) }
            Btn { compact: true; text: "Bluetooth"; onActivated: col.launch(["blueman-manager"]) }
            Btn { compact: true; text: Strings.t("gtkTheme"); onActivated: col.launch(["nwg-look"]) }
            Btn { compact: true; text: Strings.t("reloadHypr"); onActivated: { Sys.reloadHyprland() } }
            Btn { compact: true; text: Strings.t("reloadShell"); onActivated: Quickshell.reload(true) }
        }

        // ── session ──
        Section { width: parent.width; text: Strings.t("session") }
        Flow {
            width: parent.width; spacing: 4
            Btn { compact: true; icon: Theme.glyph.lock; text: Strings.t("lock"); onActivated: { Popups.close(); Sys.lock() } }
            Btn { compact: true; icon: Theme.glyph.sleep; text: Strings.t("suspend"); onActivated: { Popups.close(); Sys.suspend() } }
            Btn { compact: true; icon: Theme.glyph.out; text: Strings.t("logout"); confirm: true; onActivated: Sys.logout() }
            Btn { compact: true; icon: Theme.glyph.reboot; text: Strings.t("reboot"); confirm: true; onActivated: Sys.reboot() }
            Btn { compact: true; icon: Theme.glyph.power; text: Strings.t("poweroff"); confirm: true; onActivated: Sys.poweroff() }
        }
    }
}
