---- LOOK AND FEEL ----

hl.config({ render = { expand_undersized_textures = false } })
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = {
            top = 5,
            right = 8,
            bottom = 8,
            left = 8,
        },
        border_size = 4,
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 8,
        shadow = {
            enabled = false,
            range = 8,
            render_power = 3,
        },
    },
})
