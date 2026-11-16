import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

// Session menu: lock, suspend, reboot and power off, as icons only, with the distro logo (Arch, NixOS...,
// services/Distro via Theme.glyph.distro) spinning in the middle. Opens while the pointer rests on the middle of
// the screen's right edge (components/CenterHotZone.qml, Settings > Bar > session menu) and closes when it
// leaves both; in frame style it is a drawer of the frame (or of the bar, on a right bar), like the center menu at
// the top. `qs ipc call shell toggle session` opens it pinned. Reboot and power off ask for a second click (the
// icon turns into "?" for 2.5 s).
MenuWindow {
    id: win
    menu: "session"
    panelWidth: 88
    rightCenter: true
    hoverKeep: true

    // the same actions as the quick menu's session section (services/QuickMenu.qml)
    function action(id) { return QuickMenu.sessionCatalog.find(s => s.id === id) }

    component IconBtn: Rectangle {
        id: b
        property var act: null
        property bool armed: false
        width: 60; height: 60
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Theme.nothing ? width / 2 : Theme.radius
        color: ma.pressed ? Theme.pressed : armed ? Theme.selected : ma.containsMouse ? Theme.hover : "transparent"
        border.width: 1
        border.color: armed ? Theme.accent : ma.containsMouse ? Theme.grayLight : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.dur(100) } }
        Behavior on border.color { ColorAnimation { duration: Theme.dur(100) } }
        Text {
            anchors.centerIn: parent
            text: b.armed ? "?" : b.act ? b.act.icon : ""
            color: b.armed || ma.containsMouse ? Theme.white : Theme.grayLight
            font.family: Theme.font
            font.pixelSize: 25
            font.bold: true
        }
        Timer { id: disarm; interval: 2500; onTriggered: b.armed = false }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!b.act) return
                if (b.act.confirm && !b.armed) { b.armed = true; disarm.restart(); return }
                b.armed = false
                b.act.run()
            }
        }
    }

    Column {
        width: parent.width
        topPadding: 4; bottomPadding: 4
        spacing: 10

        IconBtn { act: win.action("lock") }
        IconBtn { act: win.action("suspend") }
        // the distro logo, one turn every 6 s while the menu is open (still when animations are off; the
        // speed does not follow the animation scale). It turns in place, like a gear: on its own centre of mass,
        // not on the centre of the text box (a font glyph has room above, below and at the sides, so it used to
        // orbit ~4 px around the axis)
        Item {
            width: 60; height: 70
            anchors.horizontalCenter: parent.horizontalCenter
            Item {
                id: spinner
                anchors.centerIn: parent
                width: 42; height: 42
                // centre of mass minus the centre of the ink box, as a fraction of the font size (measured from
                // the Nerd Font glyphs of core/Distro.qml; the NixOS snowflake is symmetric)
                readonly property var mass: ({ [0xf08c7]: [-0.005, 0.0655], [0xf385]: [-0.0925, 0.0145], [0xf31a]: [0.0396, -0.0326] })
                readonly property var off: mass[Distro.glyph] || [0, 0]
                TextMetrics { id: ink; font: logo.font; text: logo.text }
                Text {
                    id: logo
                    text: Theme.glyph.distro
                    color: Theme.white
                    font.family: Theme.font
                    font.pixelSize: 32
                    // the ink's centre of mass on the spinner's centre, which the rotation turns around
                    x: spinner.width / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2 + spinner.off[0] * font.pixelSize)
                    y: spinner.height / 2 - (baselineOffset + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2 + spinner.off[1] * font.pixelSize)
                }
                RotationAnimator on rotation {
                    from: 0; to: 360
                    duration: 6000
                    loops: Animation.Infinite
                    running: win.shown && Config.animations
                }
            }
        }
        IconBtn { act: win.action("reboot") }
        IconBtn { act: win.action("poweroff") }
    }
}
