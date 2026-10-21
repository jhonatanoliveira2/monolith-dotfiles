
local mainMod = "SUPER"
local programs = _G.programs
local menu = "~/.config/hypr/rofi/launcher.sh"

-- Helpers
local function exec(command)
    hl.bind(mainMod .. " + " .. command.key, hl.dsp.exec_cmd(command.cmd))
end

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
        capture = [[grim -o DP-1]]
        message = "Full screen saved and copied"
    end

    local command = string.format(
        [[bash -c 'dir="$HOME/Pictures"; mkdir -p "$dir"; file="$dir/$(date +%%Y-%%m-%%d_%%H-%%M-%%S).png"; if %s "$file" && wl-copy < "$file"; then notify-send -a Screenshot "Screenshot" "%s"; qs ipc call screenshot notify "$file"; else notify-send -u critical "Screenshot error" "Unable to capture screenshot"; fi']],
        capture,
        message
    )

    hl.dispatch(hl.dsp.exec_cmd(command))
end

-- Applications
exec({ key = "Return", cmd = programs.terminal })
exec({ key = "X", cmd = programs.fileManager })
exec({ key = "C", cmd = programs.ide })
exec({ key = "TAB", cmd = programs.browser })
exec({ key = "Z", cmd = programs.lockScreen })

-- Launcher
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(
    "pgrep -x rofi >/dev/null && pkill -x rofi || " .. menu
))

-- Screenshots
hl.bind(mainMod .. " + Delete", function()
    screenshot(false)
end)

hl.bind(mainMod .. " + SHIFT + Delete", function()
    screenshot(true)
end)

-- Screen recording
exec({
    key = "R",
    cmd = "~/.config/hypr/scripts/toggle-gsr.sh",
})

-- Wallpaper menu
exec({
    key = "D",
    cmd = "~/.local/bin/wallpaper-menu &",
})

-- Session exit
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd(
    "command -v hyprshutdown >/dev/null 2>&1 && " ..
    "hyprshutdown || hyprctl dispatch exit"
))

-- Window management
hl.bind(mainMod .. " + Space", function()
    toggleFloat(true)
end)

hl.bind(mainMod .. " + S", function()
    toggleFloat(false)
end)

hl.bind(mainMod .. " + Q", hl.dsp.window.close())

hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({
    mode = "fullscreen",
    action = "toggle",
}))

-- Move windows with Shift + arrows
local directions = {
    { key = "LEFT", direction = "l" },
    { key = "RIGHT", direction = "r" },
    { key = "UP", direction = "u" },
    { key = "DOWN", direction = "d" },
}

for _, item in ipairs(directions) do
    hl.bind(
        mainMod .. " + SHIFT + " .. item.key,
        hl.dsp.window.move({
            direction = item.direction,
            group_aware = true,
            window = "activewindow",
        })
    )
end

-- Focus
for _, item in ipairs({
    { key = "LEFT", direction = "left" },
    { key = "RIGHT", direction = "right" },
    { key = "UP", direction = "up" },
    { key = "DOWN", direction = "down" },
}) do
    hl.bind(
        mainMod .. " + " .. item.key,
        hl.dsp.focus({ direction = item.direction })
    )
end

-- Resize with Alt + arrows
local resizeBindings = {
    { key = "RIGHT", x = 40, y = 0 },
    { key = "LEFT", x = -40, y = 0 },
    { key = "UP", x = 0, y = -40 },
    { key = "DOWN", x = 0, y = 40 },
}

for _, item in ipairs(resizeBindings) do
    hl.bind(
        mainMod .. " + ALT + " .. item.key,
        hl.dsp.window.resize({ x = item.x, y = item.y }),
        { repeating = true }
    )
end

-- Special workspace
hl.bind(mainMod .. " + W", hl.dsp.workspace.toggle_special("magic"))

hl.bind(
    mainMod .. " + SHIFT + W",
    hl.dsp.window.move({ workspace = "special" })
)

hl.bind(
    mainMod .. " + ALT + W",
    hl.dsp.window.move({ workspace = "m+" })
)

-- Workspaces 1-10
for i = 1, 10 do
    local key = tostring(i % 10)

    hl.bind(
        mainMod .. " + " .. key,
        hl.dsp.focus({ workspace = i })
    )

    hl.bind(
        mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = i })
    )
end

-- Cursor zoom
local function zoom(value)
    local current = hl.get_config("cursor:zoom_factor")
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

hl.bind(mainMod .. " + mouse_down", function()
    zoom(-0.5)
end, { repeating = true })

hl.bind(mainMod .. " + mouse_up", function()
    zoom(0.5)
end, { repeating = true })

-- Keypad zoom
hl.bind(mainMod .. " + code:82", function()
    zoom(-0.3)
end, { repeating = true })

hl.bind(mainMod .. " + code:86", function()
    zoom(0.3)
end, { repeating = true })

-- Mouse window controls
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
