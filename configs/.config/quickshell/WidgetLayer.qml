import QtQuick
import Quickshell
import Quickshell.Wayland
import "core"
import "services"
import "components"
import "widgets"

// The widgets of one monitor (services/Widgets.qml). Desktop: a bottom-layer surface under the windows whose
// input mask is only the widgets themselves, so the rest of the desktop stays clickable. Edit mode (`editing`):
// an overlay with a dimmed backdrop and a toolbar where widgets are dragged (snapping to a grid), added and
// removed; Esc or "Done" leaves it. Each instance is loaded only when needed (shell.qml).
PanelWindow {
    id: win
    required property var modelData
    property bool editing: false
    readonly property var items: Widgets.onScreen(modelData.name)
    onItemsChanged: console.log("[widgets]", modelData.name, editing ? "editor" : "desktop", "items:", items.length)

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: editing ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.namespace: editing ? "qs-widgets-edit" : "qs-widgets"
    WlrLayershell.keyboardFocus: editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // desktop: clicks only on the widgets; edit mode: the whole screen
    Variants {
        id: regions
        model: win.editing ? [] : win.items
        delegate: Region {
            required property var modelData
            readonly property var t: Widgets.type(modelData.type)
            x: modelData.x; y: modelData.y; width: t ? t.w : 0; height: t ? t.h : 0
        }
    }
    Region { id: partMask; regions: regions.instances }
    Region { id: fullMask; item: root }
    mask: editing ? fullMask : partMask

    Item {
        id: root
        anchors.fill: parent
        focus: win.editing
        Keys.onEscapePressed: Widgets.edit(false)

        Rectangle {
            anchors.fill: parent
            visible: win.editing
            color: Qt.rgba(0, 0, 0, 0.35)
            // grid dots, painted once
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.fillStyle = "rgba(255,255,255,0.18)"
                    for (let x = 0; x < width; x += 48) for (let y = 0; y < height; y += 48) ctx.fillRect(x, y, 2, 2)
                }
            }
            MouseArea { anchors.fill: parent }   // swallow clicks on the backdrop
        }

        Repeater {
            model: win.items
            delegate: WidgetHost { required property var modelData; entry: modelData; editing: win.editing }
        }

        // edit toolbar
        Rectangle {
            visible: win.editing
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 24 }
            width: bar.implicitWidth + 24; height: bar.implicitHeight + 20
            radius: Theme.menuRadius
            color: Theme.panelBg
            border.width: 1; border.color: Theme.line
            Row {
                id: bar
                anchors.centerIn: parent
                spacing: 6
                Txt { height: 30; verticalAlignment: Text.AlignVCenter; rightPadding: 6; text: Settings.language === "en" ? "Add:" : "Adicionar:"; color: Theme.grayMid }
                Repeater {
                    model: Widgets.types
                    delegate: Btn {
                        required property var modelData
                        icon: Theme.g(modelData.glyph)
                        text: Widgets.name(modelData)
                        onActivated: Widgets.add(modelData.id, win.modelData.name)
                    }
                }
                Rectangle { width: 1; height: 30; color: Theme.line }
                Btn { icon: Theme.glyph.check; text: Settings.language === "en" ? "Done" : "Concluir"; active: true; onActivated: Widgets.edit(false) }
            }
        }
        Txt {
            visible: win.editing
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 24 }
            text: Settings.language === "en" ? "Drag to move  ·  × removes  ·  Esc to finish" : "Arraste para mover  ·  × remove  ·  Esc para concluir"
            color: Theme.grayLight; font.pixelSize: Theme.small
        }
    }
}
