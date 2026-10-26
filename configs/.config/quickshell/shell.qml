//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "core"
import "services"
import "menus"
import "settings"
import "components"

// MONOLITH shell: bar + menus + notifications. Start with `quickshell` (or `qs`).
ShellRoot {
    Component.onCompleted: Sys.init()

    SettingsWindow {}

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: scope
            required property var modelData

            Bar { id: barWin; modelData: scope.modelData }
            MenuSlot { name: "audio"; screen: scope.modelData; AudioMenu { screen: scope.modelData; bar: barWin } }
            MenuSlot { name: "media"; screen: scope.modelData; MediaMenu { screen: scope.modelData; bar: barWin } }
            MenuSlot { name: "network"; screen: scope.modelData; NetworkMenu { screen: scope.modelData; bar: barWin } }
            MenuSlot { name: "bluetooth"; screen: scope.modelData; BluetoothMenu { screen: scope.modelData; bar: barWin } }
            MenuSlot { name: "power"; screen: scope.modelData; PowerMenu { screen: scope.modelData; bar: barWin } }
            MenuSlot { name: "brightness"; screen: scope.modelData; BrightnessMenu { screen: scope.modelData; bar: barWin } }
            MenuSlot { name: "notifications"; screen: scope.modelData; NotificationCenter { screen: scope.modelData; bar: barWin } }
            MenuSlot { name: "calendar"; screen: scope.modelData; CalendarMenu { screen: scope.modelData; bar: barWin } }
            MenuSlot { name: "stats"; screen: scope.modelData; StatsMenu { screen: scope.modelData; bar: barWin } }
            MenuSlot { name: "settings"; screen: scope.modelData; SettingsMenu { screen: scope.modelData; bar: barWin } }
            LazyLoader { active: Notifs.popups.length + Notifs.internal.length > 0; Toasts { screen: scope.modelData } }
            OsdWindow { screen: scope.modelData }
        }
    }

    // ── Hyprland global shortcuts (bound in hypr/modules/media-keys.lua and keybindings.lua
    //    with hl.dsp.global("quickshell:<name>")) ────────────────────────────────────────────
    component Key: GlobalShortcut { appid: "quickshell" }
    Key { name: "volumeUp"; onPressed: { Audio.nudge(5); Osd.show("volume") } }
    Key { name: "volumeDown"; onPressed: { Audio.nudge(-5); Osd.show("volume") } }
    Key { name: "volumeMute"; onPressed: { Audio.toggleMute(); Osd.show("volume") } }
    Key { name: "micMute"; onPressed: { Audio.toggleMic(); Osd.show("mic") } }
    Key { name: "brightnessUp"; onPressed: { Brightness.nudge(5); Osd.show("brightness") } }
    Key { name: "brightnessDown"; onPressed: { Brightness.nudge(-5); Osd.show("brightness") } }
    Key { name: "touchpadToggle"; onPressed: { Sys.setTouchpad(!Settings.touchpadEnabled); Osd.show("touchpad") } }
    Key { name: "kbdUp"; onPressed: { Brightness.kbdNudge(1); Osd.show("kbd") } }
    Key { name: "kbdDown"; onPressed: { Brightness.kbdNudge(-1); Osd.show("kbd") } }
    Key { name: "kbdCycle"; onPressed: { Brightness.setKbd(Brightness.kbdCurrent >= Brightness.kbdMax ? 0 : Brightness.kbdCurrent + 1); Osd.show("kbd") } }
    Key { name: "mediaToggle"; onPressed: { Media.toggle(); Osd.show("media") } }
    Key { name: "mediaNext"; onPressed: { Media.next(); Osd.show("media") } }
    Key { name: "mediaPrev"; onPressed: { Media.previous(); Osd.show("media") } }
    Key { name: "notifications"; onPressed: Popups.toggleFocused("notifications") }
    Key { name: "media"; onPressed: Popups.toggleFocused("media") }
    Key { name: "session"; onPressed: Popups.toggleFocused("settings") }
    Key { name: "settingsApp"; onPressed: Popups.appOpen ? Popups.closeApp() : Popups.openApp("system") }

    // Key bindings:  qs ipc call shell toggle settings   |   qs ipc call shell close
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Popups.toggleFocused(name) }
        function close(): void { Popups.close() }
        function settings(page: string): void { Popups.openApp(page) }
        function dnd(): void { Settings.dnd = !Settings.dnd }
        function reload(): void { Quickshell.reload(true) }
    }

    IpcHandler {
        target: "media"
        function toggle(): void { Media.toggle() }
        function next(): void { Media.next() }
        function previous(): void { Media.previous() }
        function seek(seconds: real): void { Media.seekBy(seconds) }
        function search(query: string): void { Media.searchProvider(query) }
    }

    // Screenshot bindings: `qs ipc call screenshot notify <file>` shows a toast with a preview
    IpcHandler {
        target: "screenshot"
        function notify(path: string): void { Notifs.toast(Strings.t("screenshot"), Strings.t("screenshotBody"), path) }
    }
}
