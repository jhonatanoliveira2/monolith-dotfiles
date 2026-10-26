pragma Singleton
import QtQuick
import Quickshell

// All user-facing text. Switch the language with Config.language ("pt" | "en"); add a language by adding a map.
Singleton {
    readonly property var pt: ({
        online: "Conectado", nointernet: "Sem internet", disconnected: "Desconectado", disconnect: "Desconectar",
        connect: "Conectar", connected: "Conectado", saved: "Salva", secured: "Protegida", open: "Aberta", password: "Senha",
        networks: "Redes", scanning: "Procurando redes...", rescan: "Reescanear", advanced: "Avançado", network: "Rede",
        output: "Saída", input: "Entrada", apps: "Aplicativos", mixer: "Mixer de áudio",
        devices: "Dispositivos", paired: "Pareado", new: "Novo", scanDevices: "Procurar", stopScan: "Parar", manager: "Gerenciador",
        charging: "Carregando", discharging: "Na bateria", profile: "Perfil de energia", saver: "Economia", balanced: "Equilibrado",
        performance: "Desempenho", brightness: "Brilho",
        notifications: "Notificações", noNotifications: "Sem notificações", clearAll: "Limpar tudo", dnd: "Não perturbe",
        quick: "Rápido", keepAwake: "Manter acordado", darkMode: "Modo escuro",
        animations: "Animações", blur: "Desfoque", shadows: "Sombras", gapsIn: "Espaço interno", gapsOut: "Espaço externo",
        border: "Borda", rounding: "Arredondamento",
        desktop: "Desktop", wallpaper: "Wallpaper", gtkTheme: "Tema GTK", reloadHypr: "Recarregar Hyprland", reloadShell: "Recarregar shell",
        session: "Sessão", lock: "Bloquear", suspend: "Suspender", logout: "Sair", reboot: "Reiniciar", poweroff: "Desligar",
        screenshot: "Captura de tela", screenshotBody: "Imagem copiada para a área de transferência",
        noPlayer: "Nada tocando", searchTracks: "Buscar faixas…", results: "Resultados", recent: "Tocadas recentemente",
        searchHint: "Enter busca no serviço de música do player", history: "Histórico", media: "Mídia",
        connecting: "Conectando…", disconnecting: "Desconectando…", pairing: "Pareando…",
        netGone: "Rede fora de alcance", netTimeout: "Tempo esgotado ao conectar", netFail: "Falha ao conectar",
        wifiHwOff: "Wi-Fi bloqueado pelo hardware (botão/rfkill)", btBlocked: "Bluetooth bloqueado (rfkill) — ative para desbloquear",
        btPairFail: "Falha ao parear", monOverlap: "Monitores sobrepostos: ajuste as posições", btConnFail: "Falha ao conectar",
        accept: "Aceitar", reject: "Recusar", cancel: "Cancelar",
        bt_confirm: "Confirme se este código é o mesmo exibido no dispositivo", bt_passkey: "Digite a chave numérica exibida no dispositivo",
        bt_pin: "Digite o PIN do dispositivo (geralmente 0000 ou 1234)", bt_display: "Digite este código no dispositivo e pressione Enter",
        bt_authorize: "O dispositivo quer parear com este computador", bt_service: "O dispositivo pede acesso a um serviço",
        btPairHint: "confirme o pedido no dispositivo; se persistir, remova este computador da lista dele e tente de novo",
        btNoAgent: "agente de pareamento indisponível (bluetoothctl/script)",
        ytmOff: "API do YouTube Music inacessível", ytmAuth: "API do YouTube Music recusou o acesso", ytmHttp: "Erro da API do YouTube Music",
        ytmHint: "Aleatório/repetir no YouTube Music exigem o plugin \"API Server\" (autorização: nenhuma, ou token em Configurações > Barra)"
    })
    readonly property var en: ({
        online: "Connected", nointernet: "No internet", disconnected: "Disconnected", disconnect: "Disconnect",
        connect: "Connect", connected: "Connected", saved: "Saved", secured: "Secured", open: "Open", password: "Password",
        networks: "Networks", scanning: "Scanning...", rescan: "Rescan", advanced: "Advanced", network: "Network",
        output: "Output", input: "Input", apps: "Applications", mixer: "Audio mixer",
        devices: "Devices", paired: "Paired", new: "New", scanDevices: "Scan", stopScan: "Stop", manager: "Manager",
        charging: "Charging", discharging: "On battery", profile: "Power profile", saver: "Power saver", balanced: "Balanced",
        performance: "Performance", brightness: "Brightness",
        notifications: "Notifications", noNotifications: "No notifications", clearAll: "Clear all", dnd: "Do not disturb",
        quick: "Quick", keepAwake: "Keep awake", darkMode: "Dark mode",
        animations: "Animations", blur: "Blur", shadows: "Shadows", gapsIn: "Inner gaps", gapsOut: "Outer gaps",
        border: "Border", rounding: "Rounding",
        desktop: "Desktop", wallpaper: "Wallpaper", gtkTheme: "GTK theme", reloadHypr: "Reload Hyprland", reloadShell: "Reload shell",
        session: "Session", lock: "Lock", suspend: "Suspend", logout: "Log out", reboot: "Reboot", poweroff: "Power off",
        screenshot: "Screenshot", screenshotBody: "Image copied to the clipboard",
        noPlayer: "Nothing playing", searchTracks: "Search tracks…", results: "Results", recent: "Recently played",
        searchHint: "Enter searches the player's music service", history: "History", media: "Media",
        connecting: "Connecting…", disconnecting: "Disconnecting…", pairing: "Pairing…",
        netGone: "Network out of range", netTimeout: "Timed out while connecting", netFail: "Connection failed",
        wifiHwOff: "Wi-Fi blocked by hardware (switch/rfkill)", btBlocked: "Bluetooth blocked (rfkill) — switch on to unblock",
        btPairFail: "Pairing failed", monOverlap: "Monitors overlap: adjust the positions", btConnFail: "Connection failed",
        accept: "Accept", reject: "Reject", cancel: "Cancel",
        bt_confirm: "Confirm this code matches the one shown on the device", bt_passkey: "Type the passkey shown on the device",
        bt_pin: "Type the device PIN (usually 0000 or 1234)", bt_display: "Type this code on the device and press Enter",
        bt_authorize: "The device wants to pair with this computer", bt_service: "The device asks for access to a service",
        btPairHint: "accept the request on the device; if it persists, remove this computer from its list and try again",
        btNoAgent: "pairing agent unavailable (bluetoothctl/script)",
        ytmOff: "YouTube Music API unreachable", ytmAuth: "YouTube Music API denied access", ytmHttp: "YouTube Music API error",
        ytmHint: "Shuffle/repeat in YouTube Music need its \"API Server\" plugin (authorization: none, or a token in Settings > Bar)"
    })

    function t(key) {
        const m = Config.language === "en" ? en : pt
        return m[key] !== undefined ? m[key] : (en[key] !== undefined ? en[key] : key)
    }
    function weekdays() {
        return Config.language === "en" ? ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"] : ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
    }
}
