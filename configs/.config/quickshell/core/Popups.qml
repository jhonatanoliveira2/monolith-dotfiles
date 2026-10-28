pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which menu is open, on which screen, and where it hangs from.
// Menus open on click; with Settings.hoverMenus they also follow the pointer once one is open.
Singleton {
    id: root
    property string current: ""
    property string screenName: ""
    property real anchorX: 0
    property real anchorY: 0            // center of the button in its bar (menus of a vertical bar use it)
    property var buttons: ({})
    property bool pinned: false          // opened by click / shortcut: hover-out does not close it

    // Settings app (window or overlay, see settings/SettingsWindow.qml)
    property bool appOpen: false
    property string appPage: "system"
    function openApp(page) { appPage = page || "system"; appOpen = true; close() }
    function closeApp() { appOpen = false }

    // first-run welcome (menus/Welcome.qml), on the focused monitor
    property bool welcomeOpen: false
    property string welcomeScreen: ""
    function openWelcome() { welcomeScreen = focusedScreen(); close(); closeOverlay(); welcomeOpen = true }
    function closeWelcome() { welcomeOpen = false }

    function focusedScreen() {
        const m = Hyprland.focusedMonitor
        return m ? m.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
    }

    // full-screen overlays (app launcher, wallpaper picker): one at a time, on the focused monitor
    property string overlay: ""
    property string overlayScreen: ""
    function toggleOverlay(name) {
        if (overlay === name) { overlay = ""; return }
        overlayScreen = focusedScreen()
        close()
        overlay = name
    }
    function closeOverlay() { overlay = "" }

    Timer { id: closeTimer; interval: 350; onTriggered: if (!root.pinned) root.close() }

    function register(screen, name, item) { buttons[screen + ":" + name] = item }
    function cancelClose() { closeTimer.stop() }
    function scheduleClose() { if (current !== "" && !pinned) closeTimer.restart() }

    function close() {
        closeTimer.stop()
        current = ""
        pinned = false
    }

    function show(name, screen, item) {
        if (!name || !screen) return
        closeTimer.stop()
        const it = item || buttons[screen + ":" + name]
        const p = it ? it.mapToItem(null, it.width / 2, it.height / 2) : null
        anchorX = p ? p.x : 0
        anchorY = p ? p.y : 0
        screenName = screen
        current = name
    }

    // Hovering a bar button: switch menus only when another one is already open (no surprise popups).
    function hover(name, screen, item) {
        if (!Settings.hoverMenus || current === "" || current === name) { cancelClose(); return }
        if (screenName === screen) show(name, screen, item)
    }

    function toggle(name, screen, item) {
        if (current === name && screenName === screen) { close(); return }
        show(name, screen, item)
        pinned = true
    }

    // Used by IPC / global shortcuts: opens the menu on the focused monitor.
    function toggleFocused(name) {
        toggle(name, focusedScreen(), null)
    }
}
