import QtQuick
import "../core"
import "../services"
import "../components"

// Settings > Bar: position and menu style (Registry), the module layout editor (drag and drop between the
// start / center / end zones and "hidden", data in services/BarLayout.qml) and the remaining bar options.
// A floating "ghost" follows the pointer while the chip stays put, so the Flow never fights the drag.
Item {
    id: root
    width: parent ? parent.width : 600
    implicitHeight: col.implicitHeight
    property string dragId: ""
    property bool dragging: false
    readonly property Item ghostItem: ghost

    function label(id) { return Labels.t("mod_" + id) }

    // a module chip: drag it; dropping another chip on it places that one before it
    component Chip: Rectangle {
        id: chip
        // inline components do not see the ids of this file: the page is passed in
        property Item page: null
        property string mid: ""
        property string zone: ""
        width: chipRow.implicitWidth + 22; height: 32; radius: 4
        color: drop.containsDrag ? Theme.hover : chipMouse.containsMouse ? Theme.tint(0.04) : "transparent"
        border.width: 1; border.color: drop.containsDrag ? Theme.white : Theme.line
        opacity: page && page.dragging && page.dragId === mid ? 0.3 : 1
        Row {
            id: chipRow
            anchors.centerIn: parent; spacing: 7
            Txt { text: String.fromCodePoint(BarLayout.info(chip.mid).glyph); color: Theme.grayMid; font.pixelSize: 13 }
            Txt { text: Labels.t("mod_" + chip.mid); color: Theme.foreground }
        }
        Rectangle { visible: drop.containsDrag; x: -4; width: 2; height: parent.height; color: Theme.white }   // insertion mark
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: chip.page && chip.page.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: chip.page ? chip.page.ghostItem : null
            drag.threshold: 4
            readonly property bool active: drag.active
            // set only when the drag starts: on release `active` turns false before onReleased, which must still drop
            onActiveChanged: if (active) chip.page.dragging = true
            onPressed: {
                const g = chip.page.ghostItem, p = chip.mapToItem(chip.page, 0, 0)
                g.x = p.x; g.y = p.y
                g.mid = chip.mid
                chip.page.dragId = chip.mid
            }
            onReleased: {
                if (chip.page.dragging) chip.page.ghostItem.Drag.drop()
                chip.page.dragging = false
                chip.page.dragId = ""
            }
        }
        DropArea { id: drop; anchors.fill: parent; keys: ["barmod"]; onDropped: BarLayout.move(chip.page.dragId, chip.zone, chip.mid) }
    }

    // a zone: its chips in order; dropping on the empty part appends
    component Zone: Rectangle {
        id: zoneBox
        property Item page: null
        property string zone: ""
        readonly property var mods: zone === "hidden" ? BarLayout.hidden : BarLayout.zones[zone]
        width: parent ? parent.width : 600; height: flow.implicitHeight + 46
        color: zoneDrop.containsDrag ? Theme.tint(0.05) : "transparent"
        border.width: 1; border.color: zoneDrop.containsDrag ? Theme.grayLight : Theme.line
        radius: 6
        DropArea { id: zoneDrop; anchors.fill: parent; keys: ["barmod"]; onDropped: BarLayout.move(zoneBox.page.dragId, zoneBox.zone, "") }
        Txt { x: 12; y: 9; text: Labels.t("zone_" + zoneBox.zone); color: Theme.grayLight; font.pixelSize: Theme.small }
        Flow {
            id: flow
            x: 10; y: 32; width: parent.width - 20; spacing: 8
            Repeater { model: zoneBox.mods; delegate: Chip { required property string modelData; page: zoneBox.page; mid: modelData; zone: zoneBox.zone } }
            Txt { visible: zoneBox.mods.length === 0; height: 32; text: "—"; color: Theme.grayDark }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 6

        EntryList { page: "bar"; only: ["position"]; width: parent.width }

        CatHeader { width: parent.width; text: Labels.t("cat_layout") }
        Txt { x: 4; width: parent.width - 8; wrapMode: Text.Wrap; elide: Text.ElideNone; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
              text: Labels.t("barDragHint") }
        Zone { page: root; zone: "start" }
        Zone { page: root; zone: "center" }
        Zone { page: root; zone: "end" }
        Zone { page: root; zone: "hidden" }
        Btn { compact: true; text: Labels.t("resetLayout"); confirm: true; onActivated: BarLayout.reset() }

        EntryList { page: "bar"; except: ["position"]; first: false; width: parent.width }
    }

    // what follows the pointer while dragging
    Rectangle {
        id: ghost
        property string mid: ""
        visible: root.dragging
        z: 100
        width: ghostRow.implicitWidth + 22; height: 32; radius: 4
        color: Theme.panelBg; border.width: 1; border.color: Theme.white
        Drag.active: root.dragging
        Drag.keys: ["barmod"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Row {
            id: ghostRow
            anchors.centerIn: parent; spacing: 7
            Txt { text: ghost.mid ? String.fromCodePoint(BarLayout.info(ghost.mid).glyph) : ""; color: Theme.white; font.pixelSize: 13 }
            Txt { text: ghost.mid ? root.label(ghost.mid) : ""; color: Theme.white }
        }
    }
}
