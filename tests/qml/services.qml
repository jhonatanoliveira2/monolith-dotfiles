import QtQuick
import Quickshell
import "core"
import "services"

// Harness for tests/test-shell.sh: instantiates every singleton of core/ and services/ (no windows, Qt
// "offscreen" platform), so a QML error in any of them shows up in the log, then runs the action named by
// MONOLITH_TEST and quits:
//   ytm     one YouTube Music API call with a token, against the port in MONOLITH_TEST_PORT
//   vscode  writes the theme colours into the VS Code settings files of this HOME
//   notifs  sends itself 25 short notifications (private session bus) and reports what is still held
//   bt      feeds the pairing agent the prompts bluetoothctl prints and reports how each one was understood
//   nothingfile  writes nothing.json while the shell runs (nothing-theme.sh on) and reports whether the
//                current wallpaper is shown again (Nothing.wallpaperChanged), which the startup read must not do
//   nothingoff   the same when nothing.json is removed (nothing-theme.sh off)
ShellRoot {
    id: root
    readonly property string action: Quickshell.env("MONOLITH_TEST") || ""
    readonly property var singletons: [Config, Palettes, Popups, Settings, Strings, Theme, BarTheme, Distro, Nothing,
        Splash, Audio, BarLayout, Battery, Brightness, Displays, Bt, Media, Net, Notifs, Osd, Profile, QuickMenu, Stats,
        Perf, Lyrics, Weather, Widgets, Sys, Themes, Wallpapers, Binds, MicFx, AudioFx, Jobs]

    property int wallpaperChanges: 0
    Connections { target: Nothing; function onWallpaperChanged() { root.wallpaperChanges++ } }

    Timer {
        interval: 800; running: true
        onTriggered: {
            console.log("RESULT wallpaperAtStart=" + root.wallpaperChanges)
            console.log("RESULT nothing=" + Nothing.available + "/" + Nothing.active + " bar=" + Settings.barPosition + "/" + Settings.barStyle + " lookDone=" + Settings.nothingLookDone)
            console.log("RESULT singletons=" + root.singletons.filter(s => s !== null && s !== undefined).length + "/" + root.singletons.length)
            if (root.action === "ytm") {
                Settings.ytmPort = Number(Quickshell.env("MONOLITH_TEST_PORT"))
                Settings.ytmToken = "s3cret-token"
                Media.ytm("POST", "toggle-play", "")
            } else if (root.action === "vscode") Themes.writeCode()
            else if (root.action === "nothingfile")
                Jobs.run("test", ["sh", "-c", "mkdir -p \"$HOME/.config/monolith\" && printf '{ \"defaults\": { \"enabled\": true } }' >\"$HOME/.config/monolith/nothing.json\""],
                    { timeout: 5000 }, ok => console.log("RESULT written=" + ok))
            else if (root.action === "nothingoff")
                Jobs.run("test", ["rm", "-f", Quickshell.env("HOME") + "/.config/monolith/nothing.json"], { timeout: 5000 }, ok => console.log("RESULT removed=" + ok))
            else if (root.action === "notifs") {
                // 25 notifications that expire after 0.3 s, with a history limited to 10
                Settings.notifHistoryMax = 10
                Jobs.run("test", ["sh", "-c", "for i in $(seq 25); do gdbus call --session --dest org.freedesktop.Notifications "
                    + "--object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.Notify "
                    + "test 0 '' \"n$i\" body '[]' '{}' 300 >/dev/null || exit 1; done"], { timeout: 10000 }, ok => console.log("RESULT sent=" + ok))
            } else if (root.action === "bt") {
                // what `bluetoothctl --agent KeyboardDisplay` prints (BlueZ client/agent.c), fed in pieces as a terminal
                // would deliver it: prompts wait without a line break and come with colour escapes
                const esc = "\x1b[0;94m", off = "\x1b[0m"
                const steps = [
                    ["Agent registered\r\n", null],
                    ["[agent] Confirm pass", null],
                    ["key 123456 (yes/no): ", "confirm:123456"],
                    ["\r\nRequest canceled\r\n", "-"],
                    [esc + "[agent]" + off + " Enter PIN code: ", "pin:"],
                    ["\r\nRequest canceled\r\n[agent] Enter passkey (number in 0-999999): ", "passkey:"],
                    ["\r\nRequest canceled\r\n[agent] Accept pairing (yes/no): ", "authorize:"],
                    ["\r\nRequest canceled\r\n[agent] Authorize service 0000110b-0000-1000-8000-00805f9b34fb (yes/no): ", "service:0000110b-0000-1000-8000-00805f9b34fb"],
                    ["\r\nRequest canceled\r\n[agent] Passkey: 654321\r\n", "display:654321"],
                    ["Request canceled\r\n[agent] PIN code: 0000\r\n", "display:0000"],
                    ["[CHG] Device AA:BB:CC:DD:EE:FF Connected: yes\r\n", "display:0000"]
                ]
                const got = []
                for (const st of steps) {
                    Bt.feed(st[0])
                    const r = Bt.request
                    got.push((r ? r.kind + ":" + r.code : "-") === (st[1] === null ? "-" : st[1]) ? "ok" : "BAD(" + (r ? r.kind + ":" + r.code : "-") + ")")
                }
                console.log("RESULT bt=" + got.join(","))
            }
            done.start()
        }
    }
    Timer {
        id: done; interval: root.action === "notifs" ? 4000 : root.action.indexOf("nothing") === 0 ? 6000 : 1800
        onTriggered: {
            if (root.action.indexOf("nothing") === 0)
                console.log("RESULT nothingfile=" + Nothing.available + "/" + root.wallpaperChanges)
            if (root.action === "notifs")
                console.log("RESULT notifs=history:" + Notifs.count + " popups:" + Notifs.popups.length + " expiry:" + Object.keys(Notifs.expiry).length + " held:" + Object.keys(Notifs.held).length)
            Qt.quit()
        }
    }
}
