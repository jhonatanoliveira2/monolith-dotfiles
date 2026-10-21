hl.on("hyprland.start", function()
    local startupCommands = {
        "hypridle",
        "awww-daemon",
        "quickshell",
        "/usr/bin/lxqt-policykit-agent",
        "wallpaper-menu --restore",
    }

    for _, command in ipairs(startupCommands) do
        hl.exec_cmd(command .. " &")
    end
end)
