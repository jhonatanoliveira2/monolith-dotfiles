local mainMod = "SUPER"
local programs = _G.programs
local menu = "~/.config/hypr/rofi/launcher.sh"
local home = os.getenv("HOME")

hl.bind(mainMod .. " + Delete", hl.dsp.exec_cmd(
    "bash -c 'dir=\"$HOME/Pictures\"; mkdir -p \"$dir\"; " ..
    "file=\"$dir/$(date +%Y-%m-%d_%H-%M-%S).png\"; " ..
    "if grim -o DP-1 \"$file\" && wl-copy < \"$file\"; then " ..
    "notify-send -a Screenshot \"Captura de tela\" \"Tela inteira salva e copiada\"; " ..
    "qs ipc call screenshot notify \"$file\"; " ..
    "else notify-send -u critical \"Erro na captura\" \"Não foi possível capturar a tela\"; fi'"
))

-- Screenshot area
hl.bind(mainMod .. " + SHIFT + Delete", hl.dsp.exec_cmd(
    "bash -c 'dir=\"$HOME/Pictures\"; mkdir -p \"$dir\"; " ..
    "geometry=$(slurp) || exit 0; " ..
    "file=\"$dir/$(date +%Y-%m-%d_%H-%M-%S).png\"; " ..
    "if grim -g \"$geometry\" \"$file\" && wl-copy < \"$file\"; then " ..
    "notify-send -a Screenshot \"Captura de tela\" \"Área selecionada salva e copiada\"; " ..
    "qs ipc call screenshot notify \"$file\"; " ..
    "else notify-send -u critical \"Erro na captura\" \"Não foi possível capturar a área\"; fi'"
))

-- GPU Screen Recorder
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(
    "bash -c 'PIDFILE=/tmp/osu-gsr.pid; " ..
    "if [ -f \"$PIDFILE\" ] && kill -0 \"$(cat \"$PIDFILE\")\" 2>/dev/null; then " ..
        "pid=$(cat \"$PIDFILE\"); " ..
        "kill -INT \"$pid\"; " ..
        "rm -f \"$PIDFILE\"; " ..
        "notify-send -a GPU-Screen-Recorder \"Gravação\" \"Encerrando gravação...\"; " ..
    "else " ..
        "mkdir -p \"$HOME/Videos\"; " ..
        "file=\"$HOME/Videos/$(date +%Y-%m-%d_%H-%M-%S).mp4\"; " ..
        "cursor=$(hyprctl -j cursorpos); " ..
        "monitor=$(hyprctl -j monitors | jq -r --argjson c \"$cursor\" " ..
            "'''.[] | select($c.x >= .x and $c.x < (.x + .width) and $c.y >= .y and $c.y < (.y + .height)) | .name'''); " ..
        "if [ -z \"$monitor\" ]; then " ..
            "notify-send -u critical \"Gravação\" \"Não foi possível identificar o monitor\"; exit 1; " ..
        "fi; " ..
        "gpu-screen-recorder -w \"$monitor\" -f 60 -k hevc -q ultra -bm qp -a default_output -o \"$file\" & " ..
        "pid=$!; echo \"$pid\" > \"$PIDFILE\"; " ..
        "sleep 1; " ..
        "if kill -0 \"$pid\" 2>/dev/null; then " ..
            "notify-send -a GPU-Screen-Recorder \"Gravação iniciada\" \"$monitor · HEVC · 60 FPS · Qualidade ultra\"; " ..
        "else " ..
            "rm -f \"$PIDFILE\"; notify-send -u critical \"Gravação\" \"Falha ao iniciar o gravador\"; " ..
        "fi; " ..
    "fi'"
))



hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("swaync-client -t -sw"))

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(programs.terminal))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(programs.fileManager))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("zen-browser"))

hl.bind(mainMod .. " + Space", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))

    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        local mon = hl.get_active_monitor()
        if mon ~= nil then
            local target_w = math.floor(mon.width * 0.7) 
            local target_h = math.floor(mon.height * 0.7)

            -- absolute resize (relative = false), not a delta
            hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h, relative = false }))

            local mon_x = mon.x or 0
            local mon_y = mon.y or 0
            local target_x = mon_x + math.floor((mon.width - target_w) / 2)
            local target_y = mon_y + math.floor((mon.height - target_h) / 2)

            -- absolute move to the centered position
            hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y, relative = false }))
        end
    end
end)
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || " .. menu))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("hyprlock"))

-- Special workspace.
hl.bind(mainMod .. " + W", hl.dsp.workspace.toggle_special("magic"))
hl.bind(
    mainMod .. " + SHIFT + W",
    hl.dsp.window.move({ workspace = "special" })
)
hl.bind(
    mainMod .. " + ALT + W",
    hl.dsp.window.move({ workspace = "m+" })
)

hl.bind(mainMod .. " + Q", hl.dsp.window.close())



hl.bind(mainMod .. " + S", hl.dsp.window.float({ action = "toggle" }))
hl.bind(
    mainMod .. " + F",
    hl.dsp.window.fullscreen({
        mode = "fullscreen",
        action = "toggle",
    })
)

hl.bind(
    mainMod .. " + Z",
    hl.dsp.exec_cmd("~/.local/bin/wallpaper-random &")
)

hl.bind(
    mainMod .. " + D",
    hl.dsp.exec_cmd("matuwall --background none -b awww -p center")
)

hl.bind(
    mainMod .. " + SHIFT + Z",
    hl.dsp.exec_cmd("~/.local/bin/wallpaper-menu")
)

hl.bind(
    mainMod .. " + X",
    hl.dsp.exec_cmd(
        "command -v hyprshutdown >/dev/null 2>&1 && " ..
        "hyprshutdown || hyprctl dispatch exit"
    )
)

-- Focus.
for direction, key in pairs({
    left = "left",
    right = "right",
    up = "up",
    down = "down",
}) do
    hl.bind(
        mainMod .. " + " .. key,
        hl.dsp.focus({ direction = direction })
    )
end

-- Resize.
local resizeBindings = {
    { key = "right", x = 40, y = 0 },
    { key = "left", x = -40, y = 0 },
    { key = "up", x = 0, y = -40 },
    { key = "down", x = 0, y = 40 },
}

for _, binding in ipairs(resizeBindings) do
    hl.bind(
        mainMod .. " + ALT + " .. binding.key,
        hl.dsp.window.resize({ x = binding.x, y = binding.y }),
        { repeating = true }
    )
end

-- Workspaces 1–10.
for i = 1, 10 do
    local key = i % 10

    hl.bind(
        mainMod .. " + " .. key,
        hl.dsp.focus({ workspace = i })
    )

    hl.bind(
        mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = i })
    )
end

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 1.5 then
        hl.config({ cursor = { zoom_factor = 1.5 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + mouse_down", function() zoomfunction(-0.5) end, { repeating = true })
hl.bind(mainMod .. " + mouse_up", function() zoomfunction(0.5) end, { repeating = true })

--# Zoom with keypad
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })

hl.bind(
    mainMod .. " + mouse:272",
    hl.dsp.window.drag(),
    { mouse = true }
)

hl.bind(
    mainMod .. " + mouse:273",
    hl.dsp.window.resize(),
    { mouse = true }
)
