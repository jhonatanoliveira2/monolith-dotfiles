import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../components"

// Computer overview (detected each time the page opens) + general switches and session actions.
Column {
    id: root
    spacing: 8
    property var info: ({})
    readonly property var keys: ["host", "user", "os", "kernel", "desktop", "cpu", "gpu", "mem", "disk", "up", "monolith"]

    Process {
        running: true
        command: ["bash", Quickshell.shellPath("scripts/sysinfo.sh"), Registry.repoPath, Config.language]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i > 0) o[line.slice(0, i)] = line.slice(i + 1)
                }
                root.info = o
            }
        }
    }

    Rectangle {
        width: parent.width; height: grid.implicitHeight + 20
        color: "transparent"; border.width: 1; border.color: Theme.line; radius: Theme.radius
        Column {
            id: grid
            x: 14; y: 10; width: parent.width - 28; spacing: 4
            Repeater {
                model: root.keys
                delegate: Item {
                    required property string modelData
                    width: grid.width; height: 20
                    Txt { width: 170; text: Labels.t("si_" + modelData); color: Theme.grayMid }
                    Txt { x: 170; width: parent.width - 170; text: root.info[modelData] || "…"; color: Theme.white }
                }
            }
        }
    }
    EntryList { page: "system"; width: parent.width }
}
