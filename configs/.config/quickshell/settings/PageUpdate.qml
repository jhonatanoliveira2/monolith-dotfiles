import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../components"

// Checks the local clone against its real remote / branch (scripts/update-check.sh), shows every failure as is,
// then `git pull --ff-only` + the installer (configs only, no packages).
Column {
    id: root
    spacing: 8
    readonly property string path: Registry.repoPath
    property string upState: "idle"      // idle | checking | updating | done | failed
    property var info: ({})
    property string log: ""
    readonly property int behind: info.behind !== undefined ? Number(info.behind) : -1

    function check() {
        upState = "checking"; info = ({})
        checkProc.command = ["bash", Quickshell.shellPath("scripts/update-check.sh"), path, Registry.repoUrl]
        checkProc.running = true
    }
    function update() {
        upState = "updating"; log = ""
        const b = info.branch && info.branch !== "(detached)" ? info.branch : "main"
        updProc.command = ["sh", "-c", "set -e; export GIT_TERMINAL_PROMPT=0; if [ -d \"$1/.git\" ]; then git -C \"$1\" pull --ff-only origin \"$3\"; else git clone --branch \"$3\" \"$2\" \"$1\"; fi; " +
                           "cd \"$1\" && bash scripts/install.sh --yes --no-deps --no-color --no-clear", "sh", path, info.url || Registry.repoUrl, b]
        updProc.running = true
    }
    Component.onCompleted: check()

    Process {
        id: checkProc
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}
                for (const line of text.split("\n")) { const i = line.indexOf("="); if (i > 0) o[line.slice(0, i)] = line.slice(i + 1) }
                root.info = o
                root.upState = o.error || (o.clone === "0" && o.api !== "200") ? "failed" : "idle"
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.log = text.trim().split("\n").slice(-4).join("\n") }
    }
    Process {
        id: updProc
        stdout: SplitParser { onRead: l => root.log = (root.log + "\n" + l).split("\n").slice(-12).join("\n") }
        stderr: SplitParser { onRead: l => root.log = (root.log + "\n" + l).split("\n").slice(-12).join("\n") }
        onExited: code => { root.upState = code === 0 ? "done" : "failed"; if (code === 0) root.check() }
    }

    function statusText() {
        if (upState === "checking") return Labels.t("checking")
        if (upState === "updating") return Labels.t("updating")
        if (info.error) return Labels.t("failed") + ": " + info.error
        if (info.clone === "0") return Labels.t("notCloned") + (info.apihead ? "  ·  " + Labels.t("upLatest") + " " + info.apihead : "")
        if (upState === "done") return Labels.t("done")
        if (behind > 0) return behind + " " + Labels.t("behind")
        if (behind === 0) return Labels.t("upToDate") + (Number(info.ahead) > 0 ? "  ·  " + info.ahead + " " + Labels.t("upAhead") : "")
        return upState === "failed" ? Labels.t("failed") : ""
    }

    Rectangle {
        width: parent.width; height: col.implicitHeight + 24; color: "transparent"; border.width: 1; border.color: Theme.line; radius: Theme.radius
        Column {
            id: col
            x: 14; y: 12; width: parent.width - 28; spacing: 4
            Txt { width: parent.width; color: Theme.white; wrapMode: Text.Wrap; elide: Text.ElideNone; text: root.statusText() }
            Txt { width: parent.width; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
                  text: Labels.t("repo") + "  " + String(root.info.url || Registry.repoUrl).replace("https://", "") + "   ·   " + Labels.t("upBranch") + "  " + (root.info.branch || "?")
                        + (root.info.upstream ? "  →  " + root.info.upstream : "") }
            Txt { visible: !!root.info.local; width: parent.width; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
                  text: Labels.t("upLocal") + "  " + root.info.local + (root.info.remote ? "   ·   " + Labels.t("upRemote") + "  " + root.info.remote : "")
                        + (Number(root.info.dirty) > 0 ? "   ·   " + root.info.dirty + " " + Labels.t("upDirty") : "") }
            Txt { visible: !!root.info.api; width: parent.width; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false; wrapMode: Text.Wrap; elide: Text.ElideNone
                  text: "GitHub API  " + root.info.api + (root.info.apierror ? " (" + root.info.apierror + ")" : "")
                        + (root.info.ratelimit ? "   ·   " + Labels.t("upRate") + " " + root.info.ratelimit
                           + (root.info.ratereset ? " (" + Labels.t("upReset") + " " + Qt.formatTime(new Date(Number(root.info.ratereset) * 1000), "HH:mm") + ")" : "") : "")
                        + (root.info.api === "000" ? "   ·   " + Labels.t("upOffline") : "") }
            Row {
                spacing: 6; topPadding: 4
                Btn { compact: true; icon: Theme.glyph.refresh; text: Labels.t("check"); onActivated: root.check() }
                Btn {
                    compact: true; active: root.behind > 0 || root.info.clone === "0"; confirm: Number(root.info.dirty) > 0
                    text: root.info.clone === "0" ? Labels.t("clone") : Labels.t("updateNow")
                    onActivated: root.update()
                }
            }
        }
    }

    Rectangle {
        width: parent.width; height: 32; color: "transparent"; border.width: 1; border.color: Theme.line; radius: Theme.radius
        Txt { id: pl; x: 12; width: 110; height: parent.height; text: Labels.t("path"); color: Theme.grayMid }
        TextInput {
            anchors { left: pl.right; right: parent.right; rightMargin: 12; top: parent.top; bottom: parent.bottom }
            verticalAlignment: TextInput.AlignVCenter; clip: true; selectByMouse: true
            color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
            text: root.path
            onAccepted: { Settings.repoPath = text.trim(); focus = false; root.check() }
        }
    }
    Txt { visible: root.log !== ""; width: parent.width; wrapMode: Text.Wrap; elide: Text.ElideNone; font.pixelSize: Theme.small; color: Theme.grayMid; text: root.log.trim() }
    EntryList { page: "update"; width: parent.width }
}
