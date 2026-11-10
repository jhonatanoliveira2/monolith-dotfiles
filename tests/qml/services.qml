import QtQuick
import Quickshell
import "core"
import "services"

// Harness for tests/test-shell.sh: instantiates every singleton of core/ and services/ (no windows, Qt
// "offscreen" platform), so a QML error in any of them shows up in the log, then runs the action named by
// MONOLITH_TEST and quits:
//   ytm     one YouTube Music API call with a token, against the port in MONOLITH_TEST_PORT
//   vscode  writes the theme colours into the VS Code settings files of this HOME
ShellRoot {
    id: root
    readonly property string action: Quickshell.env("MONOLITH_TEST") || ""
    readonly property var singletons: [Config, Palettes, Popups, Settings, Strings, Theme, BarTheme, Distro, Nothing,
        Splash, Audio, BarLayout, Battery, Brightness, Displays, Bt, Media, Net, Notifs, Osd, Profile, QuickMenu, Stats,
        Perf, Lyrics, Weather, Widgets, Sys, Themes, Wallpapers, Binds, MicFx, AudioFx, Jobs]

    Timer {
        interval: 800; running: true
        onTriggered: {
            console.log("RESULT nothing=" + Nothing.available + "/" + Nothing.active + " bar=" + Settings.barPosition + "/" + Settings.barStyle + " lookDone=" + Settings.nothingLookDone)
            console.log("RESULT singletons=" + root.singletons.filter(s => s !== null && s !== undefined).length + "/" + root.singletons.length)
            if (root.action === "ytm") {
                Settings.ytmPort = Number(Quickshell.env("MONOLITH_TEST_PORT"))
                Settings.ytmToken = "s3cret-token"
                Media.ytm("POST", "toggle-play", "")
            } else if (root.action === "vscode") Themes.writeCode()
            done.start()
        }
    }
    Timer { id: done; interval: 1800; onTriggered: Qt.quit() }
}
