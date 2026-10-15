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
    "misc.lua",
}

for _, module in ipairs(modules) do
    dofile(configDir .. "/modules/" .. module)
end



-- HyprMod managed settings
require("hyprland-gui")
