hl.on("hyprland.start", function()
    local startupCommands = {
        "hypridle",
        "awww-daemon",
        "bash " .. os.getenv("HOME") .. "/.config/quickshell/scripts/start.sh",   -- quickshell without THP (less RAM)
        "lxqt-policykit-agent",   -- from PATH: /usr/bin on Arch, the Nix profile on NixOS
        "wallpaper-menu --restore",
    }

    -- exec_cmd already detaches the process
    for _, command in ipairs(startupCommands) do
        hl.exec_cmd(command)
    end
end)
