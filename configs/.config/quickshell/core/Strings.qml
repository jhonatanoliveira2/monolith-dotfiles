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
        screenshot: "Captura de tela", screenshotBody: "Imagem copiada para a área de transferência"
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
        screenshot: "Screenshot", screenshotBody: "Image copied to the clipboard"
    })

    function t(key) {
        const m = Config.language === "en" ? en : pt
        return m[key] !== undefined ? m[key] : (en[key] !== undefined ? en[key] : key)
    }
    function weekdays() {
        return Config.language === "en" ? ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"] : ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
    }
}
