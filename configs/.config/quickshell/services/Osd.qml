pragma Singleton
import QtQuick
import Quickshell
import "../core"

// What the on-screen display shows (volume | mic | brightness | kbd | touchpad | media) and for how long.
Singleton {
    id: root
    property string kind: ""
    property bool visible: false
    function show(k) {
        if (!Settings.osd) return
        kind = k
        visible = true
        hide.restart()
    }
    Timer { id: hide; interval: 1400; onTriggered: root.visible = false }
}
