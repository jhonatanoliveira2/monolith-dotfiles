import QtQuick
import "../core"

// Card of the center menu: a softly lit panel with a light drop shadow (two plain rectangles, no blur) that
// slides and fades in `order` steps after it is created (menu open or tab switch).
Rectangle {
    id: card
    property int order: 0
    property color topColor: Theme.tint(0.075)          // gradient, top to bottom
    property color bottomColor: Theme.tint(0.03)
    radius: Theme.radius + 2
    border.width: 1; border.color: Theme.line
    gradient: Gradient {
        GradientStop { position: 0; color: card.topColor }
        GradientStop { position: 1; color: card.bottomColor }
    }
    // depth: shadow below, a hairline of light along the top edge
    Rectangle { z: -1; x: 1; y: 3; width: parent.width - 2; height: parent.height; radius: parent.radius; color: "#000000"; opacity: 0.16 }
    Rectangle { x: parent.radius; y: 1; width: parent.width - 2 * parent.radius; height: 1; color: Theme.tint(0.12) }

    opacity: 0
    property real lift: 10
    transform: Translate { y: card.lift }
    Component.onCompleted: intro.start()
    SequentialAnimation {
        id: intro
        PauseAnimation { duration: Theme.dur(30 + card.order * 45) }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.dur(260); easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "lift"; to: 0; duration: Theme.dur(320); easing.type: Easing.OutCubic }
        }
    }
}
