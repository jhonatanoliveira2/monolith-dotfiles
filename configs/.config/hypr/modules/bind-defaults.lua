-- Default key combos, by bind id. keybindings.lua and media-keys.lua bind each action to the combo here,
-- unless Settings > Input changed it (generated/binds.lua, same format; "" turns a bind off).
-- Quickshell reads this file too (services/Binds.qml): keep exactly one `["id"] = "COMBO",` per line.
-- Not listed in hyprland.lua: keybindings.lua loads it.
return {
    -- applications
    ["app.terminal"] = "SUPER + Return",
    ["app.files"] = "SUPER + X",
    ["app.ide"] = "SUPER + C",
    ["app.browser"] = "SUPER + TAB",

    -- shell (Quickshell overlays and menus; rofi / wallpaper-menu without the shell)
    ["shell.launcher"] = "SUPER + A",
    ["shell.wallpaper"] = "SUPER + D",
    ["shell.notifications"] = "SUPER + N",
    ["shell.media"] = "SUPER + M",
    ["shell.settings"] = "SUPER + comma",
    ["shell.session"] = "SUPER + Escape",

    -- capture
    ["capture.screen"] = "SUPER + Delete",
    ["capture.area"] = "SUPER + SHIFT + Delete",
    ["capture.record"] = "SUPER + R",

    -- session
    ["session.lock"] = "SUPER + Z",
    ["session.exit"] = "SUPER + SHIFT + X",

    -- windows
    ["win.close"] = "SUPER + Q",
    ["win.float"] = "SUPER + Space",
    ["win.floatKeep"] = "SUPER + S",
    ["win.fullscreen"] = "SUPER + F",
    ["win.pin"] = "SUPER + P",
    ["win.split"] = "SUPER + J",
    ["win.group"] = "SUPER + G",
    ["win.drag"] = "SUPER + mouse:272",
    ["win.resizeMouse"] = "SUPER + mouse:273",

    -- focus, move, swap and resize
    ["focus.last"] = "SUPER + grave",
    ["focus.left"] = "SUPER + LEFT",
    ["focus.right"] = "SUPER + RIGHT",
    ["focus.up"] = "SUPER + UP",
    ["focus.down"] = "SUPER + DOWN",
    ["move.left"] = "SUPER + SHIFT + LEFT",
    ["move.right"] = "SUPER + SHIFT + RIGHT",
    ["move.up"] = "SUPER + SHIFT + UP",
    ["move.down"] = "SUPER + SHIFT + DOWN",
    ["swap.left"] = "SUPER + CTRL + H",
    ["swap.right"] = "SUPER + CTRL + L",
    ["swap.up"] = "SUPER + CTRL + K",
    ["swap.down"] = "SUPER + CTRL + J",
    ["resize.left"] = "SUPER + ALT + LEFT",
    ["resize.right"] = "SUPER + ALT + RIGHT",
    ["resize.up"] = "SUPER + ALT + UP",
    ["resize.down"] = "SUPER + ALT + DOWN",

    -- workspaces
    ["ws.prev"] = "SUPER + CTRL + LEFT",
    ["ws.next"] = "SUPER + CTRL + RIGHT",
    ["ws.special"] = "SUPER + W",
    ["ws.toSpecial"] = "SUPER + SHIFT + W",
    ["ws.toMonitor"] = "SUPER + ALT + W",
    ["ws.go1"] = "SUPER + 1",
    ["ws.go2"] = "SUPER + 2",
    ["ws.go3"] = "SUPER + 3",
    ["ws.go4"] = "SUPER + 4",
    ["ws.go5"] = "SUPER + 5",
    ["ws.go6"] = "SUPER + 6",
    ["ws.go7"] = "SUPER + 7",
    ["ws.go8"] = "SUPER + 8",
    ["ws.go9"] = "SUPER + 9",
    ["ws.go10"] = "SUPER + 0",
    ["ws.move1"] = "SUPER + SHIFT + 1",
    ["ws.move2"] = "SUPER + SHIFT + 2",
    ["ws.move3"] = "SUPER + SHIFT + 3",
    ["ws.move4"] = "SUPER + SHIFT + 4",
    ["ws.move5"] = "SUPER + SHIFT + 5",
    ["ws.move6"] = "SUPER + SHIFT + 6",
    ["ws.move7"] = "SUPER + SHIFT + 7",
    ["ws.move8"] = "SUPER + SHIFT + 8",
    ["ws.move9"] = "SUPER + SHIFT + 9",
    ["ws.move10"] = "SUPER + SHIFT + 0",

    -- cursor zoom
    ["zoom.out"] = "SUPER + mouse_down",
    ["zoom.in"] = "SUPER + mouse_up",
    ["zoom.outPad"] = "SUPER + code:82",
    ["zoom.inPad"] = "SUPER + code:86",

    -- media and hardware keys
    ["hw.volUp"] = "XF86AudioRaiseVolume",
    ["hw.volDown"] = "XF86AudioLowerVolume",
    ["hw.mute"] = "XF86AudioMute",
    ["hw.micMute"] = "XF86AudioMicMute",
    ["hw.brightUp"] = "XF86MonBrightnessUp",
    ["hw.brightDown"] = "XF86MonBrightnessDown",
    ["hw.touchpad"] = "XF86TouchpadToggle",
    ["hw.kbdUp"] = "XF86KbdBrightnessUp",
    ["hw.kbdDown"] = "XF86KbdBrightnessDown",
    ["hw.kbdLight"] = "XF86KbdLightOnOff",
    ["hw.next"] = "XF86AudioNext",
    ["hw.prev"] = "XF86AudioPrev",
    ["hw.play"] = "XF86AudioPlay",
    ["hw.pause"] = "XF86AudioPause",
}
