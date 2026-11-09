hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = -0.2,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-- Touchpad: four fingers moving in any direction carry the window under them (no key, no click),
-- the easy way to rearrange windows without a mouse (SUPER + click-drag still works)
hl.gesture({
    fingers = 4,
    direction = "swipe",
    action = "move",
})
