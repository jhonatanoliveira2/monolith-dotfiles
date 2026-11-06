import QtQuick
import QtQuick.Effects
import Quickshell
import "core"
import "components"

// The greeter's only window (cage shows it full screen), black, minimal.
//
// Opening: the first frame is Plymouth's last one (branding/plymouth/monolith.script: mark 20 % of the screen
// high, top at 50 % - 0.62 x mark, wordmark 11 % of the mark and 16 % below it, the progress line 16 % below
// that, the mark's bloom at half strength). Then the mark rises and turns pure white, the line fades, the night
// sky (Starfield) and the login appear. Login: clock, user, a password line that glows when focused, the
// session and three small power icons. Success: the bloom flares, everything fades to black, greetd starts the
// session.
FloatingWindow {
    id: win
    required property var greeter
    property string hostname: ""
    readonly property var cfg: greeter.cfg
    readonly property string art: "file://" + (cfg.branding || "")
    title: "MONOLITH greeter"
    color: "black"

    function focusField() { field.forceActiveFocus() }
    function shake() { shakeAnim.restart() }
    function leave(done) {
        leaveDone = done
        if (!Theme.animations) { done(); return }
        leaving.start()
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
        duration: Theme.dur(1300); easing.type: Easing.InOutCubic
    }
    function mix(a, b) { return a + (b - a) * phase }
    readonly property real screenH: height
    readonly property real markH: mix(screenH * 0.20, screenH * 0.12)
    readonly property real markY: mix(screenH / 2 - screenH * 0.20 * 0.62, screenH * 0.13)
    readonly property real ui: Math.max(0, Math.min(1, (phase - 0.5) / 0.5))
    // the bloom breathes; it flares when the session starts
    property real breath: 0.5
    SequentialAnimation on breath {
        running: Theme.animations && !win.greeter.leaving
        loops: Animation.Infinite
        NumberAnimation { to: 0.78; duration: 2600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.45; duration: 2600; easing.type: Easing.InOutSine }
    }
    property real flare: 0
    onFlareChanged: if (flare > 0.05) sweep.play()   // the session starts: one last sweep with the flare

    Item {
        id: stage
        anchors.fill: parent

        // optional wallpaper (monolith.greeter.background), very dark
        Image {
            id: wall
            anchors.fill: parent
            source: win.cfg.background ? "file://" + win.cfg.background : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? win.phase * 0.35 : 0
        }

        Starfield {
            anchors.fill: parent
            branding: win.cfg.branding || ""
            opacity: win.phase * (1 - win.flare)
            running: Theme.animations && !win.greeter.leaving && win.visible
        }

        // ── mark: Plymouth's logo (grey, horizon) cross-fading into the white snowflake, with its bloom ──
        Item {
            id: mark
            width: Math.round(win.markH * 0.8); height: Math.round(win.markH)
            x: Math.round((win.width - width) / 2); y: Math.round(win.markY)
            scale: 1 + win.flare * 0.06
            Image {
                // bloom sprite: 1.5x canvas centred on the mark
                x: -parent.width * 0.25; y: -parent.height * 0.25
                width: parent.width * 1.5; height: parent.height * 1.5
                source: win.art + "/mark-glow-512.png"
                sourceSize.height: 768
                smooth: true
                opacity: win.phase === 0 ? 0.5 : Math.min(1, win.breath + win.flare)
            }
            Image {
                anchors.fill: parent
                source: win.art + "/logo-512.png"
                sourceSize.height: 512
                smooth: true; mipmap: true
                opacity: 1 - win.phase
            }
            Image {
                anchors.fill: parent
                source: win.art + "/mark-white-512.png"
                sourceSize.height: 512
                smooth: true; mipmap: true
                // rests a touch below white, so the light sweep reads as light passing over it
                opacity: win.phase * 0.86
            }
            // light sweep: a lit band clipped to the snowflake, with its bloom (1.5x canvas, frames from build.sh)
            Image {
                id: sweep
                property int frame: -1
                x: -parent.width * 0.25; y: -parent.height * 0.25
                width: parent.width * 1.5; height: parent.height * 1.5
                visible: frame >= 0
                source: frame >= 0 ? win.art + "/mark-sweep-" + frame + ".png" : ""
                sourceSize.height: 768
                smooth: true
                cache: true
                Timer {
                    id: sweepTick
                    interval: 22; repeat: true
                    onTriggered: { if (sweep.frame + 1 >= 36) { stop(); sweep.frame = -1 } else sweep.frame = sweep.frame + 1 }
                }
                function play() { if (!sweepTick.running) { frame = 0; sweepTick.start() } }
                Timer {
                    // first sweep right after the opening, then every ~6 s
                    interval: 6000; repeat: true; triggeredOnStart: false
                    running: Theme.animations && win.phase === 1 && !win.greeter.leaving
                    onRunningChanged: if (running) firstSweep.start()
                    onTriggered: sweep.play()
                }
                Timer { id: firstSweep; interval: 500; onTriggered: sweep.play() }
            }
        }
        Item {
            id: wordmark
            // Plymouth's size at first (continuity), larger in the login layout
            height: Math.round(win.markH * win.mix(0.11, 0.24))
            width: Math.round(height * 10)          // the wordmark SVG is 640 x 64
            x: Math.round((win.width - width) / 2)
            y: Math.round(mark.y + mark.height + win.markH * win.mix(0.16, 0.10))
            Image {
                x: -parent.width * 0.25; y: -parent.height * 0.25
                width: parent.width * 1.5; height: parent.height * 1.5
                source: win.art + "/wordmark-glow-128.png"
                smooth: true
                opacity: win.phase === 0 ? 0.35 : 0.35 + (win.breath - 0.45) * 0.6 + win.flare
            }
            Image {
                anchors.fill: parent
                source: win.art + "/wordmark-128.png"
                sourceSize.height: 128
                smooth: true; mipmap: true
            }
        }
        // Plymouth's progress line, full: fades out as the mark rises
        Rectangle {
            readonly property real w: win.screenH * 0.20 * 0.8 * 2.2
            width: Math.round(w * (1 - win.phase * 0.6)); height: 2
            x: Math.round((win.width - width) / 2)
            y: Math.round(wordmark.y + wordmark.height + win.markH * 0.16)
            color: "white"
            opacity: 0.95 * Math.max(0, 1 - win.phase * 2.5)
        }

        // ── clock ──
        Item {
            id: clock
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
            readonly property string time: Qt.formatTime(now, win.cfg.clock24 === false ? "h:mm AP" : "HH:mm")
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(win.screenH * 0.36 + (1 - win.ui) * 20)
            width: timeText.implicitWidth; height: timeText.implicitHeight + dateText.implicitHeight + 6
            opacity: win.ui * (1 - win.flare)
            Text {
                id: timeGlow
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.time
                color: "white"
                font: timeText.font
                visible: false
            }
            MultiEffect {
                source: timeGlow
                anchors.fill: timeGlow
                blurEnabled: true; blur: 1.0; blurMax: 40
                opacity: 0.55
            }
            Text {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.time
                color: "white"
                font.family: Theme.font; font.pixelSize: Math.round(win.screenH * 0.065); font.weight: Font.Light
            }
            Text {
                id: dateText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: timeText.bottom; anchors.topMargin: 6
                text: clock.now.toLocaleDateString(Qt.locale(win.greeter.en ? "en_US" : "pt_BR"), "dddd, d MMMM").toUpperCase()
                color: Theme.grayMid
                font.family: Theme.font; font.pixelSize: Theme.small; font.letterSpacing: 3
            }
        }

        // ── login ──
        Column {
            id: card
            width: 300
            property real dx: 0
            x: Math.round((win.width - width) / 2 + dx)
            y: Math.round(win.screenH * 0.58 + (1 - win.ui) * 28)
            opacity: win.ui * (1 - win.flare)
            enabled: !win.greeter.leaving
            spacing: 18

            // user: Up / Down or the chevrons (several users); "other user" types the name
            Item {
                width: parent.width; height: 26
                readonly property bool many: win.greeter.users.length + (win.cfg.allowOtherUsers !== false ? 1 : 0) > 1
                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    visible: parent.many
                    text: Theme.glyph.left
                    color: prevUser.containsMouse ? Theme.white : Theme.grayDark
                    font.family: Theme.font; font.pixelSize: Theme.fontSize
                    MouseArea { id: prevUser; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; onClicked: win.greeter.cycleUser(-1) }
                }
                Text {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    visible: parent.many
                    text: Theme.glyph.right
                    color: nextUser.containsMouse ? Theme.white : Theme.grayDark
                    font.family: Theme.font; font.pixelSize: Theme.fontSize
                    MouseArea { id: nextUser; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; onClicked: win.greeter.cycleUser(1) }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !win.greeter.customUser
                    width: parent.width - 60; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: String(win.greeter.user.description || win.greeter.user.name).toUpperCase()
                    color: Theme.white
                    font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; font.letterSpacing: 4
                }
                TextInput {
                    id: userInput
                    anchors.centerIn: parent
                    visible: win.greeter.customUser
                    width: parent.width - 60
                    horizontalAlignment: TextInput.AlignHCenter
                    color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true; font.letterSpacing: 2
                    text: win.greeter.typedUser
                    onTextEdited: win.greeter.typedUser = text
                    onAccepted: field.forceActiveFocus()
                    Text {
                        anchors.centerIn: parent; visible: !parent.text
                        text: win.greeter.tr("USUÁRIO", "USER"); color: Theme.grayDark
                        font.family: Theme.font; font.pixelSize: Theme.small; font.letterSpacing: 3
                    }
                }
            }

            // password: a single line that lights up (with its glow) when focused
            Item {
                id: box
                width: parent.width; height: 34
                TextInput {
                    id: field
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: line.top; bottomMargin: 4 }
                    horizontalAlignment: TextInput.AlignHCenter; verticalAlignment: TextInput.AlignVCenter
                    echoMode: win.greeter.awaiting && win.greeter.promptEcho ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    color: Theme.white; font.family: Theme.font; font.pixelSize: Theme.fontSize + 3; font.letterSpacing: 4
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
                    Text {
                        anchors.centerIn: parent
                        visible: !parent.text
                        text: win.greeter.awaiting ? win.greeter.prompt : win.greeter.busy ? "…" : win.greeter.tr("senha", "password")
                        color: Theme.grayDark
                        font.family: Theme.font; font.pixelSize: Theme.small; font.letterSpacing: 3
                    }
                }
                Image {
                    anchors.horizontalCenter: line.horizontalCenter; anchors.verticalCenter: line.verticalCenter
                    width: line.width * 1.12; height: 26
                    source: win.art + "/line-glow.png"
                    opacity: field.activeFocus ? (win.greeter.messageError ? 0.9 : 0.55) : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.dur(220) } }
                }
                Rectangle {
                    id: line
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    width: field.activeFocus ? parent.width : parent.width * 0.6; height: 1
                    color: "white"
                    opacity: field.activeFocus ? 0.9 : 0.3
                    Behavior on width { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.dur(220) } }
                }
            }

            // PAM messages, caps lock
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                font.family: Theme.font; font.pixelSize: Theme.small; font.bold: win.greeter.messageError
                color: win.greeter.messageError ? Theme.white : Theme.grayMid
                text: (win.greeter.message || "") + (win.greeter.capsLock ? (win.greeter.message ? "  ·  " : "") + "CAPS LOCK" : "")
                opacity: text ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.dur(150) } }
            }
        }
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: card; property: "dx"; to: -10; duration: Theme.dur(45) }
            NumberAnimation { target: card; property: "dx"; to: 9; duration: Theme.dur(70) }
            NumberAnimation { target: card; property: "dx"; to: -6; duration: Theme.dur(60) }
            NumberAnimation { target: card; property: "dx"; to: 3; duration: Theme.dur(50) }
            NumberAnimation { target: card; property: "dx"; to: 0; duration: Theme.dur(40) }
        }

        // ── footer: session in the middle, host / keyboard left, power right ──
        Text {
            id: sessionText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 26
            opacity: win.ui * (1 - win.flare)
            text: (win.greeter.sessions.length > 1 ? Theme.glyph.left + "   " : "")
                  + String(win.greeter.session ? win.greeter.session.name : "…").toUpperCase()
                  + (win.greeter.sessions.length > 1 ? "   " + Theme.glyph.right : "")
            color: sessionMouse.containsMouse ? Theme.white : Theme.grayMid
            font.family: Theme.font; font.pixelSize: Theme.small; font.letterSpacing: 3
            MouseArea {
                id: sessionMouse
                anchors.fill: parent; anchors.margins: -10
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => win.greeter.cycleSession(mouse.button === Qt.RightButton || mouse.x < width / 2 ? -1 : 1)
            }
        }
        Text {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 28; bottomMargin: 26 }
            opacity: win.ui * (1 - win.flare)
            color: Theme.grayDark
            font.family: Theme.font; font.pixelSize: Theme.small; font.letterSpacing: 2
            text: win.hostname + (win.cfg.keyboard ? "   ·   " + win.cfg.keyboard : "")
        }
        Row {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 24; bottomMargin: 20 }
            spacing: 6
            opacity: win.ui * (1 - win.flare)
            enabled: !win.greeter.leaving
            Repeater {
                model: [
                    { glyph: Theme.glyph.sleep, cmd: ["systemctl", "suspend"], confirm: false, tip: win.greeter.tr("Suspender", "Suspend") },
                    { glyph: Theme.glyph.reboot, cmd: ["systemctl", "reboot"], confirm: true, tip: win.greeter.tr("Reiniciar", "Restart") },
                    { glyph: Theme.glyph.power, cmd: ["systemctl", "poweroff"], confirm: true, tip: win.greeter.tr("Desligar", "Power off") }
                ]
                delegate: Item {
                    id: pb
                    required property var modelData
                    property bool armed: false
                    width: 34; height: 34
                    Image {
                        anchors.centerIn: parent
                        width: 34; height: 34
                        source: win.art + "/star.png"
                        opacity: pm.containsMouse || pb.armed ? 0.25 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.dur(150) } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: pb.armed ? "?" : pb.modelData.glyph
                        color: pm.containsMouse || pb.armed ? Theme.white : Theme.grayMid
                        font.family: Theme.font; font.pixelSize: Theme.fontSize + 2; font.bold: pb.armed
                    }
                    Timer { id: disarm; interval: 2500; onTriggered: pb.armed = false }
                    MouseArea {
                        id: pm
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (pb.modelData.confirm && !pb.armed) { pb.armed = true; disarm.restart(); return }
                            pb.armed = false
                            Quickshell.execDetached(pb.modelData.cmd)
                        }
                    }
                    Text {
                        anchors.bottom: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                        visible: pm.containsMouse
                        text: pb.armed ? win.greeter.tr("clique de novo", "click again") : pb.modelData.tip
                        color: Theme.grayMid
                        font.family: Theme.font; font.pixelSize: Theme.small - 1; font.letterSpacing: 1
                    }
                }
            }
        }

        // ── leaving: the bloom flares, then black; greetd starts the session ──
        Rectangle {
            id: curtain
            anchors.fill: parent
            color: "black"
            opacity: 0
        }
        SequentialAnimation {
            id: leaving
            NumberAnimation { target: win; property: "flare"; to: 1; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: curtain; property: "opacity"; to: 1; duration: 380; easing.type: Easing.InQuad }
            ScriptAction { script: if (win.leaveDone) win.leaveDone() }
        }
    }
}
