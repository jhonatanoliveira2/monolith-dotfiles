
local programs = _G.programs
local menu = "~/.config/hypr/rofi/launcher.sh"
local configDir = os.getenv("HOME") .. "/.config/hypr"

-- Combos by bind id: modules/bind-defaults.lua, overridden by generated/binds.lua (written by
-- Settings > Input in Quickshell; delete it to go back to the defaults). "" leaves a bind off.
local combos = dofile(configDir .. "/modules/bind-defaults.lua")
do
    local path = configDir .. "/generated/binds.lua"
    local fh = io.open(path, "r")
    if fh then
        fh:close()
        local ok, chosen = pcall(dofile, path)
        if ok and type(chosen) == "table" then
            for id, combo in pairs(chosen) do
                combos[id] = combo
            end
        else
            hl.notification.create({ text = "MONOLITH: generated/binds.lua: " .. tostring(chosen), timeout = 8000 })
        end
    end
end

local function bind(id, action, opts)
    local combo = combos[id]
    if combo == nil or combo == "" then
        return
    end
    if opts then
        hl.bind(combo, action, opts)
    else
        hl.bind(combo, action)
    end
end
_G.monolithBind = bind -- media-keys.lua

-- Helpers

local function toggleFloat(center)
    local window = hl.get_active_window()
    if window == nil then
        return
    end

    local shouldCenter = center and not window.floating

    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))

    if not shouldCenter then
        return
    end

    local monitor = hl.get_active_monitor()
    if monitor == nil then
        return
    end

    local width = math.floor(monitor.width * 0.7)
    local height = math.floor(monitor.height * 0.7)

    local x = (monitor.x or 0) + math.floor((monitor.width - width) / 2)
    local y = (monitor.y or 0) + math.floor((monitor.height - height) / 2)

    hl.dispatch(hl.dsp.window.resize({
        x = width,
        y = height,
        relative = false,
    }))

    hl.dispatch(hl.dsp.window.move({
        x = x,
        y = y,
        relative = false,
    }))
end

local function screenshot(area)
    local capture
    local message

    if area then
        capture = [[geometry=$(slurp) || exit 0; grim -g "$geometry"]]
        message = "Selected area saved and copied"
    else
        -- capture the monitor that has focus (not a hard-coded output)
        local monitor = hl.get_active_monitor()
        capture = "grim" .. (monitor and (" -o " .. monitor.name) or "")
        message = "Full screen saved and copied"
    end

    -- the shell shows a toast with a preview; notify-send only when Quickshell is not running
    local command = string.format(
        [[bash -c 'dir="$HOME/Pictures"; mkdir -p "$dir"; file="$dir/$(date +%%Y-%%m-%%d_%%H-%%M-%%S).png"; if %s "$file" && wl-copy < "$file"; then qs ipc call screenshot notify "$file" 2>/dev/null || notify-send -a Screenshot -i "$file" "Screenshot" "%s"; else notify-send -u critical "Screenshot error" "Unable to capture screenshot"; fi']],
        capture,
        message
    )

    hl.dispatch(hl.dsp.exec_cmd(command))
end

-- Applications
bind("app.terminal", hl.dsp.exec_cmd(programs.terminal))
bind("app.files", hl.dsp.exec_cmd(programs.fileManager))
bind("app.ide", hl.dsp.exec_cmd(programs.ide))
bind("app.browser", hl.dsp.exec_cmd(programs.browser))
bind("session.lock", hl.dsp.exec_cmd(programs.lockScreen))

-- Launcher and wallpaper picker: the shell's own (Quickshell overlays) while it runs, rofi otherwise.
local function shellRunning()
    return #hl.get_layers({ namespace = "qs-bar" }) > 0
end
local function shellOr(shortcut, fallback)
    return function()
        if shellRunning() then
            hl.dispatch(hl.dsp.global("quickshell:" .. shortcut))
        else
            hl.dispatch(hl.dsp.exec_cmd(fallback))
        end
    end
end

-- Launcher
bind("shell.launcher", shellOr("launcher", "pgrep -x rofi >/dev/null && pkill -x rofi || " .. menu))

-- Screenshots
bind("capture.screen", function()
    screenshot(false)
end)

bind("capture.area", function()
    screenshot(true)
end)

