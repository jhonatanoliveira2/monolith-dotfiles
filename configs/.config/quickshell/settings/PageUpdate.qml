import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../components"

// Checks the local clone against its real remote / branch (scripts/update-check.sh), shows every failure as is,
// then `git pull --ff-only` + the installer (configs only, no packages). Installed by Nix (Distro.nixManaged), there
// is no clone: the pinned flake revision is compared with the branch on GitHub and "Update now" runs the
// Home Manager option programs.monolith.updateCommand in a terminal (flake update + rebuild).
Column {
    id: root
    spacing: 8
    readonly property string path: Registry.repoPath
    property string upState: "idle"      // idle | checking | updating | done | failed
    property var info: ({})
    property string log: ""
    property var changes: []             // new commits the update brings ("hash date subject"), listed before it runs
    readonly property int behind: info.behind !== undefined ? Number(info.behind) : -1
    readonly property bool nix: Distro.nixManaged
    readonly property string nixRev: String(Distro.nix.shortRev || "").slice(0, 7)
    readonly property string nixCmd: String(Distro.nix.updateCommand || "")
    readonly property bool nixNewer: nix && !!info.apihead && info.apihead !== nixRev

    function check() {
        upState = "checking"; info = ({}); changes = []
        checkProc.command = nix ? ["bash", Quickshell.shellPath("scripts/update-check.sh"), "", Distro.nix.repo || Registry.repoUrl, Distro.nix.branch || "main"]
                                : ["bash", Quickshell.shellPath("scripts/update-check.sh"), path, Registry.repoUrl]
        checkProc.running = true
    }
    function update() {
        if (nix) {
            if (nixCmd) Quickshell.execDetached([Settings.launcherTerminal, "-e", "sh", "-c", nixCmd + "; echo; read -p 'Enter...' x"])
            return
        }
        upState = "updating"; log = ""
        const b = info.branch && info.branch !== "(detached)" ? info.branch : "main"
        // An existing clone moves to exactly the revision the check listed (`target`, already fetched): what runs
        // is what was shown, even if the remote changed in between. Only without it (older check output) it pulls.
        updProc.command = ["sh", "-c", "set -e; export GIT_TERMINAL_PROMPT=0; if [ -d \"$1/.git\" ]; then " +
                           "if [ -n \"$4\" ]; then git -C \"$1\" merge --ff-only \"$4\"; else git -C \"$1\" pull --ff-only origin \"$3\"; fi; " +
                           "else git clone --branch \"$3\" \"$2\" \"$1\"; fi; " +
                           "cd \"$1\" && bash scripts/install.sh --yes --no-deps --no-color --no-clear", "sh", path, info.url || Registry.repoUrl, b, info.target || ""]
        updProc.running = true
    }
    Component.onCompleted: check()

    Process {
        id: checkProc
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {}, ch = []
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i <= 0) continue
                    if (line.slice(0, i) === "change") ch.push(line.slice(i + 1)); else o[line.slice(0, i)] = line.slice(i + 1)
                }
                root.changes = ch
                root.info = o
                root.upState = o.error || (o.clone === "0" && o.api !== "200" && !root.nix) ? "failed" : "idle"
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
        if (nix) return Labels.t("upNix") + "  ·  " + Labels.t("upNixRev") + " " + (nixRev || "?")
                        + (Distro.nix.lastModified ? " (" + Distro.nix.lastModified + ")" : "")
                        + (nixNewer ? "  ·  " + Labels.t("upNixNew") + " " + info.apihead : info.apihead ? "  ·  " + Labels.t("upToDate") : "")
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
                    visible: !root.nix || root.nixCmd !== ""
                    compact: true; active: root.nix ? root.nixNewer : root.behind > 0 || root.info.clone === "0"; confirm: !root.nix && root.info.clone !== "0"      // code from the remote is about to run: always a second click
                    text: root.info.clone === "0" && !root.nix ? Labels.t("clone") : Labels.t("updateNow")
                    onActivated: root.update()
                }
            }
        }
    }

    // what the update brings, to be read before the second click
    Column {
        visible: !root.nix && root.changes.length > 0 && root.upState !== "updating"
        width: parent.width; spacing: 2
        Txt { text: Labels.t("upIncoming"); color: Theme.grayMid; font.pixelSize: Theme.small }
        Txt { visible: Number(root.info.installer) > 0; width: parent.width; wrapMode: Text.Wrap; elide: Text.ElideNone; font.pixelSize: Theme.small; color: Theme.accent
              text: Labels.t("upInstaller") + " (" + root.info.installer + ")" }
        Repeater {
            model: root.changes
            delegate: Txt { required property string modelData; width: parent.width; elide: Text.ElideRight; font.pixelSize: Theme.small; font.bold: false; color: Theme.foreground; text: modelData }
        }
        Txt { visible: Number(root.info.more) > 0; text: "+ " + root.info.more + " " + Labels.t("behind"); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
    }

    Txt {
        visible: root.nix; width: parent.width; wrapMode: Text.Wrap; elide: Text.ElideNone; font.pixelSize: Theme.small; font.bold: false; color: Theme.grayMid
        text: Labels.t("upNixHint") + (root.nixCmd ? "\n" + root.nixCmd
              : "\n" + Labels.t("upNixNoCmd") + "\n  nix flake update monolith --flake <flake>\n  sudo nixos-rebuild switch --flake <flake>")
    }
    Rectangle {
        visible: !root.nix
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
