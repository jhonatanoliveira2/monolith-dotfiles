//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "menus"

// MONOLITH shell: bar + menus + notifications. Start with `quickshell` (or `qs`).
ShellRoot {
    Component.onCompleted: Sys.init()

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: scope
            required property var modelData

            Bar { id: bar; modelData: scope.modelData }
            AudioMenu { screen: scope.modelData; bar: bar }
            NetworkMenu { screen: scope.modelData; bar: bar }
            BluetoothMenu { screen: scope.modelData; bar: bar }
            PowerMenu { screen: scope.modelData; bar: bar }
            NotificationCenter { screen: scope.modelData; bar: bar }
            CalendarMenu { screen: scope.modelData; bar: bar }
            StatsMenu { screen: scope.modelData; bar: bar }
            SettingsMenu { screen: scope.modelData; bar: bar }
            Toasts { screen: scope.modelData }
        }
    }

    // Key bindings:  qs ipc call shell toggle settings   |   qs ipc call shell close
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Popups.toggleFocused(name) }
        function close(): void { Popups.close() }
        function dnd(): void { Settings.dnd = !Settings.dnd }
        function reload(): void { Quickshell.reload(true) }
    }

    // Compatibility with the screenshot bindings (`qs ipc call screenshot notify`)
    IpcHandler {
        target: "screenshot"
        function notify(): void { Notifs.toast(Strings.t("screenshot"), Strings.t("screenshotBody")) }
    }
}
