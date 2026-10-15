hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint", {
    type = "bezier",
    points = {
        { 0.23, 1 },
        { 0.32, 1 },
    },
})

hl.curve("easeInOutCubic", {
    type = "bezier",
    points = {
        { 0.65, 0.05 },
        { 0.36, 1 },
    },
})

hl.curve("linear", {
    type = "bezier",
    points = {
        { 0, 0 },
        { 1, 1 },
    },
})

hl.curve("almostLinear", {
    type = "bezier",
    points = {
        { 0.5, 0.5 },
        { 0.75, 1 },
    },
})

hl.curve("quick", {
    type = "bezier",
    points = {
        { 0.15, 0 },
        { 0.1, 1 },
    },
})

local animations = {
    { leaf = "global", speed = 10, bezier = "default" },
    { leaf = "border", speed = 6, bezier = "easeOutQuint" },
    { leaf = "windows", speed = 5, bezier = "easeOutQuint" },
    { leaf = "windowsIn", speed = 4.5, bezier = "easeOutQuint", style = "popin 90%" },
    { leaf = "windowsOut", speed = 2, bezier = "easeOutQuint", style = "popin 90%" },
    { leaf = "fadeIn", speed = 1.7, bezier = "almostLinear" },
    { leaf = "fadeOut", speed = 1.5, bezier = "almostLinear" },
    { leaf = "fade", speed = 3, bezier = "quick" },
    { leaf = "layers", speed = 4, bezier = "easeOutQuint" },
    { leaf = "layersIn", speed = 4, bezier = "easeOutQuint", style = "fade" },
    { leaf = "layersOut", speed = 1.6, bezier = "linear", style = "fade" },
    { leaf = "workspaces", speed = 3, bezier = "easeOutQuint", style = "slide" },
    { leaf = "workspacesIn", speed = 2.2, bezier = "easeOutQuint", style = "slide" },
    { leaf = "workspacesOut", speed = 2.2, bezier = "easeOutQuint", style = "slide" },
    { leaf = "zoomFactor", speed = 7, bezier = "quick" },
}

for _, animation in ipairs(animations) do
    animation.enabled = true
    hl.animation(animation)
end
