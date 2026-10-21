
import QtQuick
import "../core"

BarItem {
    id: root

    property string menu: ""
    property string screenName: ""
    signal alt(var mouse)

    active: menu !== ""
        && Popups.current === menu
        && Popups.screenName === screenName

    HoverHandler {
        id: hover
    
        onHoveredChanged: {
            if (hovered) {
                Popups.cancelClose()
                Popups.show(root.menu, root.screenName, root)
            } else {
                Popups.scheduleClose()
            }
        }
    }

    onClicked: m => {
        if (m.button === Qt.LeftButton && menu !== "")
            Popups.toggle(menu, screenName, root)
        else
            root.alt(m)
    }

    Component.onCompleted: {
        if (menu !== "")
            Popups.register(screenName, menu, root)
    }
}
