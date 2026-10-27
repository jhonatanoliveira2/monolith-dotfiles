import QtQuick
import Quickshell
import "../core"

// Creates an overlay (launcher, wallpaper picker) only while it is open on this screen, plus its close animation.
Scope {
    id: slot
    property string name: ""
    property var screen: null
    default property Component overlay
    readonly property bool wanted: Popups.overlay === name && screen !== null && Popups.overlayScreen === screen.name
    onWantedChanged: if (!wanted) linger.restart()
    Timer { id: linger; interval: Theme.dur(260) + 60 }
    LazyLoader { active: slot.wanted || linger.running; component: slot.overlay }
}
