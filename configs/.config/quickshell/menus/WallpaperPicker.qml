import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

// Wallpaper picker (Super+D / quick menu; wallpaper-menu's rofi menu stays the fallback): static images (awww) and live videos (mpvpaper) through
// services/Wallpapers.qml. Tabs, monitor, search and a grid of previews; arrows + Enter, typing filters.
// The monitor starts on the focused one (the overlay opens there); the order comes from Settings > Wallpapers.
Overlay {
    id: win
    name: "wallpaper"
    cardWidth: 1180
    cardHeight: 720
    property string kind: Wallpapers.currentKind === "video" ? "video" : "image"
    property string output: Quickshell.screens.length > 1 && screen ? screen.name : "ALL"
    property string query: ""
    // random order: one shuffle per opening, so the grid does not jump when the list is rescanned
    property var ranks: ({})
    function rank(path) { if (!(path in ranks)) ranks[path] = Math.random(); return ranks[path] }
    readonly property var all: {
        const list = (kind === "video" ? Wallpapers.videos : Wallpapers.images).slice()
        const byName = (a, b) => a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: "base" })
        if (Settings.wpOrder === "random") return list.sort((a, b) => rank(a.path) - rank(b.path))
        if (Settings.wpOrder === "name_desc") return list.sort((a, b) => byName(b, a))
        return list.sort(byName)
    }
    readonly property var visibleList: query ? all.filter(w => w.name.toLowerCase().indexOf(query.toLowerCase()) >= 0) : all
    Component.onCompleted: { Wallpapers.refresh(); search.forceActiveFocus() }
    // previews created right after the list changes (tab, search, rescan) ease in one after another
    property bool fresh: true
    onVisibleListChanged: { fresh = true; freshOff.restart() }
    Timer { id: freshOff; interval: 700; running: true; onTriggered: win.fresh = false }

    function choose(w) {
        if (!w) return
        Wallpapers.apply(kind === "video" ? "live" : "static", w.path, output)
    }
    // a random one from the visible list (tab and search apply), other than the current one when possible
    function chooseRandom() {
        const pool = visibleList.length > 1 ? visibleList.filter(w => w.path !== Wallpapers.current) : visibleList
        if (!pool.length) return
        const w = pool[Math.floor(Math.random() * pool.length)]
        grid.currentIndex = visibleList.indexOf(w)
        choose(w)
    }

    Item {
        anchors.fill: parent
        anchors.margins: 18

        // ── header: tabs, monitors, search ──
        Row {
            id: head
            width: parent.width; spacing: 6
            Txt { text: String.fromCodePoint(0xf03e) + "   " + Strings.t("wallpaper"); color: Theme.white; font.pixelSize: 16; height: 32 }
            Item { width: 14; height: 1 }
            Btn { compact: true; text: Strings.t("wpStatic") + "  " + Wallpapers.images.length; active: win.kind === "image"; onActivated: { win.kind = "image"; grid.currentIndex = 0 } }
            Btn { compact: true; text: Strings.t("wpLive") + "  " + Wallpapers.videos.length; active: win.kind === "video"; onActivated: { win.kind = "video"; grid.currentIndex = 0 } }
            Item { width: 14; height: 1 }
            Btn { visible: Quickshell.screens.length > 1; compact: true; text: Strings.t("wpAll"); active: win.output === "ALL"; onActivated: win.output = "ALL" }
            Repeater {
                model: Quickshell.screens.length > 1 ? Quickshell.screens : []
                delegate: Btn { required property var modelData; compact: true; text: modelData.name; active: win.output === modelData.name; onActivated: win.output = modelData.name }
            }
        }
        Rectangle {
            id: box
            anchors { top: head.bottom; topMargin: 12; left: parent.left; right: parent.right }
            height: 34; color: "transparent"; border.width: 1; border.color: search.activeFocus ? Theme.white : Theme.line; radius: 4
            Txt { id: mag; x: 10; height: parent.height; text: String.fromCodePoint(0xf002); color: Theme.grayMid }
            TextInput {
                id: search
                anchors { left: mag.right; leftMargin: 10; right: parent.right; rightMargin: 10; top: parent.top; bottom: parent.bottom }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1
                clip: true
                onTextChanged: { win.query = text; grid.currentIndex = 0 }
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Right) { grid.moveCurrentIndexRight(); e.accepted = true }
                    else if (e.key === Qt.Key_Left) { grid.moveCurrentIndexLeft(); e.accepted = true }
                    else if (e.key === Qt.Key_Down) { grid.moveCurrentIndexDown(); e.accepted = true }
                    else if (e.key === Qt.Key_Up) { grid.moveCurrentIndexUp(); e.accepted = true }
                    else if (e.key === Qt.Key_Tab) { win.kind = win.kind === "image" ? "video" : "image"; grid.currentIndex = 0; e.accepted = true }
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.choose(win.visibleList[grid.currentIndex]); e.accepted = true }
                }
                Txt { visible: search.text === ""; anchors.fill: parent; text: Strings.t("wpSearch"); color: Theme.grayMid; font.bold: false }
            }
        }

        // ── grid ──
        GridView {
            id: grid
            anchors { top: box.bottom; topMargin: 14; left: parent.left; right: parent.right; bottom: foot.top; bottomMargin: 10 }
            clip: true
            cellWidth: Math.floor(width / Math.max(2, Settings.wpColumns))
            cellHeight: Math.round((cellWidth - 12) * 9 / 16) + 40
            model: win.visibleList
            boundsBehavior: Flickable.StopAtBounds
            // keyboard moves scroll smoothly to keep the focused preview in view
            highlight: Item {}
            highlightFollowsCurrentItem: true
            highlightMoveDuration: Theme.dur(200)
            highlightRangeMode: GridView.ApplyRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: height
            // smooth wheel scrolling (the default jumps a whole step per notch)
            NumberAnimation { id: glide; target: grid; property: "contentY"; duration: Theme.dur(260); easing.type: Easing.OutCubic }
            WheelHandler {
                onWheel: e => {
                    const max = Math.max(0, grid.contentHeight - grid.height) + grid.originY
                    const from = glide.running ? glide.to : grid.contentY
                    glide.stop()
                    glide.to = Math.max(grid.originY, Math.min(max, from - e.angleDelta.y * 1.4))
                    glide.start()
                }
            }
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool isCurrent: modelData.path === Wallpapers.current
                readonly property bool focused: GridView.isCurrentItem
                width: grid.cellWidth; height: grid.cellHeight
                opacity: win.fresh ? 0 : 1
                transform: Translate { id: rise; y: win.fresh ? 16 : 0 }
                Component.onCompleted: if (win.fresh) enter.start()
                SequentialAnimation {
                    id: enter
                    PauseAnimation { duration: Theme.dur(Math.min(cell.index, 16) * 22) }
                    ParallelAnimation {
                        NumberAnimation { target: cell; property: "opacity"; to: 1; duration: Theme.dur(220); easing.type: Easing.OutCubic }
                        NumberAnimation { target: rise; property: "y"; to: 0; duration: Theme.dur(280); easing.type: Easing.OutCubic }
                    }
                }
                // a short press-and-release pulse when a wallpaper is applied
                SequentialAnimation {
                    id: pulse
                    NumberAnimation { target: frame; property: "scale"; to: 0.94; duration: Theme.dur(90); easing.type: Easing.OutCubic }
                    NumberAnimation { target: frame; property: "scale"; to: 1; duration: Theme.dur(260); easing.type: Easing.OutBack }
                }
                Rectangle {
                    id: frame
                    x: 6; y: 6; width: parent.width - 12; height: Math.round(width * 9 / 16)
                    radius: 6; color: Theme.grayDark; clip: true
                    border.width: cell.focused || cell.isCurrent || ma.containsMouse ? 2 : 1
                    border.color: cell.isCurrent ? Theme.white : cell.focused || ma.containsMouse ? Theme.grayLight : Theme.line
                    scale: ma.containsMouse ? 1.025 : 1
                    Behavior on scale { enabled: !pulse.running; NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutCubic } }
                    Behavior on border.width { NumberAnimation { duration: Theme.dur(120) } }
                    Image {
                        anchors { fill: parent; margins: 2 }
                        source: cell.modelData.thumb ? "file://" + cell.modelData.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(480, 270)
                    }
                    Txt { visible: !cell.modelData.thumb; anchors.centerIn: parent; text: String.fromCodePoint(win.kind === "video" ? 0xf03d : 0xf03e); color: Theme.grayMid; font.pixelSize: 26 }
                    Rectangle {
                        anchors { right: parent.right; top: parent.top; margins: 8 }
                        width: 22; height: 22; radius: 11; color: Theme.accent
                        scale: cell.isCurrent ? 1 : 0
                        visible: scale > 0
                        Behavior on scale { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutBack } }
                        Txt { anchors.centerIn: parent; text: String.fromCodePoint(0xf00c); color: Theme.onAccent; font.pixelSize: 11 }
                    }
                }
                Txt { anchors { top: frame.bottom; topMargin: 6; left: frame.left; right: frame.right } horizontalAlignment: Text.AlignHCenter
                      text: cell.modelData.name; color: cell.isCurrent ? Theme.white : Theme.grayLight; font.pixelSize: Theme.small; font.bold: cell.isCurrent }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: { grid.currentIndex = cell.index; pulse.restart(); win.choose(cell.modelData) } }
            }
            Txt {
                visible: grid.count === 0
                anchors.centerIn: parent
                text: Wallpapers.loading ? Strings.t("wpLoading") : Strings.t("wpEmpty")
                color: Theme.grayMid
            }
        }
        HoverScrollBar { flick: grid; anchors.rightMargin: -12 }

        // ── footer ──
        Row {
            id: foot
            anchors { left: parent.left; bottom: parent.bottom }
            spacing: 8
            Txt { anchors.verticalCenter: parent.verticalCenter; text: Wallpapers.error || Strings.t("wpKeys"); color: Wallpapers.error ? Theme.foreground : Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
        }
        Row {
            anchors { right: parent.right; bottom: parent.bottom }
            spacing: 6
            Btn { compact: true; icon: Theme.glyph.shuffle; text: Strings.t("wpRandom"); onActivated: win.chooseRandom() }
            // dynamic theme from the current wallpaper, for when it does not follow every change on its own
            Btn { visible: !(Themes.dynamic && Settings.themeFollow); compact: true; icon: String.fromCodePoint(0xf03d8); text: Strings.t("wpTheme")
                  active: Themes.status === "loading"; onActivated: Themes.applyWallpaper() }
            Btn { compact: true; icon: Theme.glyph.refresh; text: Strings.t("rescan"); active: Wallpapers.loading; onActivated: Wallpapers.refresh() }
            Btn { compact: true; icon: Theme.glyph.cog; text: Strings.t("wpSettings"); onActivated: { Popups.closeOverlay(); Popups.openApp("wallpaper") } }
        }
    }
}
