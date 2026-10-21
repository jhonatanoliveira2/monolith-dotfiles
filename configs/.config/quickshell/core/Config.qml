pragma Singleton
import QtQuick
import Quickshell

// Everything meant to be tweaked by hand lives here.
Singleton {
    property string language: "en"             // "pt" | "en"  (see Strings.qml)
    property bool animations: true             // false: no transitions at all (lowest GPU use)
    property bool builtinNotifications: true   // false: keep swaync / another daemon as the notification server
    property bool showPlayer: true
    property bool showSysmon: true
    property int titleMax: 12                  // characters of the track title shown in the bar
    property int volumeStep: 2                 // % per wheel notch
    property int toastTimeout: 6000            // ms (critical notifications stay until dismissed)

    // Commands used by the settings menu
    property var lockCommand: ["hyprlock"]
    property var wallpaperCommand: ["wallpaper-menu"]
    property var logoutCommand: ["hyprctl", "dispatch", "hl.dsp.exit()"]
    property var hyprKeyword: ["hyprctl", "keyword"]   // runtime option changes (one place to adapt)
}
