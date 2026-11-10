import QtQuick
import "../../core"
import "../../services"
import "../../components"
import "../../settings"

// Performance tab: CPU / GPU / RAM with their top 3 apps, network, the shell's own usage and storage.
// Totals come from Stats, the rest from Perf; both sample only while this tab exists.
Column {
    id: tab
    spacing: 8
    Component.onCompleted: { Stats.demand++; Perf.demand++; Perf.refreshStorage() }
    Component.onDestruction: { Stats.demand--; Perf.demand-- }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: Perf.refreshStorage() }

    function pct(v) { return v >= 10 ? Math.round(v) + "%" : v.toFixed(1) + "%" }
    function rate(b) { return Perf.bytes(b) + "/s" }

    // history as bars that grow from the bottom
    component Spark: Row {
        id: sp
        property var values: []
        property real max: 100
        spacing: 1
        Repeater {
            model: sp.values
            delegate: Rectangle {
                required property var modelData
                anchors.bottom: parent.bottom
                width: Math.max(1, (sp.width - (Perf.historyLength - 1)) / Perf.historyLength)
                height: Math.max(1, sp.height * Math.min(1, modelData / Math.max(1, sp.max)))
                radius: 1
                color: Theme.accent
                opacity: 0.3 + 0.7 * Math.min(1, modelData / Math.max(1, sp.max))
            }
        }
    }
    // top 3 list: name, value and a bar relative to the first
    component Top: Column {
        id: tl
        property var items: []
        property var fmt: v => v
        spacing: 5
        Repeater {
            model: tl.items
            delegate: Item {
                required property var modelData
                required property int index
                width: tl.width; height: 17
                Txt { width: parent.width - val.width - 6; text: modelData.name; color: index === 0 ? Theme.white : Theme.foreground; font.pixelSize: Theme.small; font.bold: index === 0 }
                Txt { id: val; anchors.right: parent.right; text: tl.fmt(modelData.v); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                DotMeter {
                    visible: Theme.nothing
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    dot: 2; gap: 2
                    value: tl.items[0].v > 0 ? modelData.v / tl.items[0].v : 0
                    litColor: index === 0 ? Theme.white : Theme.grayLight
                }
                Rectangle {
                    visible: !Theme.nothing
                    anchors.bottom: parent.bottom
                    height: 2; radius: 1; color: Qt.alpha(Theme.accent, index === 0 ? 0.9 : 0.5)
                    width: parent.width * (tl.items[0].v > 0 ? modelData.v / tl.items[0].v : 0)
                    Behavior on width { NumberAnimation { duration: Theme.dur(400); easing.type: Easing.OutCubic } }
                }
            }
        }
        Txt { visible: tl.items.length === 0; text: "…"; color: Theme.grayMid }
    }
    // CPU / GPU / RAM card
    component Unit: Card {
        id: u
        property string icon: ""
        property string label: ""
        property real value: 0                  // 0..100
        property string temp: ""
        property var lines: []                  // detail lines beside the ring
        property var history: []
        property var apps: []
        property var fmt: v => v
        height: 236
        Txt { x: 12; y: 10; text: u.icon + "  " + u.label; color: Theme.white }
        Rectangle {
            visible: u.temp !== ""
            anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 8 }
            width: tempTxt.implicitWidth + 14; height: 20; radius: 10
            color: Qt.alpha(Theme.accent, 0.15); border.width: 1; border.color: Qt.alpha(Theme.accent, 0.4)
            Txt { id: tempTxt; anchors.centerIn: parent; text: Theme.g(0xf2c9) + " " + u.temp; color: Theme.white; font.pixelSize: Theme.small }
        }
        Ring {
            id: ring
            x: 12; y: 38; width: 76; height: 76; thickness: 7
            value: u.value / 100
            color: u.value >= 85 ? Theme.white : Theme.accent
            Txt { anchors.centerIn: parent; text: Math.round(u.value) + "%"; font.pixelSize: 15; color: Theme.white }
        }
        Column {
            anchors { left: ring.right; leftMargin: 12; right: parent.right; rightMargin: 10; top: ring.top; topMargin: 2 }
            spacing: 3
            Repeater {
                model: u.lines
                delegate: Txt { required property var modelData; width: parent.width; text: modelData; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
            }
            Spark { width: parent.width; height: 26; values: u.history }
        }
        Rectangle { x: 12; y: 124; width: parent.width - 24; height: 1; color: Theme.line }
        Txt { x: 12; y: 132; text: Labels.pick(["Maior uso", "Top apps"]); color: Theme.grayMid; font.pixelSize: 10 }
        Top { x: 12; y: 152; width: parent.width - 24; items: u.apps; fmt: u.fmt }
    }

    Row {
        width: parent.width; spacing: 8
        Unit {
            order: 0; width: (parent.width - 16) / 3
            icon: Theme.g(0xf2db); label: "CPU"
            value: Math.max(0, Stats.cpu); temp: Stats.cpuTemp >= 0 ? Stats.cpuTemp + "°C" : ""
            lines: [Labels.pick(["Uso total", "Total load"])]
            history: Stats.cpuHistory
            apps: Perf.topCpu; fmt: v => tab.pct(v)
        }
        Unit {
            order: 1; width: (parent.width - 16) / 3
            icon: Theme.g(0xf08ae); label: "GPU"
            value: Math.max(0, Stats.gpu); temp: Stats.gpuTemp >= 0 ? Stats.gpuTemp + "°C" : ""
            lines: [Stats.gpu < 0 ? Labels.pick(["Em repouso", "Idle"]) : Labels.pick(["Uso total", "Total load"])]
            history: Stats.gpuHistory
            apps: Perf.topGpu; fmt: v => tab.pct(v)
        }
        Unit {
            order: 2; width: (parent.width - 16) / 3
            icon: Theme.g(0xf035b); label: Labels.pick(["Memória", "Memory"])
            value: Stats.ramPct
            lines: [Stats.ramUsed + " / " + Stats.ramTotal + " GB",
                    Labels.pick(["Livre ", "Available "]) + (Number(Stats.ramTotal) - Number(Stats.ramUsed)).toFixed(1) + " GB"]
            history: Stats.ramHistory
            apps: Perf.topMem; fmt: v => Perf.bytes(v)
        }
    }

    Row {
        width: parent.width; spacing: 8
        // ── network ──
        Card {
            id: net
            order: 3
            width: (parent.width - 8) * 2 / 3; height: 150
            readonly property real peak: Math.max(1024, Math.max.apply(null, Perf.rxHistory.concat(Perf.txHistory, [0])))
            Txt { x: 12; y: 10; text: Theme.g(0xf0ac) + "  Internet"; color: Theme.white }
            Column {
                x: 12; y: 36; width: 150
                spacing: 6
                Column {
                    Txt { text: Theme.g(0xf063) + "  " + tab.rate(Perf.rx); color: Theme.white; font.pixelSize: 16 }
                    Txt { text: Labels.pick(["Download · total ", "Download · total "]) + Perf.bytes(Perf.rxTotal); color: Theme.grayMid; font.pixelSize: 10; font.bold: false }
                }
                Column {
                    Txt { text: Theme.g(0xf062) + "  " + tab.rate(Perf.tx); color: Theme.foreground; font.pixelSize: 16 }
                    Txt { text: Labels.pick(["Upload · total ", "Upload · total "]) + Perf.bytes(Perf.txTotal); color: Theme.grayMid; font.pixelSize: 10; font.bold: false }
                }
            }
            // download grows up from the middle line, upload down from it
            Item {
                id: graph
                anchors { left: parent.left; leftMargin: 176; right: parent.right; rightMargin: 12; top: parent.top; topMargin: 14; bottom: parent.bottom; bottomMargin: 14 }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.line }
                Row {
                    width: parent.width; height: parent.height / 2 - 1
                    spacing: 1
                    Repeater {
                        model: Perf.rxHistory
                        delegate: Rectangle {
                            required property var modelData
                            anchors.bottom: parent.bottom
                            width: Math.max(1, (graph.width - (Perf.historyLength - 1)) / Perf.historyLength)
                            height: Math.max(1, parent.height * modelData / net.peak)
                            radius: 1; color: Theme.accent; opacity: 0.85
                        }
                    }
                }
                Row {
                    y: parent.height / 2 + 1
                    width: parent.width; height: parent.height / 2 - 1
                    spacing: 1
                    Repeater {
                        model: Perf.txHistory
                        delegate: Rectangle {
                            required property var modelData
                            width: Math.max(1, (graph.width - (Perf.historyLength - 1)) / Perf.historyLength)
                            height: Math.max(1, parent.height * modelData / net.peak)
                            radius: 1; color: Theme.grayLight; opacity: 0.55
                        }
                    }
                }
                Txt { anchors { right: parent.right; top: parent.top } text: tab.rate(net.peak); color: Theme.grayMid; font.pixelSize: 9; font.bold: false }
            }
        }
        // ── the shell itself ──
        Card {
            order: 4
            width: (parent.width - 8) / 3; height: 150
            Txt { x: 12; y: 10; text: Theme.g(0xf303) + "  Monolith Shell"; color: Theme.white }
            Column {
                x: 12; y: 40; width: parent.width - 24
                spacing: 9
                Repeater {
                    model: [
                        { k: "CPU", v: tab.pct(Perf.selfCpu), f: Perf.selfCpu / 10 },
                        { k: "RAM", v: Perf.bytes(Perf.selfMem), f: Perf.selfMem / (1024 * 1024 * 1024) },
                        { k: "GPU", v: tab.pct(Perf.selfGpu), f: Perf.selfGpu / 20 }
                    ]
                    delegate: Column {
                        required property var modelData
                        width: parent.width; spacing: 3
                        Item {
                            width: parent.width; height: 15
                            Txt { text: modelData.k; color: Theme.grayMid; font.pixelSize: Theme.small }
                            Txt { anchors.right: parent.right; text: modelData.v; color: Theme.white; font.pixelSize: Theme.small }
                        }
                        Rectangle {
                            width: parent.width; height: 4; radius: 2; color: Theme.grayDark
                            Rectangle { width: Math.max(4, parent.width * Math.min(1, modelData.f)); height: parent.height; radius: 2; color: Theme.accent
                                        Behavior on width { NumberAnimation { duration: Theme.dur(400) } } }
                        }
                    }
                }
            }
        }
    }

    // ── storage: one block per disk, a bar per mounted partition ──
    Card {
        order: 5
        width: parent.width; height: disks.height + 46
        Txt { x: 12; y: 10; text: Theme.g(0xf0a0) + "  " + Labels.pick(["Armazenamento", "Storage"]); color: Theme.white }
        Column {
            id: disks
            x: 12; y: 36; width: parent.width - 24
            spacing: 10
            Repeater {
                model: Perf.disks
                delegate: Column {
                    required property var modelData
                    width: disks.width; spacing: 5
                    Txt { text: modelData.name + (modelData.model ? "  ·  " + modelData.model : "") + "  ·  " + Perf.bytes(modelData.size); color: Theme.foreground; font.pixelSize: Theme.small }
                    Repeater {
                        model: modelData.parts
                        delegate: Item {
                            id: part
                            required property var modelData
                            readonly property real f: modelData.size > 0 ? modelData.used / modelData.size : 0
                            width: disks.width; height: 18
                            Txt { width: 150; anchors.verticalCenter: parent.verticalCenter; text: modelData.mount + "  " + modelData.fs; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
                            Rectangle {
                                x: 156; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 156 - info.width - 10; height: 6; radius: 3
                                color: Theme.nothing ? "transparent" : Theme.grayDark
                                DotMeter { visible: Theme.nothing; anchors.fill: parent; dot: 5; value: part.f
                                           litColor: part.f >= 0.9 ? Theme.white : Theme.grayLight }
                                Rectangle {
                                    visible: !Theme.nothing
                                    width: parent.width * part.f; height: parent.height; radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.55) }
                                        GradientStop { position: 1; color: part.f >= 0.9 ? Theme.white : Theme.accent }
                                    }
                                }
                            }
                            Txt {
                                id: info
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: Perf.bytes(modelData.used) + " / " + Perf.bytes(modelData.size) + "  ·  " + Perf.bytes(modelData.avail) + Labels.pick([" livre", " free"])
                                color: Theme.foreground; font.pixelSize: Theme.small; font.bold: false
                            }
                        }
                    }
                }
            }
        }
    }
}
