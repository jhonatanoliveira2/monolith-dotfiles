import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "core"
import "services"
import "components"
import "widgets"

// The widgets of one monitor (services/Widgets.qml). Desktop: a bottom-layer surface under the windows whose
// input mask is only the widgets themselves, so the rest of the desktop stays clickable. Edit mode (`editing`):
// an overlay with a dimmed backdrop and a toolbar where widgets are dragged (snapping to a grid), added and
// removed; Esc or "Done" leaves it. Each instance is loaded only when needed (shell.qml).
// Auto-hide (Settings.widgetsAutoHide): while the monitor's workspace has windows the widgets fade out and are
// then destroyed (no timers or samplers left running); they come back when the workspace is empty again.
// Temporary widgets (Widgets.temps) have their own instance (`tempOnly`) on the top layer, above the windows
// like a pinned note: they show on the workspace they were created on, never auto-hide, and are drawn even
// when the saved widgets are turned off. Only their own area takes clicks.
PanelWindow {
    id: win
    required property var modelData
    property bool editing: false
    property bool tempOnly: false
    property bool addTemp: false            // editor: the "Add" buttons create temporary widgets
    // saved widgets (only when turned on, or while arranging them) and the temporary ones of the workspace shown here
    readonly property var items: !tempOnly && (Settings.widgetsEnabled || editing) ? Widgets.onScreen(modelData.name) : []
    readonly property int workspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    readonly property var temps: tempOnly || editing ? Widgets.tempsOn(workspaceId) : []
    onItemsChanged: console.log("[widgets]", modelData.name, editing ? "editor" : "desktop", "items:", items.length)

    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool busy: monitor !== null && monitor.activeWorkspace !== null && monitor.activeWorkspace.toplevels.values.length > 0
    readonly property bool shown: editing || !Settings.widgetsAutoHide || !busy
    // `alive` drops only after the fade-out, so the widgets disappear smoothly before they are destroyed
    property bool alive: shown
    onShownChanged: if (shown) { unload.stop(); alive = true } else unload.restart()
    Timer { id: unload; interval: Theme.dur(300) + 50; onTriggered: win.alive = win.shown }

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: editing ? WlrLayer.Overlay : tempOnly ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: editing ? "qs-widgets-edit" : "qs-widgets"
    WlrLayershell.keyboardFocus: editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // desktop: clicks only on the widgets; edit mode: the whole screen
    Variants {
        id: regions
        model: win.editing ? [] : (win.shown ? win.items : []).concat(win.temps)
        delegate: Region {
            required property var modelData
            readonly property var d: Widgets.dims(modelData)
            x: modelData.x; y: modelData.y; width: d.w; height: d.h
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

        Item {
            anchors.fill: parent
            opacity: win.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(300); easing.type: Easing.OutCubic } }
            Repeater {
                model: win.alive ? win.items : []
                delegate: WidgetHost { required property var modelData; entry: modelData; editing: win.editing }
            }
        }
        Repeater {
            model: win.temps
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
                // temporary: pinned to this workspace, above the windows, gone when the shell restarts
                Btn { icon: Theme.g(0xf051b); text: Settings.language === "en" ? "Temporary" : "Temporário"; active: win.addTemp; onActivated: win.addTemp = !win.addTemp }
                Rectangle { width: 1; height: 30; color: Theme.line }
                Repeater {
                    model: Widgets.types
                    delegate: Btn {
                        required property var modelData
                        icon: Theme.g(modelData.glyph)
                        text: Widgets.name(modelData)
                        onActivated: win.addTemp ? Widgets.addTemp(modelData.id, win.modelData.name) : Widgets.add(modelData.id, win.modelData.name)
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
