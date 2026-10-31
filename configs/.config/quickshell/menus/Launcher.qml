import QtQuick
import Quickshell
import Quickshell.Widgets
import "../core"
import "../services"
import "../components"

// App launcher (Super+A, replaces rofi drun; rofi stays the fallback without the shell). Desktop entries from Quickshell's DesktopEntries,
// ranked by match quality (exact, prefix, word start, substring, keywords / description, fuzzy) and, optionally,
// by how often each app was launched (Settings.launcherUsage). Also: "2+2" shows the result (Enter copies it),
// "> cmd" runs a command. Terminal=true apps open in Settings.launcherTerminal. Options: Settings > Launcher.
// Every match is listed; Settings.launcherMax rows are visible and the list scrolls in a loop (arrows, Tab,
// Page Up / Down and the mouse wheel wrap around), with a sliding highlight and items easing in.
Overlay {
    id: win
    name: "launcher"
    cardWidth: 640
    readonly property int rowH: Settings.launcherComments ? 52 : 40
    readonly property int rows: Math.min(Math.max(1, list.count), Math.max(1, Settings.launcherMax))
    cardHeight: 76 + rows * rowH + 10
    property string query: ""
    property int sel: 0
    Component.onCompleted: input.forceActiveFocus()

    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)
    function uses(a) { return (Settings.launcherUsage || {})[a.id] || 0 }
    // 0 = no match
    function score(a, q) {
        const n = String(a.name || "").toLowerCase()
        if (n === q) return 1000
        if (n.startsWith(q)) return 800
        if ((" " + n).indexOf(" " + q) >= 0) return 650
        if (n.indexOf(q) >= 0) return 500
        const extra = [a.genericName, a.comment, (a.keywords || []).join(" "), a.id].join(" ").toLowerCase()
        if (extra.indexOf(q) >= 0) return 300
        // fuzzy: every typed character in order; tighter matches score higher
        let i = 0, gaps = 0, last = -1
        for (const c of q) {
            const j = n.indexOf(c, last + 1)
            if (j < 0) return 0
            if (last >= 0) gaps += j - last - 1
            last = j; i++
        }
        return Math.max(1, 200 - gaps * 5)
    }
    readonly property var calc: {
        const q = query.trim()
        if (!Settings.launcherCalc || !/^[\d\s+\-*/().,%^]+$/.test(q) || !/\d/.test(q) || !/[+\-*/%^]/.test(q)) return null
        try {
            const v = Function("\"use strict\"; return (" + q.replace(/\^/g, "**").replace(/,/g, ".") + ")")()
            return typeof v === "number" && isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : null
        } catch (e) { return null }
    }
    readonly property string command: Settings.launcherCommands && query.startsWith(">") ? query.slice(1).trim() : ""
    readonly property var results: {
        const q = query.trim().toLowerCase()
        const extra = calc !== null ? [{ kind: "calc", text: calc }] : command ? [{ kind: "cmd", text: command }] : []
        if (command) return extra
        const ranked = apps.map(a => ({ a: a, s: q ? score(a, q) : 1 })).filter(x => x.s > 0)
        ranked.sort((x, y) => (y.s - x.s) || (Settings.launcherSort === "usage" ? uses(y.a) - uses(x.a) : 0)
                              || String(x.a.name).localeCompare(String(y.a.name)))
        return extra.concat(ranked.map(x => ({ kind: "app", app: x.a })))
    }
    onResultsChanged: { sel = 0; fresh = true; freshOff.restart() }
    // rows created right after the results change ease in; rows scrolled into view later just appear
    property bool fresh: true
    Timer { id: freshOff; interval: 450; running: true; onTriggered: win.fresh = false }
    // move the selection by n rows, wrapping around both ends
    function step(n) { if (list.count) sel = ((sel + n) % list.count + list.count) % list.count }

    function run(r) {
        if (!r) return
        if (r.kind === "calc") Quickshell.execDetached(["wl-copy", r.text])
        else if (r.kind === "cmd") Quickshell.execDetached(["sh", "-c", r.text])
        else {
            const a = r.app, u = Object.assign({}, Settings.launcherUsage || {})
            u[a.id] = (u[a.id] || 0) + 1
            Settings.launcherUsage = u
            if (a.runInTerminal) Quickshell.execDetached([Settings.launcherTerminal || "ghostty", "-e"].concat(Array.from(a.command)))
            else a.execute()
        }
        Popups.closeOverlay()
    }

    Rectangle {
        id: box
        x: 14; y: 14; width: parent.width - 28; height: 44
        color: "transparent"; border.width: 1; border.color: input.activeFocus ? Theme.white : Theme.line; radius: 6
        Txt { id: mag; x: 14; height: parent.height; text: String.fromCodePoint(0xf002); color: Theme.grayMid; font.pixelSize: 15 }
        TextInput {
            id: input
            anchors { left: mag.right; leftMargin: 12; right: parent.right; rightMargin: 12; top: parent.top; bottom: parent.bottom }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3
            clip: true
            onTextChanged: win.query = text
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) { win.step(1); e.accepted = true }
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { win.step(-1); e.accepted = true }
                else if (e.key === Qt.Key_PageDown) { win.step(win.rows); e.accepted = true }
                else if (e.key === Qt.Key_PageUp) { win.step(-win.rows); e.accepted = true }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.run(win.results[win.sel]); e.accepted = true }
            }
            Txt { visible: input.text === ""; anchors.fill: parent; text: Strings.t("lnSearch"); color: Theme.grayMid; font.bold: false; font.pixelSize: Theme.fontSize + 1 }
        }
    }

    ListView {
        id: list
        anchors { top: box.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14; topMargin: 10 }
        clip: true
        model: win.results
        currentIndex: win.sel
        boundsBehavior: Flickable.StopAtBounds
        // the highlight slides between rows and the view scrolls smoothly to keep it visible
        highlight: Rectangle { radius: 6; color: Theme.selected }
        highlightMoveDuration: Theme.dur(140)
        highlightMoveVelocity: -1
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        // the wheel walks the list in a loop (endless scrolling) instead of stopping at the ends
        WheelHandler {
            property real acc: 0
            onWheel: e => {
                acc += e.angleDelta.y
                while (Math.abs(acc) >= 120) { win.step(acc > 0 ? -1 : 1); acc -= acc > 0 ? 120 : -120 }
            }
        }
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool current: index === win.sel
            width: list.width; height: win.rowH; radius: 6
            color: ma.containsMouse && !current ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.dur(100) } }
            // rows ease in, a little after one another
            opacity: win.fresh ? 0 : 1
            transform: Translate { id: shift; x: win.fresh ? 14 : 0 }
            Component.onCompleted: if (win.fresh) enter.start()     // started once: never cut short halfway
            SequentialAnimation {
                id: enter
                PauseAnimation { duration: Theme.dur(Math.min(row.index, 10) * 18) }
                ParallelAnimation {
                    NumberAnimation { target: row; property: "opacity"; to: 1; duration: Theme.dur(180); easing.type: Easing.OutCubic }
                    NumberAnimation { target: shift; property: "x"; to: 0; duration: Theme.dur(220); easing.type: Easing.OutCubic }
                }
            }
            Item {
                id: ic
                x: 10; width: 30; height: parent.height
                IconImage {
                    id: appIcon
                    visible: row.modelData.kind === "app" && Settings.launcherIcons && source != ""
                    anchors.centerIn: parent; implicitSize: 28
                    // iconPath(name, true) is "" when the theme lacks the icon: fall back to a generic one
                    source: row.modelData.kind !== "app" ? "" : Quickshell.iconPath(row.modelData.app.icon, true) || Quickshell.iconPath("application-x-executable", true)
                }
                Txt {
                    visible: !appIcon.visible
                    anchors.centerIn: parent
                    text: String.fromCodePoint(row.modelData.kind === "calc" ? 0xf1ec : row.modelData.kind === "cmd" ? 0xf120 : 0xf135)
                    color: Theme.grayLight; font.pixelSize: 16
                }
            }
            Column {
                anchors { left: ic.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 2
                Txt {
                    width: parent.width
                    text: row.modelData.kind === "calc" ? "= " + row.modelData.text : row.modelData.kind === "cmd" ? Strings.t("lnRun") + ": " + row.modelData.text : row.modelData.app.name
                    color: row.current ? Theme.white : Theme.foreground; font.pixelSize: Theme.fontSize + 1
                }
                Txt {
                    visible: Settings.launcherComments && text !== ""
                    width: parent.width
                    text: row.modelData.kind === "calc" ? Strings.t("lnCopy") : row.modelData.kind === "app" ? String(row.modelData.app.comment || row.modelData.app.genericName || "") : ""
                    color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
                }
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onEntered: win.sel = row.index; onClicked: win.run(row.modelData) }
        }
        Txt { visible: list.count === 0; anchors.centerIn: parent; text: Strings.t("lnNone"); color: Theme.grayMid }
    }
    HoverScrollBar { flick: list; anchors.rightMargin: -10 }
}
