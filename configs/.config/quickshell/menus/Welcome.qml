import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../components"

// First-run welcome: the main features, their shortcuts and buttons to the Settings pages to set up first.
// Shown once (Settings.welcomeDone, kept in settings.json); reopen it from Settings > System or with
// `qs ipc call shell welcome`.
Scope {
    id: root
    function tr(pt, en) { return Config.language === "en" ? en : pt }
    function finish(page) {
        Settings.welcomeDone = true
        Popups.closeWelcome()
        if (page) Popups.openApp(page)
    }

    // decide only after settings.json was read, so a saved welcomeDone survives restarts and reloads
    function check() { if (Settings.loaded && !Settings.welcomeDone) Popups.openWelcome() }
    Component.onCompleted: check()
    Connections { target: Settings; function onLoadedOnce() { root.check() } }

    readonly property var features: [
        { g: 0xf0c9, k: "", t: ["Barra", "Bar"],
          d: ["Clique nos módulos para abrir áudio, rede, bluetooth, brilho, bateria e calendário; com um menu aberto, passar o mouse alterna entre eles.",
              "Click the modules to open audio, network, bluetooth, brightness, battery and calendar; with a menu open, hovering switches between them."] },
        { g: 0xf135, k: "Super + A", t: ["Lançador", "Launcher"],
          d: ["Busca apps; \"2+2\" calcula e \"> cmd\" executa um comando.", "Searches apps; \"2+2\" calculates and \"> cmd\" runs a command."] },
        { g: 0xf03e, k: "Super + D", t: ["Wallpapers", "Wallpapers"],
          d: ["Imagens e vídeos por monitor; o tema dinâmico tira as cores do wallpaper.", "Images and videos per monitor; the dynamic theme takes its colours from the wallpaper."] },
        { g: 0xf0f3, k: "Super + N", t: ["Notificações", "Notifications"],
          d: ["Central com histórico e Não perturbe.", "Center with history and Do not disturb."] },
        { g: 0xf0ea2, k: "Super + M", t: ["Mídia", "Media"],
          d: ["Player atual, faixas recentes e busca no serviço de música.", "Current player, recent tracks and search in the music service."] },
        { g: 0xf303, k: "Super + Esc", t: ["Menu rápido", "Quick menu"],
          d: ["Interruptores, atalhos e sessão (bloquear, suspender, desligar).", "Switches, shortcuts and session (lock, suspend, power off)."] },
        { g: 0xf013, k: "Super + ,", t: ["Configurações", "Settings"],
          d: ["Tudo em um lugar; Ctrl+F busca qualquer opção.", "Everything in one place; Ctrl+F searches any option."] },
        { g: 0xf030, k: "Super + Del", t: ["Captura e gravação", "Capture and recording"],
          d: ["Super+Del captura o monitor, com Shift uma área; Super+R grava a tela.", "Super+Del captures the monitor, with Shift an area; Super+R records the screen."] }
    ]
    readonly property var setup: [
        { g: 0xf26c, page: "display", t: ["Monitores", "Displays"] },
        { g: 0xf03d8, page: "themes", t: ["Temas", "Themes"] },
        { g: 0xf028, page: "audio", t: ["Áudio", "Audio"] },
        { g: 0xf1eb, page: "network", t: ["Rede", "Network"] },
        { g: 0xf013, page: "system", t: ["Configurações", "Settings"] }
    ]

    LazyLoader {
        active: Popups.welcomeOpen
        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Popups.welcomeScreen) || Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: Qt.rgba(0, 0, 0, 0.45)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "monolith-welcome"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Rectangle {
                id: card
                width: Math.min(780, parent.width - 80)
                height: Math.min(body.implicitHeight + 48, parent.height - 80)
                anchors.centerIn: parent
                radius: Theme.menuRadius
                color: Theme.panelBg
                border.width: 1
                border.color: Theme.line
                focus: true
                Keys.onEscapePressed: root.finish("")
                Keys.onReturnPressed: root.finish("")
                NumberAnimation on opacity { from: 0; to: 1; duration: Theme.dur(180) }
                NumberAnimation on scale { from: 0.97; to: 1; duration: Theme.dur(180); easing.type: Easing.OutCubic }
                MouseArea { anchors.fill: parent }   // keep clicks on the card from reaching the backdrop

                Flickable {
                    anchors { fill: parent; margins: 24 }
                    contentHeight: body.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: body
                        width: parent.width
                        spacing: 14

                        // header
                        Row {
                            spacing: 14
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Theme.glyph.arch
                                color: Theme.accent
                                font.family: Theme.font; font.pixelSize: 38
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Txt { text: root.tr("Bem-vindo ao MONOLITH", "Welcome to MONOLITH"); color: Theme.white; font.pixelSize: 20 }
                                Txt {
                                    text: root.tr("Um resumo do shell e por onde começar.", "A quick tour of the shell and where to start.")
                                    color: Theme.grayMid; font.bold: false
                                }
                            }
                        }

                        Section { width: parent.width; text: root.tr("Funções e atalhos", "Features and shortcuts") }
                        Grid {
                            id: grid
                            width: parent.width
                            columns: width > 560 ? 2 : 1
                            columnSpacing: 18
                            rowSpacing: 12
                            Repeater {
                                model: root.features
                                Item {
                                    required property var modelData
                                    width: (grid.width - grid.columnSpacing * (grid.columns - 1)) / grid.columns
                                    implicitHeight: Math.max(info.implicitHeight, 24)
                                    Text {
                                        id: icon
                                        width: 26
                                        text: Theme.g(modelData.g)
                                        color: Theme.accent
                                        font.family: Theme.font; font.pixelSize: 16
                                    }
                                    Column {
                                        id: info
                                        anchors { left: icon.right; right: parent.right; leftMargin: 4 }
                                        spacing: 3
                                        Item {
                                            width: parent.width
                                            implicitHeight: Math.max(title.implicitHeight, chip.height)
                                            Txt { id: title; anchors.verticalCenter: parent.verticalCenter; text: root.tr(modelData.t[0], modelData.t[1]); color: Theme.white }
                                            Rectangle {
                                                id: chip
                                                visible: modelData.k !== ""
                                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                                width: key.implicitWidth + 12
                                                height: 20
                                                radius: 4
                                                color: Theme.tint(0.06)
                                                border.width: 1
                                                border.color: Theme.line
                                                Txt { id: key; anchors.centerIn: parent; text: modelData.k; font.pixelSize: Theme.small }
                                            }
                                        }
                                        Txt {
                                            width: parent.width
                                            text: root.tr(modelData.d[0], modelData.d[1])
                                            color: Theme.grayMid
                                            font.pixelSize: Theme.small; font.bold: false
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideNone
                                        }
                                    }
                                }
                            }
                        }

                        Section { width: parent.width; text: root.tr("Primeiros passos", "First steps") }
                        Flow {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: root.setup
                                Btn {
                                    required property var modelData
                                    icon: Theme.g(modelData.g)
                                    text: root.tr(modelData.t[0], modelData.t[1])
                                    onActivated: root.finish(modelData.page)
                                }
                            }
                        }

                        // footer
                        Item {
                            width: parent.width
                            implicitHeight: start.implicitHeight + 6
                            Txt {
                                anchors { left: parent.left; right: start.left; rightMargin: 12; bottom: parent.bottom }
                                text: root.tr("Reabra em Configurações > Sistema ou com qs ipc call shell welcome",
                                              "Reopen it from Settings > System or with qs ipc call shell welcome")
                                color: Theme.grayDark
                                font.pixelSize: Theme.small; font.bold: false
                            }
                            Btn {
                                id: start
                                anchors { right: parent.right; bottom: parent.bottom }
                                active: true
                                icon: Theme.glyph.check
                                text: root.tr("Começar", "Get started")
                                onActivated: root.finish("")
                            }
                        }
                    }
                }
            }
        }
    }
}
