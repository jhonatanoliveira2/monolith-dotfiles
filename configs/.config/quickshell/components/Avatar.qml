import QtQuick
import QtQuick.Effects
import "../core"

// Round profile picture (services/Profile.qml); the initial of the name when there is none.
Item {
    id: root
    property string source: ""
    property string initial: "?"
    implicitWidth: 32
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        visible: img.status !== Image.Ready
        radius: width / 2
        color: Theme.grayDark
        border.width: 1
        border.color: Theme.line
        Text {
            anchors.centerIn: parent
            text: root.initial
            color: Theme.white
            font.family: Theme.font; font.bold: true
            font.pixelSize: Math.max(8, root.height * 0.45)
        }
    }
    Image {
        id: img
        anchors.fill: parent
        visible: false
        source: root.source ? "file://" + root.source : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(64, root.width * 2), Math.max(64, root.height * 2))
        asynchronous: true
        smooth: true
        mipmap: true
    }
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: width / 2 }
    }
    MultiEffect {
        anchors.fill: parent
        visible: img.status === Image.Ready
        source: img
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
