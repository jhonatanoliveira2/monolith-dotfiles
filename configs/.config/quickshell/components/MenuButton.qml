import QtQuick
import "../core"

// Bar button that owns a menu: click toggles it; while any menu is open, hovering moves it here.
BarItem {
    id: root
    property string menu: ""
    property string screenName: ""
    signal alt(var mouse)

    active: menu !== "" && Popups.current === menu && Popups.screenName === screenName

    onHoveredChanged: if (hovered && menu !== "") Popups.hover(menu, screenName, root)

    onClicked: m => {
        if (m.button === Qt.LeftButton && menu !== "") Popups.toggle(menu, screenName, root)
        else root.alt(m)
    }

    Component.onCompleted: if (menu !== "") Popups.register(screenName, menu, root)
}
