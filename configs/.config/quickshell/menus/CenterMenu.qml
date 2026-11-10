import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../services"
import "../components"
import "../settings"
import "center"

// Center menu: opens while the pointer rests on the middle of the bar (Bar.qml, Settings > Bar > center menu)
// and closes when it leaves both. A shell command line on top, then tabs: Dashboard, Performance, Weather and
// Player (menus/center/). Created only while open (MenuSlot), and only the open tab exists: each tab asks the
// services it needs (Stats, Perf, Media, Lyrics, Weather) to run while it is shown, so nothing else polls.
MenuWindow {
    id: win
    menu: "center"
    panelWidth: 760
    maxHeight: 900
    // side bar: opens at the top centre (a drawer of the frame in frame style), when the pointer rests on the
    // middle of the top edge (components/CenterHotZone.qml) or by a click on the clock
    topCenter: Settings.barVertical
    hoverKeep: true
    hoverScroll: true

    Column {
        id: col
        width: parent.width
        spacing: 8

        // ── command line: Enter runs it here (output below), Shift+Enter in the terminal, Up / Down = history ──
        property string out: ""
        property int hIdx: -1
        function push(line) {
            const t = out + line + "\n"
            out = t.length > 12000 ? t.slice(t.length - 12000) : t
        }
        // saved in settings.json, or kept in memory for this session only (Settings > Bar > Center menu)
        readonly property var history: Settings.centerHistoryKeep ? (Settings.centerHistory || []) : Settings.centerSession
        function remember(cmd) {
            const h = Array.from(history).filter(x => x !== cmd)
            h.push(cmd)
            if (Settings.centerHistoryKeep) Settings.centerHistory = h.slice(-50)
            else Settings.centerSession = h.slice(-50)
            hIdx = -1
        }
        function run(cmd, inTerminal) {
            cmd = cmd.trim()
            if (!cmd) return
            remember(cmd)
            input.text = ""
            if (inTerminal) {
                Popups.close()
                Quickshell.execDetached([Settings.launcherTerminal || "ghostty", "-e", "sh", "-c", cmd + "; printf '\\n[enter] '; read _"])
                return
            }
            if (proc.running) proc.running = false
            out = ""
            push("$ " + cmd)
            proc.code = -1
            proc.command = ["sh", "-c", "exec 2>&1; " + cmd]
            proc.running = true
        }
        Process {
            id: proc
            property int code: -1
            stdout: SplitParser { onRead: d => col.push(d) }
            onExited: c => proc.code = c
        }

        Card {
            width: parent.width; height: 40
            border.color: input.activeFocus ? Theme.accent : Theme.line
            Behavior on border.color { ColorAnimation { duration: Theme.dur(120) } }
            Txt {
                id: prompt
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: Theme.g(0xf120); color: input.activeFocus ? Theme.accent : Theme.grayMid
            }
            TextInput {
                id: input
                anchors { left: prompt.right; leftMargin: 10; right: tools.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                color: Theme.white
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccent
                font.family: Theme.font; font.pixelSize: Theme.fontSize
                clip: true
                // typing pins the menu: it no longer closes when the pointer leaves, only on Esc / outside click
                onActiveFocusChanged: if (activeFocus) Popups.pinned = true
                Keys.onReturnPressed: e => col.run(text, e.modifiers & Qt.ShiftModifier)
                Keys.onEnterPressed: e => col.run(text, e.modifiers & Qt.ShiftModifier)
                Keys.onUpPressed: {
                    const h = col.history
                    if (!h.length) return
                    col.hIdx = col.hIdx < 0 ? h.length - 1 : Math.max(0, col.hIdx - 1)
                    text = h[col.hIdx]
                }
                Keys.onDownPressed: {
                    const h = col.history
                    if (col.hIdx < 0) return
                    col.hIdx = col.hIdx + 1 < h.length ? col.hIdx + 1 : -1
                    text = col.hIdx < 0 ? "" : h[col.hIdx]
                }
                Txt {
                    visible: !input.text && !input.activeFocus
                    anchors.verticalCenter: parent.verticalCenter
                    text: Labels.pick(["Executar comando…   Enter: aqui  ·  Shift+Enter: terminal", "Run a command…   Enter: here  ·  Shift+Enter: terminal"])
                    color: Theme.grayMid; font.bold: false
                }
            }
            Row {
                id: tools
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                spacing: 4
                Btn { compact: true; visible: proc.running; icon: Theme.g(0xf04d); text: Labels.pick(["Parar", "Stop"]); onActivated: proc.running = false }
                Btn { compact: true; visible: input.text !== ""; icon: Theme.g(0xf04b); onActivated: col.run(input.text, false) }
                Btn { compact: true; visible: input.text !== ""; icon: Theme.g(0xf120); onActivated: col.run(input.text, true) }
            }
        }

        // output of the last command
        Card {
            visible: col.out !== ""
            width: parent.width; height: Math.min(outText.implicitHeight + 40, 220)
            Flickable {
                id: outFlick
                anchors { fill: parent; margins: 10; bottomMargin: 30 }
                contentWidth: width; contentHeight: outText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                // follow the output while it streams in
                onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                TextEdit {
                    id: outText
                    width: parent.width
                    readOnly: true; selectByMouse: true
                    wrapMode: TextEdit.WrapAnywhere
                    textFormat: TextEdit.PlainText
                    text: col.out.replace(/\n$/, "")
                    color: Theme.foreground; selectionColor: Theme.accent; selectedTextColor: Theme.onAccent
                    font.family: Theme.font; font.pixelSize: Theme.small
                }
            }
            HoverScrollBar { flick: outFlick }
            Txt {
                anchors { left: parent.left; leftMargin: 10; bottom: parent.bottom; bottomMargin: 7 }
                text: proc.running ? Labels.pick(["Executando…", "Running…"]) : proc.code === 0 ? Theme.glyph.check + "  " + Labels.pick(["Concluído", "Done"])
                      : Theme.glyph.close + "  " + Labels.pick(["Código ", "Exit code "]) + proc.code
                color: proc.running || proc.code === 0 ? Theme.grayMid : Theme.white
                font.pixelSize: Theme.small; font.bold: false
            }
            Row {
                anchors { right: parent.right; rightMargin: 6; bottom: parent.bottom; bottomMargin: 3 }
                spacing: 4
                Btn { compact: true; icon: Theme.g(0xf0c5); onActivated: Quickshell.execDetached(["wl-copy", col.out]) }
                Btn { compact: true; icon: Theme.g(0xf1f8); onActivated: { if (proc.running) proc.running = false; col.out = "" } }
            }
        }

        // ── tabs ──
        readonly property var tabs: [
            { icon: Theme.g(0xf0e4), label: "Dashboard" },
            { icon: Theme.g(0xf080), label: "Performance" },
            { icon: Theme.g(0xf0595), label: Labels.pick(["Clima", "Weather"]) },
            { icon: Theme.glyph.note, label: "Player" }
        ]
        readonly property int tab: Math.max(0, Math.min(tabs.length - 1, Settings.centerTab))
        Item {
            width: parent.width; height: 34
            Row {
                id: tabRow
                anchors.fill: parent
                Repeater {
                    model: col.tabs
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: tabRow.width / col.tabs.length; height: tabRow.height
                        readonly property bool current: col.tab === index
                        Rectangle { anchors { fill: parent; margins: 2 } radius: Theme.radius; color: tabHov.hovered && !parent.current ? Theme.hover : "transparent" }
                        Led {             // Nothing theme: the open tab has a lit LED before its name
                            visible: Theme.nothing
                            anchors { right: tabLabel.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            width: 5; height: 5; lit: parent.current
                        }
                        Txt {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: Theme.nothing ? modelData.label.toUpperCase() : modelData.icon + "  " + modelData.label
                            font.letterSpacing: Theme.nothing ? 1.5 : 0
                            color: parent.current ? Theme.white : Theme.grayMid
                            Behavior on color { ColorAnimation { duration: Theme.dur(150) } }
                        }
                        HoverHandler { id: tabHov }
                        TapHandler { onTapped: Settings.centerTab = index }
                    }
                }
            }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.line }
            // the underline slides to the open tab
            Rectangle {
                visible: !Theme.nothing
                anchors.bottom: parent.bottom
                height: 2; radius: 1; color: Theme.accent
                width: tabRow.width / col.tabs.length * 0.5
                x: tabRow.width / col.tabs.length * (col.tab + 0.25)
                Behavior on x { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
            }
        }
        // only the open tab exists; it is rebuilt on every switch, so its cards play their entry animation again
        Loader {
            width: parent.width
            sourceComponent: [dashboard, performance, weather, player][col.tab]
        }
        Component { id: dashboard; Dashboard {} }
        Component { id: performance; Performance {} }
        Component { id: weather; WeatherTab {} }
        Component { id: player; PlayerTab {} }
    }
}
