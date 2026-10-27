import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

// Profile: picture (file chooser, drag and drop or a pasted path), name, subtitle and where it shows
// (Registry entries). Data: services/Profile.qml.
Column {
    id: root
    spacing: 6

    CatHeader { first: true; width: parent.width; text: Labels.t("cat_picture") }
    Rectangle {
        width: parent.width; height: 132
        color: drop.containsDrag ? Theme.hover : "transparent"
        border.width: 1; border.color: drop.containsDrag ? Theme.white : Theme.line

        Avatar { id: big; x: 18; width: 96; height: 96; anchors.verticalCenter: parent.verticalCenter; source: Profile.avatar; initial: Profile.initial }
        Column {
            anchors { left: big.right; leftMargin: 18; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 6
            Txt { width: parent.width; text: Profile.name; color: Theme.white; font.pixelSize: 18 }
            Txt { width: parent.width; text: Profile.subtitle; color: Theme.grayMid; font.bold: false }
            Row {
                spacing: 4
                Btn { compact: true; icon: Theme.g(0xf03e); text: Labels.t("pfChoose"); onActivated: Profile.pick() }
                Btn { compact: true; visible: Profile.hasAvatar; text: Labels.t("pfRemove"); confirm: true; onActivated: Profile.removeAvatar() }
            }
            Txt { width: parent.width; text: Labels.t("pfDrop"); color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false }
        }
        // drop an image file from a file manager
        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: d => { if (d.hasUrls && d.urls.length) Profile.setAvatar(String(d.urls[0])) }
        }
    }
    // or paste a path
    Rectangle {
        width: parent.width; height: 34; color: "transparent"; border.width: 1; border.color: path.activeFocus ? Theme.white : Theme.line
        TextInput {
            id: path
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize
            clip: true; selectByMouse: true
            onAccepted: { Profile.setAvatar(text.replace(/^~/, Quickshell.env("HOME"))); text = "" }
            Txt { visible: path.text === ""; anchors.fill: parent; text: Labels.t("pfPath"); color: Theme.grayMid; font.bold: false }
        }
    }
    Txt { visible: Profile.error !== ""; x: 10; width: parent.width - 20; text: Profile.error; color: Theme.foreground; wrapMode: Text.Wrap; elide: Text.ElideNone }

    EntryList { page: "profile"; first: false; width: parent.width }
    Txt { x: 10; width: parent.width - 20; wrapMode: Text.Wrap; elide: Text.ElideNone; color: Theme.grayMid; font.pixelSize: Theme.small; font.bold: false
          text: Labels.t("pfHelp") }
}
