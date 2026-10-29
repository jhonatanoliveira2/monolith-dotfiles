import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

// Colour themes: default (original Monolith), dynamic (wpgtk palette of the wallpaper changed last, on any
// monitor) and presets. Palettes: core/Palettes.qml; generation, wallpaper following and Fish: services/Themes.qml.
Column {
    id: root
    spacing: 4
    readonly property string mode: Settings.themeMode
    readonly property var pal: Settings.themePalette
    readonly property bool hasPalette: Palettes.valid(pal)
    Component.onCompleted: Themes.checkDeps()

    function fileName(p) { return String(p || "").split("/").pop() }
    function monitors(o) { return !o || o === "ALL" ? Labels.t("thAllMonitors") : o.split(",").join(", ") }

    // a row of colour squares
    component Swatches: Row {
        property var colors: []
        property int size: 14
        spacing: 3
        Repeater {
            model: parent.colors
            delegate: Rectangle { required property var modelData; width: parent.size; height: parent.size; color: modelData; border.width: 1; border.color: Theme.line }
        }
    }
    // a selectable theme card
    component Card: Rectangle {
        id: card
        property string title: ""
        property string desc: ""
        property var colors: []
        property bool current: false
        signal picked()
        height: 96
        color: cardMouse.containsMouse ? Theme.hover : current ? Theme.selected : "transparent"
        border.width: current ? 2 : 1
        border.color: current ? Theme.accent : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
        Column {
            x: 12; y: 10; width: parent.width - 24; spacing: 4
            Row {
                width: parent.width; spacing: 8
                Txt { text: card.title; color: Theme.white; font.pixelSize: Theme.fontSize + 1 }
                Txt { visible: card.current; text: Theme.glyph.dot + " " + Labels.t("thActive"); color: Theme.accent; font.pixelSize: Theme.small }
            }
            Txt { width: parent.width; text: card.desc; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
        }
        Swatches { x: 12; anchors { bottom: parent.bottom; bottomMargin: 12 } colors: card.colors }
        MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.picked() }
    }

    // ── theme ──
    CatHeader { first: true; width: parent.width; text: Labels.t("cat_themeMode") }
    Row {
        width: parent.width; spacing: 6
        readonly property real cw: (width - 12) / 3
        Card {
            width: parent.cw; title: Labels.t("thDefault"); desc: Labels.t("thDefaultDesc"); current: root.mode === "default"
            colors: ["#111111", "#444444", "#888888", "#cccccc", "#eeeeee", "#ffffff"]
            onPicked: Themes.setMode("default")
        }
        Card {
            width: parent.cw; title: Labels.t("thDynamic"); desc: Labels.t("thDynamicDesc"); current: root.mode === "dynamic"
            colors: root.hasPalette ? root.pal.colors.slice(0, 8) : []
            onPicked: Themes.setMode("dynamic")
        }
        Card {
            width: parent.cw; title: Labels.t("thPreset"); current: root.mode === "preset"
            desc: (Palettes.preset(Settings.themePreset) || { name: "" }).name
            colors: (Palettes.preset(Settings.themePreset) || { colors: [] }).colors.slice(0, 8)
            onPicked: Themes.setMode("preset")
        }
    }
    SettingRow { width: parent.width; entry: Registry.byPage("themes").find(e => e.id === "themeVscode") }

    // ── dynamic palette ──
    CatHeader { width: parent.width; text: Labels.t("cat_themeDynamic") }
    Rectangle {
        width: parent.width; height: dyn.implicitHeight + 24
        color: "transparent"; border.width: 1; border.color: Theme.line
        // preview of the image (or the video frame) the colours came from
        Rectangle {
            id: thumb
            x: 12; y: 12; width: 192; height: 108
            color: Theme.grayDark; border.width: 1; border.color: Theme.line; clip: true
            Image {
                anchors { fill: parent; margins: 1 }
                source: root.hasPalette && root.pal.frame ? "file://" + root.pal.frame : ""
                fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(384, 216)
            }
            Txt { visible: !root.hasPalette; anchors.centerIn: parent; text: String.fromCodePoint(0xf03e); color: Theme.grayMid; font.pixelSize: 26 }
        }
        Column {
            id: dyn
            anchors { left: thumb.right; leftMargin: 14; right: parent.right; rightMargin: 12; top: parent.top; topMargin: 12 }
            spacing: 6
            // status
            Row {
                spacing: 8
                Txt {
                    id: spin
                    text: Themes.status === "loading" ? Theme.glyph.refresh : Themes.status === "error" ? Theme.glyph.close : Theme.glyph.check
                    color: Themes.status === "error" ? Theme.foreground : Theme.accent
                    RotationAnimator on rotation { running: Themes.status === "loading"; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    onTextChanged: rotation = 0
                }
                Txt {
                    text: Themes.status === "loading" ? Labels.t("thLoading")
                        : Themes.status === "error" ? Labels.t("thError")
                        : root.hasPalette ? (root.mode === "dynamic" ? Labels.t("thApplied") : Labels.t("thReady")) : Labels.t("thNone")
                    color: Theme.white
                }
            }
            Txt {
                visible: Themes.status === "error"
                width: parent.width; wrapMode: Text.Wrap; elide: Text.ElideNone; font.pixelSize: Theme.small; font.bold: false; color: Theme.grayLight
                text: Themes.error + "\n" + (root.hasPalette ? Labels.t("thKept") : Labels.t("thFallback"))
            }
            // source: wallpaper + monitor
            Txt {
                visible: root.hasPalette
                width: parent.width; font.pixelSize: Theme.small; font.bold: false; color: Theme.grayLight
                text: Labels.t("thSource") + ": " + root.fileName(root.pal ? root.pal.source : "")
                      + "   ·   " + (root.pal && root.pal.kind === "video" ? Labels.t("thVideoFrame") : Labels.t("thImage"))
            }
            Txt {
                visible: root.hasPalette
                width: parent.width; font.pixelSize: Theme.small; font.bold: false; color: Theme.grayLight
                text: Labels.t("thMonitor") + ": " + root.monitors(root.pal ? root.pal.outputs : "")
                      + (root.pal && root.pal.time ? "   ·   " + Qt.formatDateTime(new Date(root.pal.time), "dd/MM HH:mm") : "")
            }
            Txt {
                visible: root.hasPalette && Wallpapers.current !== "" && root.pal.source !== Wallpapers.current
                width: parent.width; wrapMode: Text.Wrap; elide: Text.ElideNone; font.pixelSize: Theme.small; font.bold: false; color: Theme.grayMid
                text: Labels.t("thOutdated") + " " + root.fileName(Wallpapers.current)
            }
            Swatches { visible: root.hasPalette; colors: root.hasPalette ? root.pal.colors : []; size: 16 }
            SettingRow { width: parent.width; entry: Registry.byPage("themes").find(e => e.id === "themeFollow") }
            Row {
                spacing: 6
                Btn { compact: true; icon: Theme.glyph.refresh; text: Labels.t("thRegenerate"); active: Themes.status === "loading"
                      onActivated: { if (root.mode !== "dynamic") Settings.themeMode = "dynamic"; Themes.regenerate() } }
                Btn { compact: true; visible: root.mode !== "default"; text: Labels.t("thRestore"); onActivated: Themes.setMode("default") }
            }
        }
    }

    // ── presets ──
    CatHeader { width: parent.width; text: Labels.t("cat_themePresets") }
    Grid {
        id: presetGrid
        width: parent.width; columns: 4; spacing: 6
        readonly property real cw: (width - 18) / 4
        Repeater {
            model: Palettes.presets
            delegate: Card {
                required property var modelData
                width: presetGrid.cw; height: 76
                title: modelData.name
                colors: modelData.colors.slice(1, 7).concat([modelData.background, modelData.foreground])
                current: root.mode === "preset" && Settings.themePreset === modelData.id
                onPicked: Themes.setMode("preset", modelData.id)
            }
        }
    }

    // ── dependencies ──
    CatHeader { width: parent.width; text: Labels.t("cat_themeDeps") }
    Repeater {
        model: Themes.deps
        delegate: Rectangle {
            required property var modelData
            width: root.width; height: 34
            color: "transparent"; border.width: 1; border.color: Theme.line
            Txt { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 20; text: modelData.ok ? Theme.glyph.check : Theme.glyph.close
                  color: modelData.ok ? Theme.accent : Theme.foreground }
            Txt { x: 40; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; color: Theme.foreground }
            Txt { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                  text: modelData.ok ? modelData.detail : Labels.t("thMissing") + "  ·  " + modelData.detail
                  color: modelData.ok ? Theme.grayMid : Theme.white; font.pixelSize: Theme.small; font.bold: !modelData.ok }
        }
    }
    Txt { visible: !Themes.depsChecked; x: 12; text: Labels.t("checking"); color: Theme.grayMid }
    Item { width: 1; height: 4 }
    Btn { compact: true; icon: Theme.glyph.refresh; text: Labels.t("thRecheck"); onActivated: Themes.checkDeps() }

    // ── fish ──
    CatHeader { width: parent.width; text: Labels.t("cat_themeFish") }
    Txt { x: 12; width: parent.width - 24; wrapMode: Text.Wrap; elide: Text.ElideNone; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
          text: Labels.t("thFishHelp") }
}
