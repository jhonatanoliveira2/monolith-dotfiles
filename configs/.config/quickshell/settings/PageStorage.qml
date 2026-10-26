import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../components"

// Disks and partitions (lsblk, in bytes: total / used / free per file system), device health from UDisks2,
// and cleanup of caches. Cleanup always scans first, shows what will be removed and needs a confirming second click.
Column {
    id: root
    spacing: 8
    property var disks: []            // lsblk "blockdevices" (disks with their partitions)
    property var health: ({})
    property var targets: []          // cleanup scan: [{id, bytes, count, what}]
    property var infoDirs: []
    property bool scanning: false
    property string running: ""       // cleanup target being removed
    property string log: ""

    function load() { diskProc.running = true }
    function scan() { scanning = true; scanProc.running = true }
    Component.onCompleted: { load(); scan() }

    function human(b) {
        b = Number(b) || 0
        const u = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++ }
        return (i >= 3 ? b.toFixed(1) : Math.round(b)) + " " + u[i]
    }
    function kind(d) {
        if (d.tran === "usb" || d.rm || d.hotplug) return "usb"
        if (d.tran === "nvme" || String(d.name).indexOf("nvme") === 0) return "nvme"
        return d.rota ? "hdd" : "ssd"
    }
    function glyph(k) { return k === "usb" ? Theme.g(0xf287) : Theme.g(0xf0a0) }
    function healthText(h) {
        if (!h) return ""
        const out = []
        if (h.bus === "nvme") {
            const bad = (h.warn || []).length > 0 || (h.errors || 0) > 0 || (h.spare !== undefined && h.spare < 10)
            out.push(bad ? Labels.t("stWarn") : Labels.t("stOk"))
            if (h.used !== undefined) out.push(Labels.t("stWear") + " " + h.used + "%")
            if (h.spare !== undefined) out.push(Labels.t("stSpare") + " " + h.spare + "%")
            if (h.errors) out.push(h.errors + " " + Labels.t("stErrors"))
            if ((h.warn || []).length) out.push(h.warn.join(", "))
        } else if (h.bus === "ata") {
            if (h.enabled === false) out.push(Labels.t("stNoSmart"))
            else out.push(h.failing ? Labels.t("stFailing") : Labels.t("stOk"))
            if (h.badSectors) out.push(h.badSectors + " " + Labels.t("stBad"))
        }
        if (h.temp > 0) out.push(h.temp + "°C")
        if (h.hours > 0) out.push(h.hours + " h")
        return out.join("  ·  ")
    }
    // a partition's numbers: fssize/fsused/fsavail are null for unmounted ones
    function usage(p) {
        const size = Number(p.fssize) || 0, used = Number(p.fsused) || 0, free = Number(p.fsavail) || 0
        return { size: size, used: used, free: free, pct: size > 0 ? Math.min(100, Math.round(used * 100 / size)) : -1 }
    }

    Process {
        id: diskProc
        command: ["bash", Quickshell.shellPath("scripts/storage.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n")
                try { root.disks = (JSON.parse(l[0]).blockdevices || []).filter(d => d.type === "disk" && !/^(zram|loop|ram)/.test(d.name)) } catch (e) { root.disks = [] }
                try { root.health = JSON.parse(l[1] || "{}") } catch (e) { root.health = ({}) }
            }
        }
    }
    Process {
        id: scanProc
        command: ["bash", Quickshell.shellPath("scripts/cleanup.sh"), "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = [], info = []
                for (const line of text.split("\n")) {
                    const p = line.split("|")
                    if (p.length < 4) continue
                    const e = { id: p[0], bytes: Number(p[1]), count: Number(p[2]), what: p.slice(3).join("|") }
                    if (e.id === "info") info.push(e); else t.push(e)
                }
                root.targets = t
                root.infoDirs = info
                root.scanning = false
            }
        }
    }
    Process {
        id: runProc
        stdout: SplitParser { onRead: l => root.log = (root.log + "\n" + l).split("\n").slice(-6).join("\n") }
        stderr: SplitParser { onRead: l => root.log = (root.log + "\n" + l).split("\n").slice(-6).join("\n") }
        onExited: code => {
            root.log = (root.log + "\n" + Labels.t(root.running ? "cl_" + root.running : "") + ": " + (code === 0 ? Labels.t("done") : Labels.t("failed") + " (" + code + ")")).trim()
            root.running = ""
            root.scan(); root.load()
        }
    }

    // ── disks ──
    Section { width: parent.width; text: Labels.t("disks") }
    Repeater {
        model: root.disks
        delegate: Column {
            id: disk
            required property var modelData
            readonly property string k: root.kind(modelData)
            readonly property var parts: (modelData.children || []).concat(modelData.mountpoints && modelData.mountpoints[0] ? [modelData] : [])
            width: root.width
            spacing: 2
            Rectangle {
                width: parent.width; height: 44; radius: Theme.radius; color: Theme.hover; border.width: 1; border.color: Theme.line
                Txt { id: dg; x: 12; width: 26; height: parent.height; text: root.glyph(disk.k); font.pixelSize: 18; color: Theme.white }
                Column {
                    anchors { left: dg.right; leftMargin: 6; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    Txt { width: parent.width; color: Theme.white
                          text: (modelData.model || modelData.name) + "  ·  " + root.human(modelData.size) + "  ·  " + Labels.t("st_" + disk.k) + "  ·  " + modelData.path }
                    Txt { width: parent.width; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
                          visible: text !== ""; text: root.healthText(root.health[modelData.path]) }
                }
            }
            Repeater {
                model: disk.parts
                delegate: Item {
                    required property var modelData
                    readonly property var u: root.usage(modelData)
                    readonly property string mnt: (modelData.mountpoints || []).filter(x => x).join(", ")
                    width: disk.width; height: u.pct >= 0 ? 46 : 28
                    Txt { x: 40; width: parent.width - usageTxt.implicitWidth - 70; height: 22; color: Theme.grayLight
                          text: (modelData.label || modelData.name) + (modelData.fstype ? "  ·  " + modelData.fstype : "") + (mnt ? "  ·  " + mnt : "  ·  " + Labels.t("stUnmounted")) }
                    Txt { id: usageTxt; anchors.right: parent.right; anchors.rightMargin: 10; height: 22; color: Theme.grayMid; font.bold: false
                          text: u.pct >= 0 ? Labels.t("stUsed") + " " + root.human(u.used) + "  ·  " + Labels.t("stFree") + " " + root.human(u.free) + "  ·  " + root.human(u.size) + "  ·  " + u.pct + "%"
                                           : root.human(modelData.size) }
                    Rectangle {
                        visible: u.pct >= 0
                        x: 40; y: 28; width: parent.width - 50; height: 4; color: Theme.grayDark
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, u.pct)) / 100; height: 4
                            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.grayMid } GradientStop { position: 1; color: Theme.white } }
                        }
                    }
                    MouseArea { anchors.fill: parent; enabled: mnt !== ""; onDoubleClicked: Quickshell.execDetached(["xdg-open", modelData.mountpoints[0]]) }
                }
            }
        }
    }

    // ── cleanup ──
    Item {
        width: parent.width; height: 30
        Section { anchors.fill: parent; text: Labels.t("cleanup") }
        Btn { anchors { right: parent.right; verticalCenter: parent.verticalCenter } compact: true; icon: Theme.glyph.refresh
              text: root.scanning ? Labels.t("checking") : Labels.t("analyze"); onActivated: { root.scan(); root.load() } }
    }
    Txt { x: 10; width: parent.width - 20; wrapMode: Text.Wrap; elide: Text.ElideNone; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false; text: Labels.t("cleanupHint") }
    Repeater {
        model: root.targets
        delegate: Rectangle {
            required property var modelData
            width: root.width; height: 44; radius: Theme.radius; color: "transparent"; border.width: 1; border.color: Theme.line
            Column {
                anchors { left: parent.left; leftMargin: 12; right: go.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                Txt { width: parent.width; color: Theme.white
                      text: Labels.t("cl_" + modelData.id) + "  ·  " + (modelData.bytes > 0 ? root.human(modelData.bytes) : modelData.count > 0 ? "" : Labels.t("clEmpty"))
                            + (modelData.count > 0 ? "  ·  " + modelData.count + " " + Labels.t("clItems") : "") }
                Txt { width: parent.width; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false; text: Labels.t("clRemoves") + " " + modelData.what }
            }
            Btn {
                id: go
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                compact: true; confirm: true
                enabled: root.running === "" && (modelData.bytes > 0 || modelData.count > 0)
                opacity: enabled ? 1 : 0.4
                text: root.running === modelData.id ? Labels.t("updating") : Labels.t("clean")
                onActivated: {
                    if (!enabled) return
                    root.running = modelData.id; root.log = ""
                    runProc.command = ["bash", Quickshell.shellPath("scripts/cleanup.sh"), "run", modelData.id]
                    runProc.running = true
                }
            }
        }
    }
    Txt { visible: root.log !== ""; x: 10; width: parent.width - 20; wrapMode: Text.Wrap; elide: Text.ElideNone; font.pixelSize: Theme.small; color: Theme.grayLight; text: root.log }
    Section { visible: root.infoDirs.length > 0; width: parent.width; text: Labels.t("clBiggest") }
    Repeater {
        model: root.infoDirs
        delegate: ListRow { required property var modelData; width: root.width; icon: Theme.g(0xf07b); title: modelData.what; trailing: root.human(modelData.bytes)
                            onClicked: Quickshell.execDetached(["xdg-open", modelData.what]) }
    }
    EntryList { page: "storage"; width: parent.width }
}
