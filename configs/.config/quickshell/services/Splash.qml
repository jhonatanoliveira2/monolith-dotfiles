pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Minimum time of the loading screen (Plymouth) at startup, reboot and power off. The NixOS module
// (nix/modules/nixos/boot.nix) creates /var/lib/monolith/splash-min-seconds (writable by wheel) and reads it at
// every boot and shutdown; without that file (Arch, CachyOS, splash off) the setting is hidden.
Singleton {
    id: root
    readonly property string path: "/var/lib/monolith/splash-min-seconds"
    property bool available: false
    readonly property int seconds: Math.max(0, parseInt(String(file.text()).trim()) || 0)

    function set(n) {
        n = Math.max(0, Math.min(30, Math.round(n)))
        // wheel can write the file; anyone else asks for the password
        write.command = ["sh", "-c", 'printf "%s\\n" "$1" > "$2" 2>/dev/null || pkexec sh -c \'printf "%s\\n" "$1" > "$2"\' sh "$1" "$2"',
                         "sh", String(n), root.path]
        write.running = true
    }

    FileView {
        id: file
        path: root.path
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.available = true
        onLoadFailed: root.available = false
    }
    Process { id: write; onExited: file.reload() }
}