-- Screen recording
bind("capture.record", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-gsr.sh"))

-- Wallpaper picker
bind("shell.wallpaper", shellOr("wallpaper", "~/.local/bin/wallpaper-menu &"))

-- Session exit
local hasHyprshutdown = os.execute("command -v hyprshutdown >/dev/null 2>&1") == true

bind("session.exit", function()
    if hasHyprshutdown then
        hl.dispatch(hl.dsp.exec_cmd("hyprshutdown"))
    else
        hl.dispatch(hl.dsp.exit())
    end
end)

-- Window management
bind("win.float", function()
    toggleFloat(true)
end)

bind("win.floatKeep", function()
    toggleFloat(false)
end)

bind("win.close", hl.dsp.window.close())

bind("win.fullscreen", hl.dsp.window.fullscreen({
    mode = "fullscreen",
    action = "toggle",
}))

bind("win.pin", hl.dsp.window.pin())
bind("win.split", hl.dsp.layout("togglesplit"))
bind("win.group", hl.dsp.group.toggle())
bind("focus.last", hl.dsp.focus({ urgent_or_last = true }))

-- Previous / next occupied workspace
bind("ws.prev", hl.dsp.focus({ workspace = "e-1" }))
bind("ws.next", hl.dsp.focus({ workspace = "e+1" }))

-- Swap with the neighbour window
for _, item in ipairs({
    { id = "swap.left", direction = "l" },
    { id = "swap.right", direction = "r" },
    { id = "swap.up", direction = "u" },
    { id = "swap.down", direction = "d" },
}) do
    bind(item.id, hl.dsp.window.swap({ direction = item.direction }))
end

-- Shell (Quickshell global shortcuts, see shell.qml)
for _, item in ipairs({
    { id = "shell.notifications", name = "notifications" },
    { id = "shell.media", name = "media" },
    { id = "shell.settings", name = "settingsApp" },
    { id = "shell.session", name = "session" },
}) do
    bind(item.id, hl.dsp.global("quickshell:" .. item.name))
end

-- Move windows with Shift + arrows
local directions = {
    { id = "move.left", direction = "l" },
    { id = "move.right", direction = "r" },
    { id = "move.up", direction = "u" },
    { id = "move.down", direction = "d" },
}

for _, item in ipairs(directions) do
    bind(
        item.id,
        hl.dsp.window.move({
            direction = item.direction,
            group_aware = true,
            window = "activewindow",
        })
    )
end

-- Focus
for _, item in ipairs({
    { id = "focus.left", direction = "left" },
    { id = "focus.right", direction = "right" },
    { id = "focus.up", direction = "up" },
    { id = "focus.down", direction = "down" },
}) do
    bind(
        item.id,
        hl.dsp.focus({ direction = item.direction })
    )
end

-- Resize with Alt + arrows
local resizeBindings = {
    { id = "resize.right", x = 40, y = 0 },
    { id = "resize.left", x = -40, y = 0 },
    { id = "resize.up", x = 0, y = -40 },
    { id = "resize.down", x = 0, y = 40 },
}

for _, item in ipairs(resizeBindings) do
    bind(
        item.id,
        hl.dsp.window.resize({ x = item.x, y = item.y }),
        { repeating = true }
    )
end

-- Special workspace
bind("ws.special", hl.dsp.workspace.toggle_special("magic"))

bind(
    "ws.toSpecial",
    hl.dsp.window.move({ workspace = "special" })
)

bind(
    "ws.toMonitor",
    hl.dsp.window.move({ workspace = "m+" })
)

-- Workspaces 1-10
for i = 1, 10 do
    bind(
        "ws.go" .. i,
        hl.dsp.focus({ workspace = i })
    )

    bind(
        "ws.move" .. i,
        hl.dsp.window.move({ workspace = i })
    )
end

-- Cursor zoom
local function zoom(value)
    local current = hl.get_config("cursor.zoom_factor")
    if current == nil then
        return
    end

    local target = math.max(1.0, math.min(1.5, current + value))

    hl.config({
        cursor = {
            zoom_factor = target,
        },
    })
end

bind("zoom.out", function()
    zoom(-0.5)
end, { repeating = true })

bind("zoom.in", function()
    zoom(0.5)
end, { repeating = true })

-- Keypad zoom
bind("zoom.outPad", function()
    zoom(-0.3)
end, { repeating = true })

bind("zoom.inPad", function()
    zoom(0.3)
end, { repeating = true })

-- Mouse window controls
bind(
    "win.drag",
    hl.dsp.window.drag(),
    { mouse = true }
)

bind(
    "win.resizeMouse",
    hl.dsp.window.resize(),
    { mouse = true }
)
