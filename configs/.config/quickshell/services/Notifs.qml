pragma Singleton
import QtQuick
import "../core"
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon (org.freedesktop.Notifications) built into the shell: toasts + history + Do Not Disturb.
// Set Config.builtinNotifications = false to keep your notification system (only one daemon can own the D-Bus name).
Singleton {
    id: root
    readonly property bool dnd: Settings.dnd
    readonly property var history: server.item ? server.item.trackedNotifications.values : []
    readonly property int count: history.length
    property var popups: []              // Notification objects currently shown as toasts
    property var internal: []            // simple {title, body} toasts raised by IPC (e.g. screenshots)
    property var expiry: ({})

    LazyLoader {
        id: server
        active: Config.builtinNotifications
        NotificationServer {
            keepOnReload: true
            actionsSupported: true
            bodyMarkupSupported: true
            imageSupported: true
            persistenceSupported: true
            onNotification: n => root.receive(n)
        }
    }

    function receive(n) {
        n.tracked = true
        if (Settings.dnd && n.urgency !== NotificationUrgency.Critical) return
        const t = n.urgency === NotificationUrgency.Critical ? 0
            : (n.expireTimeout > 0 ? n.expireTimeout * 1000 : Config.toastTimeout)
        expiry[n.id] = t > 0 ? Date.now() + t : 0
        popups = popups.concat([n])
    }

    function toast(title, body) {
        const id = "i" + Date.now()
        internal = internal.concat([{ id: id, title: title, body: body }])
        expiry[id] = Date.now() + 3500
    }

    function dismiss(n) { popups = popups.filter(p => p !== n); n.dismiss() }
    function hidePopup(n) { popups = popups.filter(p => p !== n) }
    function clearAll() {
        popups = []
        const items = history.slice()
        for (const n of items) n.dismiss()
    }

    // One cheap tick, only while something is on screen.
    Timer {
        interval: 1000
        repeat: true
        running: root.popups.length > 0 || root.internal.length > 0
        onTriggered: {
            const now = Date.now()
            root.popups = root.popups.filter(p => !(root.expiry[p.id] > 0 && root.expiry[p.id] <= now))
            root.internal = root.internal.filter(p => root.expiry[p.id] > now)
        }
    }
}
