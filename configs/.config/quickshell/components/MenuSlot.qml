import QtQuick
import Quickshell
import "../core"

// Creates a menu window only while it is open (plus its fade-out): closed menus cost no memory.
Scope {
    id: slot
    property string name: ""
    property var screen: null
    default property Component menu
    readonly property bool wanted: Popups.current === name && screen !== null && Popups.screenName === screen.name
    onWantedChanged: if (!wanted) linger.restart()
    Timer { id: linger; interval: Theme.dur(220) + 80 }
    LazyLoader { active: slot.wanted || linger.running; component: slot.menu }
}
