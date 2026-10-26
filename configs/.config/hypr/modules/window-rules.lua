hl.window_rule({
    name = "suppress-maximize-events",
    match = {
        class = ".*",
    },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = {
        class = "hyprland-run",
    },
    move = "20 monitor_h-120",
    float = true,
})

-- Monolith Settings (Quickshell FloatingWindow)
hl.window_rule({
    name = "monolith-settings",
    match = {
        title = "^Monolith Settings$",
    },
    float = true,
    size = "1000 660",
    center = true,
})

-- Quickshell surfaces: the menus/toasts/OSD animate themselves in QML, so skip the compositor
-- animation (no double fade); blur only what is translucent.
hl.layer_rule({
    name = "qs-bar",
    match = { namespace = "^qs-bar$" },
    blur = true,
    ignore_alpha = 0.2,
})

hl.layer_rule({
    name = "qs-popups",
    match = { namespace = "^qs-(menu|toasts|osd)$" },
    blur = true,
    ignore_alpha = 0.3,
    no_anim = true,
})
