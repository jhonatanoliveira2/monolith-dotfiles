import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../core"
import "../services"
import "../components"

// Floating notifications (top right, under the bar). Only exists on the focused monitor and only while there is something to show.
// Hover holds a toast, click runs its default action, right click dismisses it.
PanelWindow {
    id: win
    readonly property bool mine: Hyprland.focusedMonitor === null || screen === null || Hyprland.focusedMonitor.name === screen.name
    readonly property int total: Notifs.popups.length + Notifs.internal.length

    visible: mine && total > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    // top-right corner, clear of the bar wherever it is
    margins { top: Settings.barPosition === "top" ? Theme.barSize + Theme.gap : 6; right: Settings.barPosition === "right" ? Theme.barSize + 6 : 6 }
    implicitWidth: 370
    implicitHeight: Math.max(1, stack.implicitHeight)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-toasts"

    component Card: Rectangle {
        id: card
        property string tid: ""
        default property alias body: inner.data
        width: stack.width
        implicitHeight: inner.implicitHeight + 18
        radius: Theme.menuRadius
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.line
        // slide in from the right
        x: shownIn ? 0 : 40
        opacity: shownIn ? 1 : 0
        property bool shownIn: false
        Component.onCompleted: shownIn = true
        Behavior on x { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }
        signal clicked(var mouse)
        HoverHandler { onHoveredChanged: Notifs.hold(card.tid, hovered) }
        MouseArea {     // below the content so action buttons stay clickable
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => card.clicked(m)
        }
        Item {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 9 }
            implicitHeight: childrenRect.height
        }
    }

    Column {
        id: stack
        width: parent.width
        spacing: 6
        move: Transition { NumberAnimation { properties: "y"; duration: Theme.dur(180); easing.type: Easing.OutCubic } }

        Repeater {
            model: Notifs.internal
            delegate: Card {
                required property var modelData
                tid: modelData.id
                Row {
                    width: parent.width
                    spacing: 10
                    Image {
                        visible: modelData.image !== ""
                        width: visible ? 96 : 0; height: 54
                        source: modelData.image ? "file://" + modelData.image : ""
                        sourceSize.width: 192
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Column {
                        width: parent.width - (modelData.image ? 106 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        Txt { width: parent.width; text: modelData.title; color: Theme.foreground }
                        Txt { width: parent.width; text: modelData.body; font.bold: false; font.pixelSize: 12 }
                    }
                }
                onClicked: m => {
                    if (m.button === Qt.LeftButton && modelData.image) Quickshell.execDetached(["xdg-open", modelData.image])
                    Notifs.hideInternal(modelData.id)
                }
            }
        }

        Repeater {
            model: Notifs.popups
            delegate: Card {
                id: toast
                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property var defaultAction: modelData.actions.find(a => a.identifier === "default") || null
                readonly property var buttons: modelData.actions.filter(a => a.identifier !== "default")
                tid: modelData.id
                border.color: critical ? Theme.white : Theme.line

                onClicked: m => {
                    if (m.button === Qt.RightButton) { Notifs.dismiss(modelData); return }
                    if (toast.defaultAction) toast.defaultAction.invoke()
                    Notifs.hidePopup(modelData)
                }
                Row {
                    width: parent.width
                    spacing: 10
                    Item {
                        id: pic
                        readonly property string src: modelData.image || (modelData.appIcon ? Quickshell.iconPath(modelData.appIcon, true) : "")
                        visible: src !== ""
                        width: visible ? 36 : 0; height: 36
                        IconImage { anchors.fill: parent; source: pic.src; asynchronous: true }
                    }
                    Column {
                        width: parent.width - (pic.visible ? 46 : 0)
                        spacing: 3
                        Txt { width: parent.width; text: modelData.appName; color: Theme.grayMid; font.pixelSize: Theme.small }
                        Txt { width: parent.width; text: modelData.summary; color: Theme.foreground }
                        Txt {
                            visible: modelData.body !== ""
                            width: parent.width; text: modelData.body; font.bold: false; font.pixelSize: 12
                            textFormat: Text.StyledText; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                        Flow {
                            visible: toast.buttons.length > 0
                            width: parent.width; spacing: 4; topPadding: 4
                            Repeater {
                                model: toast.buttons
                                delegate: Btn { required property var modelData; compact: true; text: modelData.text; onActivated: modelData.invoke() }
                            }
                        }
                    }
                }
            }
        }
    }
}
