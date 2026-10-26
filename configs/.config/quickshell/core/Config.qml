pragma Singleton
import QtQuick
import Quickshell

// Defaults live in Settings.qml (editable from the Settings app); the commands below are edited by hand.
Singleton {
    property string language: Settings.language
    property bool animations: Settings.shellAnimations
    property bool builtinNotifications: Settings.builtinNotifications
    property bool showPlayer: Settings.showPlayer
    property bool showSysmon: Settings.showSysmon
    // player title width in characters: grows with the text between these bounds (max is never below min)
    property int titleMin: Math.max(6, Math.min(40, Settings.titleMin))
    property int titleMax: Math.max(titleMin, Math.min(80, Settings.titleMax))
    property int volumeStep: Settings.volumeStep
    property real animationScale: Settings.animationScale
    property real barOpacity: Settings.barOpacity
    property real menuOpacity: Settings.menuOpacity
    property string settingsMode: Settings.settingsMode   // "window" | "overlay"
    property int toastTimeout: Settings.toastTimeout   // ms (critical notifications stay until dismissed, see Settings.criticalSticky)

    // Commands used by the settings menu
    property var lockCommand: ["hyprlock"]
    property var wallpaperCommand: ["wallpaper-menu"]
    property var logoutCommand: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && exec hyprshutdown || exec hyprctl dispatch 'hl.dsp.exit()'"]
    property var hyprEval: ["hyprctl", "eval"]   // runtime option changes go through the Lua API (hl.config)
}
