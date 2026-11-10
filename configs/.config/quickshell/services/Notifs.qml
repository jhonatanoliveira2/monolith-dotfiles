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
    signal arrived(bool critical)         // a toast is shown (Nothing theme: components/EdgeGlow.qml)
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

    // The timeout an application asks for, in ms. D-Bus carries milliseconds and Quickshell 0.3 hands the value
    // over as it is (measured: `-t 300` arrives as 300), while its documentation speaks of seconds; multiplying
    // by 1000 kept a 5 s notification on screen for 83 minutes. A value under 100 can only be seconds (nobody
    // asks for a toast shorter than 0.1 s), anything else is milliseconds; never shorter than 1 s, to be readable.
    function timeoutMs(t) { return Math.max(1000, t < 100 ? t * 1000 : t) }
    function receive(n) {
        n.tracked = true
        trim()
        if (Settings.dnd && n.urgency !== NotificationUrgency.Critical) return
        root.arrived(n.urgency === NotificationUrgency.Critical)
        const t = n.urgency === NotificationUrgency.Critical && Settings.criticalSticky ? 0
            : (n.expireTimeout > 0 ? timeoutMs(n.expireTimeout) : Config.toastTimeout)
        expiry[n.id] = t > 0 ? Date.now() + t : 0
        // a replaced notification (same id) updates in place instead of stacking
        const list = popups.filter(p => p.id !== n.id).concat([n])
        popups = list.slice(Math.max(0, list.length - Math.max(1, Settings.maxToasts)))   // oldest toasts make room
        for (const p of list) if (popups.indexOf(p) < 0) forget(p.id)
        n.closed.connect(() => hidePopup(n))
        schedule()
    }

    function toast(title, body, image) {
        const id = "i" + Date.now()
        internal = internal.concat([{ id: id, title: title, body: body, image: image || "" }])
        expiry[id] = Date.now() + (image ? 5000 : 3500)
        schedule()
    }

    // The history keeps the newest Settings.notifHistoryMax notifications: the oldest ones are dismissed as new
    // ones arrive, so a long session does not hold every notification (and its image) it ever received.
    // Deferred to the next turn of the event loop and never re-entered: dismissing a notification emits its
    // `closed` signal, which comes back here through hidePopup().
    property bool trimming: false
    function trim() { Qt.callLater(trimNow) }
    function trimNow() {
        if (trimming) return
        trimming = true
        const max = Math.max(10, Settings.notifHistoryMax)
        const shown = popups.slice()
        const old = history.slice()
        for (let i = 0; i < old.length - max; i++) if (shown.indexOf(old[i]) < 0) old[i].dismiss()
        trimming = false
    }
    // a toast that left the screen no longer needs its timing entries
    function forget(id) {
        if (expiry[id] !== undefined) delete expiry[id]
        if (held[id] !== undefined) { const h = Object.assign({}, held); delete h[id]; held = h }
    }
    function dismiss(n) { hidePopup(n); n.dismiss() }
    function hidePopup(n) { popups = popups.filter(p => p !== n); forget(n.id); schedule(); if (!trimming) trim() }
    function hideInternal(id) { internal = internal.filter(p => p.id !== id); forget(id); schedule() }
    function clearAll() {
        popups = []
        expiry = ({}); held = ({})
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
            const gone = root.popups.filter(p => due(p.id)).concat(root.internal.filter(p => due(p.id))).map(p => p.id)
            root.popups = root.popups.filter(p => !due(p.id))
            root.internal = root.internal.filter(p => !due(p.id))
            for (const id of gone) root.forget(id)
            if (gone.length) root.trim()          // toasts are never trimmed while shown: catch up now
            root.schedule()
        }
    }
}
