import QtQuick
import Quickshell
import "../core"
import "../services"
import "../components"

Column {
    spacing: 8
    Rectangle {
        width: parent.width; height: 48; color: "transparent"; border.width: 1; border.color: Theme.line; radius: Theme.radius
        Txt { x: 14; height: parent.height; color: Theme.white
              text: !Config.builtinNotifications ? Labels.t("notifExternal") : Notifs.count + " " + Labels.t("notifStored") + (Settings.dnd ? "  ·  " + Strings.t("dnd") : "") }
        Row {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 6
            Btn { compact: true; text: Labels.t("notifTest"); onActivated: Quickshell.execDetached(["notify-send", "-a", "MONOLITH", "MONOLITH", Labels.t("notifTestBody")]) }
            Btn { compact: true; visible: Notifs.count > 0; text: Strings.t("clearAll"); confirm: true; onActivated: Notifs.clearAll() }
        }
    }
    EntryList { page: "notifications"; width: parent.width }
}
