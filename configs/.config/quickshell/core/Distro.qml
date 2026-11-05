pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The distribution the shell runs on, from /etc/os-release (read once, at startup). Arch Linux and CachyOS
// work the same everywhere in the shell (pacman, paccache, the paru / yay caches, sysfs and /proc): this
// only picks the logo and the name. Other Arch-based systems show the Arch logo, anything else Tux.
Singleton {
    id: root
    // blockLoading: text() waits for this tiny file, so the right logo is there from the first frame
    FileView { id: file; path: "/etc/os-release"; blockLoading: true }
    readonly property var fields: {
        const v = {}
        for (const l of String(file.text()).split("\n")) {
            const i = l.indexOf("=")
            if (i > 0) v[l.slice(0, i)] = l.slice(i + 1).replace(/^["']|["']$/g, "")
        }
        return v
    }
    readonly property string osId: fields.ID || ""                                   // arch, cachyos, ...
    readonly property var like: String(fields.ID_LIKE || "").split(" ").filter(s => s)
    readonly property string name: fields.PRETTY_NAME || fields.NAME || "Linux"
    readonly property bool cachyos: osId === "cachyos"
    readonly property bool archBased: osId === "arch" || like.indexOf("arch") >= 0
    // Nerd Font logos: linux-cachyos, linux-archlinux, linux-tux
    readonly property int glyph: cachyos ? 0xf385 : archBased || osId === "" ? 0xf303 : 0xf31a
    Component.onCompleted: console.log("[distro]", osId || "?", "-", name)
}
