pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Preferences saved in ~/.local/state/quickshell-monolith/settings.json.
// Hyprland values use -1 = "not touched from the menu" (your hyprland.lua stays in charge).
Singleton {
    id: root
    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias gapsIn: adapter.gapsIn
    property alias gapsOut: adapter.gapsOut
    property alias borderSize: adapter.borderSize
    property alias rounding: adapter.rounding
    property alias animations: adapter.animations
    property alias blur: adapter.blur
    property alias shadow: adapter.shadow
    property alias vfr: adapter.vfr

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell-monolith"
    property bool ready: false

    Process {
        command: ["mkdir", "-p", root.dir]
        running: true
        onExited: root.ready = true
    }

    FileView {
        path: root.ready ? root.dir + "/settings.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        adapter: JsonAdapter {
            id: adapter
            property bool dnd: false
            property bool keepAwake: false
            property int gapsIn: -1
            property int gapsOut: -1
            property int borderSize: -1
            property int rounding: -1
            property int animations: -1
            property int blur: -1
            property int shadow: -1
            property int vfr: -1
        }
    }
}
