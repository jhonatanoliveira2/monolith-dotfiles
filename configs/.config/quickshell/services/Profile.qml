pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// The user's profile: display name, subtitle and an optional picture, shown in the quick menu, the Settings
// sidebar, the bar (instead of the Arch logo, optional) and on hyprlock.
//  - the picture is copied (center-cropped to 512 px with ImageMagick when installed) into the state dir,
//    with a new name on every change so Image never shows a cached old one; also written to ~/.face
//    (the usual login-screen picture; an existing one is kept once as ~/.face.bak)
//  - hyprlock reads ~/.config/hypr/generated/lock-avatar.png and lock-name (see hypr/hyprlock.conf);
//    both files are removed when the lock screen option is off, so nothing is drawn there
Singleton {
    id: root
    readonly property string user: Quickshell.env("USER") || ""
    property string host: ""
    property string realName: ""
    readonly property string name: Settings.profileName.trim() || realName || user
    readonly property string subtitle: Settings.profileSubtitle.trim() || (user + (host ? "@" + host : ""))
    readonly property string avatar: Settings.profileAvatar
    readonly property bool hasAvatar: avatar !== ""
    readonly property string initial: name ? name.charAt(0).toUpperCase() : "?"
    property string error: ""
    readonly property string dir: Settings.dir + "/profile"
    readonly property string lockDir: Quickshell.env("HOME") + "/.config/hypr/generated"

    Process {
        running: true
        command: ["sh", "-c", "uname -n; getent passwd \"$1\" | cut -d: -f5 | cut -d, -f1", "sh", root.user]
        stdout: StdioCollector {
            onStreamFinished: { const l = text.split("\n"); root.host = (l[0] || "").trim(); root.realName = (l[1] || "").trim() }
        }
    }

    // path or file:// URL of any image (png, jpg, webp, …)
    function setAvatar(path) {
        const p = decodeURIComponent(String(path).replace(/^file:\/\//, "")).trim()
        if (!p) return
        error = ""
        copy.command = ["sh", "-c", `
            src="$1"; dir="$2"; dst="$2/avatar-$3.png"
            [ -f "$src" ] || { echo "!$src"; exit 1; }
            mkdir -p "$dir" || exit 1
            if command -v magick >/dev/null 2>&1; then
                magick "$src[0]" -auto-orient -resize '512x512^' -gravity center -extent 512x512 "$dst" 2>/dev/null || cp -f "$src" "$dst"
            else cp -f "$src" "$dst"; fi || exit 1
            find "$dir" -maxdepth 1 -name 'avatar-*' ! -path "$dst" -delete
            [ -e "$HOME/.face" ] && [ ! -e "$HOME/.face.bak" ] && cp -f "$HOME/.face" "$HOME/.face.bak"
            cp -f "$dst" "$HOME/.face"
            echo "$dst"`, "sh", p, dir, String(Date.now())]
        copy.running = true
    }
    function removeAvatar() {
        Quickshell.execDetached(["sh", "-c", "find \"$1\" -maxdepth 1 -name 'avatar-*' -delete; rm -f \"$HOME/.face\"; " +
                                 "[ -e \"$HOME/.face.bak\" ] && mv -f \"$HOME/.face.bak\" \"$HOME/.face\"", "sh", dir])
        Settings.profileAvatar = ""
    }
    // file chooser: zenity, kdialog or yad, whichever is installed
    function pick() {
        error = ""
        picker.running = true
    }

    Process {
        id: copy
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out.startsWith("!")) root.error = Strings.t("pfNoFile") + ": " + out.slice(1)
                else if (out) Settings.profileAvatar = out
            }
        }
        onExited: code => { if (code !== 0 && !root.error) root.error = Strings.t("pfCopyFail") }
    }
    Process {
        id: picker
        command: ["sh", "-c", `
            f='*.png *.jpg *.jpeg *.webp *.gif *.bmp'
            if command -v zenity >/dev/null 2>&1; then exec zenity --file-selection --title="$1" --file-filter="$1 | $f"
            elif command -v kdialog >/dev/null 2>&1; then exec kdialog --getopenfilename "$HOME" "$f"
            elif command -v yad >/dev/null 2>&1; then exec yad --file --title="$1" --file-filter="$f"
            else echo "!none"; fi`, "sh", Strings.t("pfPick")]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out === "!none") root.error = Strings.t("pfNoPicker")
                else if (out) root.setAvatar(out)
            }
        }
    }

    // ── hyprlock ──
    function syncLock() { lockSync.restart() }
    onNameChanged: syncLock()
    onAvatarChanged: syncLock()
    Connections {
        target: Settings
        function onProfileOnLockChanged() { root.syncLock() }
        function onLoadedOnce() { root.syncLock() }
    }
    Timer {
        id: lockSync
        interval: 500
        onTriggered: Quickshell.execDetached(["sh", "-c", `
            g="$1"; mkdir -p "$g" || exit 1
            if [ "$2" = 1 ]; then
                printf '%s' "$3" > "$g/lock-name"
                if [ -f "$4" ]; then cp -f "$4" "$g/lock-avatar.png"; else rm -f "$g/lock-avatar.png"; fi
            else rm -f "$g/lock-name" "$g/lock-avatar.png"; fi`,
            "sh", root.lockDir, Settings.profileOnLock ? "1" : "0", root.name, root.avatar])
    }
}
