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
    property var internal: []            // simple {id, title, body, image} toasts raised by IPC (e.g. screenshots)
    property var expiry: ({})            // id -> ms timestamp (0 = until dismissed)
    property var held: ({})              // id -> true while the pointer is over the toast

    LazyLoader {
        id: server
        active: Config.builtinNotifications
        NotificationServer {
            keepOnReload: true
            actionsSupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: true
            imageSupported: true
            persistenceSupported: true
            onNotification: n => root.receive(n)
        }
    }

    function receive(n) {
        n.tracked = true
        if (Settings.dnd && n.urgency !== NotificationUrgency.Critical) return
        const t = n.urgency === NotificationUrgency.Critical && Settings.criticalSticky ? 0
            : (n.expireTimeout > 0 ? n.expireTimeout * 1000 : Config.toastTimeout)
        expiry[n.id] = t > 0 ? Date.now() + t : 0
        // a replaced notification (same id) updates in place instead of stacking
        const list = popups.filter(p => p.id !== n.id).concat([n])
        popups = list.slice(Math.max(0, list.length - Math.max(1, Settings.maxToasts)))   // oldest toasts make room
        n.closed.connect(() => hidePopup(n))
        schedule()
    }

    function toast(title, body, image) {
        const id = "i" + Date.now()
        internal = internal.concat([{ id: id, title: title, body: body, image: image || "" }])
        expiry[id] = Date.now() + (image ? 5000 : 3500)
        schedule()
    }

    function dismiss(n) { hidePopup(n); n.dismiss() }
    function hidePopup(n) { popups = popups.filter(p => p !== n); schedule() }
    function hideInternal(id) { internal = internal.filter(p => p.id !== id); schedule() }
    function clearAll() {
        popups = []
        const items = history.slice()
        for (const n of items) n.dismiss()
    }
    // hovering a toast pauses its timeout; leaving it gives it a couple more seconds
    function hold(id, on) {
        held = Object.assign({}, held, { [id]: on })
        if (!on && expiry[id] > 0) expiry[id] = Math.max(expiry[id], Date.now() + 2000)
        schedule()
    }

    // One timer aimed at the next expiry (no fixed-rate ticking).
    function schedule() {
        const now = Date.now()
        let next = Infinity
        for (const p of popups) if (expiry[p.id] > 0 && !held[p.id]) next = Math.min(next, expiry[p.id])
        for (const p of internal) if (!held[p.id]) next = Math.min(next, expiry[p.id])
        if (next === Infinity) { expire.stop(); return }
        expire.interval = Math.max(50, next - now)
        expire.restart()
    }
    Timer {
        id: expire
        onTriggered: {
            const now = Date.now()
            const due = id => !root.held[id] && root.expiry[id] > 0 && root.expiry[id] <= now + 30
            root.popups = root.popups.filter(p => !due(p.id))
            root.internal = root.internal.filter(p => !due(p.id))
            root.schedule()
        }
    }
}
