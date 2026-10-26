-- Ponto de entrada da configuração.
local configDir = os.getenv("HOME") .. "/.config/hypr"

local modules = {
    "core.lua",
    "monitors.lua",
    "programs.lua",
    "environment.lua",
    "input.lua",
    "layout.lua",
    "animations.lua",
    "window-rules.lua",
    "autostart.lua",
    "keybindings.lua",
    "media-keys.lua",
}

for _, module in ipairs(modules) do
    dofile(configDir .. "/modules/" .. module)
end

-- HyprMod managed settings
require("hyprland-gui")

-- Choices made in the MONOLITH Settings app (Display / Configs), written by Quickshell into generated/.
-- Loaded last so they win; delete a file to go back to the modules above.
for _, file in ipairs({ "generated/monitors.lua", "generated/settings.lua" }) do
    local path = configDir .. "/" .. file
    local fh = io.open(path, "r")
    if fh then
        fh:close()
        local ok, err = pcall(dofile, path)
        if not ok then
            hl.notification.create({ text = "MONOLITH: " .. file .. ": " .. tostring(err), timeout = 8000 })
        end
    end
end
