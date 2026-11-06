-- Programas usados diretamente pelos atalhos.
local terminal = "ghostty"
local fileManager = "nautilus"
local ide = "code"
local browser = "zen-browser"
local lockScreen = "hyprlock"

_G.programs = {
    terminal = terminal,
    fileManager = fileManager,
    ide = ide,
    browser = browser,
    lockScreen = lockScreen,
}

-- Overrides kept outside this file: ~/.config/monolith/programs.lua returns a table with any of the keys above
-- (written by the Nix Home Manager module from programs.monolith.apps; can also be created by hand).
local overrideFile = os.getenv("HOME") .. "/.config/monolith/programs.lua"
local ok, override = pcall(dofile, overrideFile)
if ok and type(override) == "table" then
    for key, value in pairs(override) do _G.programs[key] = value end
end
