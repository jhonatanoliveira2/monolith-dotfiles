import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../services"
import "../components"

// Small bottom-center display for the volume / brightness / media keys. Only exists while visible.
Scope {
    id: scope
    property var screen: null
    readonly property bool mine: Hyprland.focusedMonitor === null || screen === null || Hyprland.focusedMonitor.name === screen.name

    LazyLoader {
        active: scope.mine && (Osd.visible || closing.running)
        PanelWindow {
            screen: scope.screen
            anchors.bottom: true
            margins.bottom: 70
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 300
            implicitHeight: 54
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-osd"
            mask: Region {}                      // never steals the pointer

            Rectangle {
                id: box
                anchors.fill: parent
                radius: Theme.menuRadius
                color: Theme.panelBg
                border.width: 1
                border.color: Theme.line
                opacity: Osd.visible ? 1 : 0
                scale: Osd.visible ? 1 : 0.94
                Behavior on opacity { NumberAnimation { duration: Theme.dur(160) } }
                Behavior on scale { NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutCubic } }

                readonly property real value: Osd.kind === "volume" ? (Audio.muted ? 0 : Audio.volume)
                    : Osd.kind === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume)
                    : Osd.kind === "brightness" ? Brightness.fraction : Media.progress
                readonly property string icon: Osd.kind === "volume" ? Audio.glyph()
                    : Osd.kind === "mic" ? (Audio.micMuted ? Theme.glyph.micOff : Theme.glyph.mic)
                    : Osd.kind === "brightness" ? Theme.glyph.backlight
                    : (Media.playing ? Theme.glyph.play : Theme.glyph.pause)

                CoverArt {
                    id: art
                    visible: Osd.kind === "media"
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 34; height: 34; size: 68
                    source: Media.art
                }
                Txt {
                    id: ic
                    anchors { left: art.visible ? art.right : parent.left; leftMargin: art.visible ? 10 : 16; verticalCenter: parent.verticalCenter }
                    width: 20
                    text: box.icon; font.pixelSize: 17; color: Theme.white
                }
                Column {
                    anchors { left: ic.right; leftMargin: 10; right: pct.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Txt { visible: Osd.kind === "media"; width: parent.width; text: Media.title + (Media.artist ? "  ·  " + Media.artist : ""); color: Theme.foreground; font.pixelSize: Theme.small }
                    Rectangle {
                        width: parent.width; height: 4; radius: 2; color: Theme.grayDark
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, box.value)); height: parent.height; radius: 2
                            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.grayMid } GradientStop { position: 1; color: Theme.white } }
                            Behavior on width { NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutCubic } }
                        }
                    }
                }
                Txt {
                    id: pct
                    visible: Osd.kind !== "media"
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    width: visible ? 40 : 0
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(box.value * 100) + "%"
                    color: Theme.grayLight
                }
            }
        }
    }
    // keeps the window alive for the fade-out
    Timer { id: closing; interval: Theme.dur(200) + 20 }
    Connections {
        target: Osd
        function onVisibleChanged() { if (!Osd.visible) closing.restart() }
    }
}
