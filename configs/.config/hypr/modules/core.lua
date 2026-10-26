hl.on("hyprland.start", function()
    -- --systemd also imports the variables into the systemd user manager
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
end)

hl.config({
    cursor = {
        no_hardware_cursors = 1,
    },
    misc = {
        -- the wallpaper is drawn by awww; never render Hyprland's own
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})
