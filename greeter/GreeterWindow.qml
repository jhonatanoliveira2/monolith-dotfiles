import QtQuick
import Quickshell
import Quickshell.Services.Greetd
import "core"
import "components"

// The greeter's only window (cage shows it full screen). Layout of the opening frame = Plymouth's last frame
// (branding/build.sh, branding/plymouth/monolith.script): mark height 20 % of the screen, top at
// 50 % - 0.62 x mark, wordmark 11 % of the mark, 16 % below it, the progress line 16 % below the wordmark.
FloatingWindow {
    id: win
    required property var greeter
    property string hostname: ""
    readonly property var cfg: greeter.cfg
    title: "MONOLITH greeter"
    color: "black"

    function focusField() { field.forceActiveFocus() }
    function shake() { shakeAnim.restart() }
    // success: one light sweep across the mark, fade to black, then `done` (greetd starts the session)
    function leave(done) {
        leaveDone = done
        if (!Theme.animations) { done(); return }
        sweep.play()
        fadeOut.start()
    }
    property var leaveDone: null

    Component.onCompleted: {
        const ready = Quickshell.env("MONOLITH_GREETER_READY")
        if (ready) Quickshell.execDetached(["touch", ready])   // the wrapper's watchdog: the greeter is up
        intro.start()
        field.forceActiveFocus()
    }

    // ── opening: 0 = Plymouth's frame, 1 = login layout ──
    property real phase: 0
    NumberAnimation {
        id: intro
        target: win; property: "phase"; from: 0; to: 1
        duration: Theme.dur(1100); easing.type: Easing.InOutCubic
    }
    function mix(a, b) { return a + (b - a) * phase }
    readonly property real screenH: height
    readonly property real markH: mix(screenH * 0.20, screenH * 0.085)
    readonly property real markY: mix(screenH / 2 - screenH * 0.20 * 0.62, screenH * 0.07)
    readonly property real ui: Math.max(0, Math.min(1, (phase - 0.45) / 0.55))   // login fades in late

    Item {
        id: stage
        anchors.fill: parent
        focus: true

        // optional wallpaper (monolith.greeter.background), darkened, appearing with the login
        Image {
            id: wall
            anchors.fill: parent
            source: win.cfg.background ? "file://" + win.cfg.background : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? win.phase : 0
        }
        Rectangle { anchors.fill: parent; color: "black"; opacity: wall.opacity * 0.6 }

        // ── the mark: static image, or the sweep frames while it plays ──
        Image {
            id: mark
            readonly property int frames: win.cfg.sweepFrames || 0
            property int frame: -1
            width: Math.round(win.markH * 0.8); height: Math.round(win.markH)
            x: Math.round((win.width - width) / 2); y: Math.round(win.markY)
            source: "file://" + win.cfg.branding + (frame >= 0 ? "/sweep-" + frame + ".png" : "/logo-512.png")
            sourceSize.height: 512
            smooth: true; mipmap: true; cache: true
            Timer {
                id: sweep
                interval: 18; repeat: true
                function play() { if (mark.frames > 0) { mark.frame = 0; start() } }
                onTriggered: { mark.frame = mark.frame + 1; if (mark.frame >= mark.frames) { stop(); mark.frame = -1 } }
            }
            // an idle sweep now and then, like the boot splash
            Timer { interval: 9000; repeat: true; running: Theme.animations && win.phase === 1 && !win.greeter.leaving; onTriggered: sweep.play() }
        }
        Image {
            id: wordmark
            height: Math.round(win.markH * 0.11)
            width: Math.round(height * 10)          // the wordmark SVG is 640 x 64
            x: Math.round((win.width - width) / 2)
            y: Math.round(mark.y + mark.height + win.markH * 0.16)
            source: "file://" + win.cfg.branding + "/wordmark-128.png"
            sourceSize.height: 128
            smooth: true; mipmap: true
        }
        // Plymouth's progress line, full: fades out as the mark rises
        Rectangle {
            readonly property real w: win.screenH * 0.20 * 0.8 * 2.2
            width: Math.round(w * (1 - win.phase * 0.6)); height: 2
            x: Math.round((win.width - width) / 2)
            y: Math.round(wordmark.y + wordmark.height + win.markH * 0.16)
            color: "white"
            opacity: 0.9 * Math.max(0, 1 - win.phase * 2.5)
        }

        // ── clock ──
        Column {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(win.screenH * 0.27 + (1 - win.ui) * 24)
            opacity: win.ui
            spacing: 2
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.now, win.cfg.clock24 === false ? "h:mm AP" : "HH:mm")
                color: Theme.white
                font.family: Theme.font; font.pixelSize: Math.round(win.screenH * 0.07); font.weight: Font.Light
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.now.toLocaleDateString(Qt.locale(win.greeter.en ? "en_US" : "pt_BR"), "dddd, d MMMM")
                color: Theme.grayMid
                font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: true
            }
        }

        // ── login ──
        Column {
            id: card
            width: 340
            property real dx: 0
            x: Math.round((win.width - width) / 2 + dx)
            y: Math.round(win.screenH * 0.47 + (1 - win.ui) * 32)
            opacity: win.ui * (win.greeter.leaving ? 0 : 1)
            Behavior on opacity { NumberAnimation { duration: Theme.dur(250) } }
            spacing: 14
            enabled: !win.greeter.leaving

            Avatar {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76; height: 76
                source: win.greeter.user.name && !win.greeter.customUser ? "/var/lib/AccountsService/icons/" + win.greeter.user.name : ""
                initial: (win.greeter.user.description || win.greeter.user.name || "?").charAt(0).toUpperCase()
            }

            // user: known users cycle with the arrows (or Up / Down); "other user" types a name
            Item {
                width: parent.width; height: 30
                Btn {
                    id: prevUser
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    compact: true; icon: Theme.glyph.left; text: ""
                    visible: win.greeter.users.length + (win.cfg.allowOtherUsers !== false ? 1 : 0) > 1
                    onActivated: win.greeter.cycleUser(-1)
                }
                Btn {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    compact: true; icon: Theme.glyph.right; text: ""
                    visible: prevUser.visible
                    onActivated: win.greeter.cycleUser(1)
                }
                Txt {
                    anchors.centerIn: parent
                    visible: !win.greeter.customUser
                    width: parent.width - 90; horizontalAlignment: Text.AlignHCenter
                    color: Theme.white; font.pixelSize: Theme.fontSize + 3
                    text: win.greeter.user.description || win.greeter.user.name
                }
                Rectangle {
                    anchors.centerIn: parent
                    visible: win.greeter.customUser
                    width: parent.width - 90; height: 30; radius: Theme.radius
                    color: "transparent"; border.width: 1; border.color: userInput.activeFocus ? Theme.grayMid : Theme.line
                    TextInput {
                        id: userInput
                        anchors.fill: parent; anchors.margins: 6
                        verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
                        color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
                        text: win.greeter.typedUser
                        onTextEdited: win.greeter.typedUser = text
                        onAccepted: field.forceActiveFocus()
                        Txt {
                            anchors.centerIn: parent; visible: !parent.text
                            color: Theme.grayDark; text: win.greeter.tr("usuário", "user name")
                        }
                    }
                }
            }

            // password / PAM answers
            Rectangle {
                id: box
                width: parent.width; height: 40; radius: Theme.radius
                color: Qt.rgba(1, 1, 1, field.activeFocus ? 0.06 : 0.03)
                border.width: 1
                border.color: win.greeter.messageError ? Theme.grayLight : field.activeFocus ? Theme.grayMid : Theme.line
                Behavior on border.color { ColorAnimation { duration: Theme.dur(120) } }
                Text {
                    id: lockIcon
                    anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    text: Theme.glyph.lock; color: Theme.grayMid; font.family: Theme.font; font.pixelSize: Theme.fontSize
                }
                TextInput {
                    id: field
                    anchors { left: lockIcon.right; leftMargin: 10; right: parent.right; rightMargin: 12; top: parent.top; bottom: parent.bottom }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: win.greeter.awaiting && win.greeter.promptEcho ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize + 1; font.bold: true
                    clip: true
                    enabled: !win.greeter.busy || win.greeter.awaiting
                    onAccepted: { const t = text; text = ""; win.greeter.submit(t) }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) { text = ""; win.greeter.reset(); win.greeter.show("", false); event.accepted = true }
                        else if (event.key === Qt.Key_Up) { win.greeter.cycleUser(-1); event.accepted = true }
                        else if (event.key === Qt.Key_Down) { win.greeter.cycleUser(1); event.accepted = true }
                        else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Left) { win.greeter.cycleSession(-1); event.accepted = true }
                        else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Right) { win.greeter.cycleSession(1); event.accepted = true }
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !parent.text
                        width: parent.width
                        color: Theme.grayDark; font.bold: false
                        text: win.greeter.awaiting ? win.greeter.prompt : win.greeter.busy ? "" : win.greeter.tr("senha", "password")
                    }
                }
            }

            // messages: PAM info / errors, caps lock
            Txt {
                width: parent.width; height: implicitHeight
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; elide: Text.ElideNone
                font.pixelSize: Theme.small; font.bold: win.greeter.messageError
                color: win.greeter.messageError ? Theme.white : Theme.grayMid
                text: (win.greeter.message || "") + (win.greeter.capsLock ? (win.greeter.message ? "  ·  " : "") + Theme.glyph.caps + "  Caps Lock" : "")
                opacity: text ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur(150) } }
            }

            // session
            Item {
                width: parent.width; height: 26
                Btn { anchors.left: parent.left; compact: true; icon: Theme.glyph.left; text: ""; visible: win.greeter.sessions.length > 1; onActivated: win.greeter.cycleSession(-1) }
                Btn { anchors.right: parent.right; compact: true; icon: Theme.glyph.right; text: ""; visible: win.greeter.sessions.length > 1; onActivated: win.greeter.cycleSession(1) }
                Txt {
                    anchors.centerIn: parent
                    width: parent.width - 90; horizontalAlignment: Text.AlignHCenter
                    color: Theme.grayLight; font.pixelSize: Theme.small + 1
                    text: Theme.glyph.session + "   " + (win.greeter.session ? win.greeter.session.name : "…")
                }
            }
        }
        SequentialAnimation {
            id: shakeAnim
            loops: 1
            NumberAnimation { target: card; property: "dx"; to: -10; duration: Theme.dur(45) }
            NumberAnimation { target: card; property: "dx"; to: 9; duration: Theme.dur(70) }
            NumberAnimation { target: card; property: "dx"; to: -6; duration: Theme.dur(60) }
            NumberAnimation { target: card; property: "dx"; to: 3; duration: Theme.dur(50) }
            NumberAnimation { target: card; property: "dx"; to: 0; duration: Theme.dur(40) }
        }

        // ── footer: host / keyboard on the left, power on the right ──
        Txt {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 24; bottomMargin: 20 }
            opacity: win.ui * (win.greeter.leaving ? 0 : 1)
            color: Theme.grayMid; font.pixelSize: Theme.small
            text: Theme.glyph.host + "  " + win.hostname + (win.cfg.keyboard ? "     " + Theme.glyph.keyboard + "  " + win.cfg.keyboard : "")
                  + (win.cfg.version ? "     MONOLITH " + win.cfg.version : "")
        }
        Row {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 24; bottomMargin: 16 }
            spacing: 8
            opacity: win.ui * (win.greeter.leaving ? 0 : 1)
            enabled: !win.greeter.leaving
            Btn { compact: true; icon: Theme.glyph.sleep; text: win.greeter.tr("Suspender", "Suspend"); onActivated: Quickshell.execDetached(["systemctl", "suspend"]) }
            Btn { compact: true; icon: Theme.glyph.reboot; text: win.greeter.tr("Reiniciar", "Restart"); confirm: true; onActivated: Quickshell.execDetached(["systemctl", "reboot"]) }
            Btn { compact: true; icon: Theme.glyph.power; text: win.greeter.tr("Desligar", "Power off"); confirm: true; onActivated: Quickshell.execDetached(["systemctl", "poweroff"]) }
        }

        // ── leaving: fade to black, then greetd starts the session ──
        Rectangle {
            id: curtain
            anchors.fill: parent
            color: "black"
            opacity: 0
        }
        SequentialAnimation {
            id: fadeOut
            PauseAnimation { duration: 300 }
            NumberAnimation { target: curtain; property: "opacity"; to: 1; duration: 380; easing.type: Easing.InQuad }
            ScriptAction { script: if (win.leaveDone) win.leaveDone() }
        }
    }
}
