hl.on("hyprland.start", function()
    local startupCommands = {
        "hypridle",
        "awww-daemon",
        "quickshell",
        "/usr/bin/lxqt-policykit-agent",
        "wallpaper-menu --restore",
    }

    -- exec_cmd already detaches the process
    for _, command in ipairs(startupCommands) do
        hl.exec_cmd(command)
    end
end)
