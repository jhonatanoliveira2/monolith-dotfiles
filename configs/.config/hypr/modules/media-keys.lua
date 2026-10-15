local function bindMedia(key, command, options)
    hl.bind(
        key,
        hl.dsp.exec_cmd(command),
        options or { locked = true }
    )
end

bindMedia(
    "XF86AudioRaiseVolume",
    "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
    { locked = true, repeating = true }
)

bindMedia(
    "XF86AudioLowerVolume",
    "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
    { locked = true, repeating = true }
)

bindMedia("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
bindMedia("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")

bindMedia(
    "XF86MonBrightnessUp",
    "brightnessctl -e4 -n2 set 5%+",
    { locked = true, repeating = true }
)

bindMedia(
    "XF86MonBrightnessDown",
    "brightnessctl -e4 -n2 set 5%-",
    { locked = true, repeating = true }
)

bindMedia("XF86AudioNext", "playerctl next")
bindMedia("XF86AudioPause", "playerctl play-pause")
bindMedia("XF86AudioPlay", "playerctl play-pause")
bindMedia("XF86AudioPrev", "playerctl previous")
