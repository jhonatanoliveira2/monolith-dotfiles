-- Media / volume / brightness keys.
-- While Quickshell runs they go to its global shortcuts (native PipeWire / MPRIS control + on-screen display);
-- without the shell they fall back to the CLI tools, so the keys never stop working.
local function shellRunning()
    return #hl.get_layers({ namespace = "qs-bar" }) > 0
end

local function bindMedia(key, shortcut, fallback, repeating)
    hl.bind(key, function()
        if shellRunning() then
            hl.dispatch(hl.dsp.global("quickshell:" .. shortcut))
        else
            hl.dispatch(hl.dsp.exec_cmd(fallback))
        end
    end, { locked = true, repeating = repeating or false })
end

bindMedia("XF86AudioRaiseVolume", "volumeUp", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", true)
bindMedia("XF86AudioLowerVolume", "volumeDown", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", true)
bindMedia("XF86AudioMute", "volumeMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
bindMedia("XF86AudioMicMute", "micMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")

bindMedia("XF86MonBrightnessUp", "brightnessUp", "brightnessctl -e4 -n2 set 5%+", true)
bindMedia("XF86MonBrightnessDown", "brightnessDown", "brightnessctl -e4 -n2 set 5%-", true)

-- laptops: touchpad on / off (Settings > Input keeps the state) and keyboard backlight
bindMedia("XF86TouchpadToggle", "touchpadToggle", "notify-send Touchpad 'Quickshell is not running'")
bindMedia("XF86KbdBrightnessUp", "kbdUp", "brightnessctl -q -d '*::kbd_backlight' set +1", true)
bindMedia("XF86KbdBrightnessDown", "kbdDown", "brightnessctl -q -d '*::kbd_backlight' set 1-", true)
bindMedia("XF86KbdLightOnOff", "kbdCycle", "brightnessctl -q -d '*::kbd_backlight' set +1")

bindMedia("XF86AudioNext", "mediaNext", "playerctl next")
bindMedia("XF86AudioPrev", "mediaPrev", "playerctl previous")
bindMedia("XF86AudioPlay", "mediaToggle", "playerctl play-pause")
bindMedia("XF86AudioPause", "mediaToggle", "playerctl play-pause")
