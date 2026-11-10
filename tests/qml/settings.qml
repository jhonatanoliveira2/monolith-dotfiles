import QtQuick
import Quickshell
import "core"

// Harness for tests/test-shell.sh: loads core/Settings.qml alone (no windows, Qt "offscreen" platform), waits
// for settings.json to be read, optionally changes one preference, then prints what happened as
// "RESULT key=value" lines and quits. MONOLITH_TEST_CHANGE=1 flips `dnd` after the load.
ShellRoot {
    id: root
    property bool sawCorrupted: false
    property string backup: ""
    function report() {
        console.log("RESULT loaded=" + Settings.loaded)
        console.log("RESULT dnd=" + Settings.dnd)
        console.log("RESULT volumeStep=" + Settings.volumeStep)
        console.log("RESULT loadError=" + (Settings.loadError ? "yes" : "no"))
        console.log("RESULT writeBlocked=" + Settings.writeBlocked)
        console.log("RESULT corrupted=" + root.sawCorrupted)
        console.log("RESULT backup=" + root.backup)
        Qt.quit()
    }
    Connections {
        target: Settings
        function onCorrupted(b) { root.sawCorrupted = true; root.backup = b }
    }
    // the load, the copy of an unusable file and the batched write are all asynchronous
    Timer {
        interval: 700; running: true
        onTriggered: { if (Quickshell.env("MONOLITH_TEST_CHANGE") === "1") Settings.dnd = !Settings.dnd; done.start() }
    }
    Timer { id: done; interval: 700; onTriggered: root.report() }
}
