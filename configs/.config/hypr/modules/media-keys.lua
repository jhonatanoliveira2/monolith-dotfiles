-- Media / volume / brightness keys.
-- While Quickshell runs they go to its global shortcuts (native PipeWire / MPRIS control + on-screen display);
-- without the shell they fall back to the CLI tools, so the keys never stop working.
local function shellRunning()
    return #hl.get_layers({ namespace = "qs-bar" }) > 0
end

-- combos by id: modules/bind-defaults.lua / Settings > Input (bind from keybindings.lua)
local function bindMedia(id, shortcut, fallback, repeating)
    _G.monolithBind(id, function()
        if shellRunning() then
            hl.dispatch(hl.dsp.global("quickshell:" .. shortcut))
        else
            hl.dispatch(hl.dsp.exec_cmd(fallback))
        end
    end, { locked = true, repeating = repeating or false })
end

bindMedia("hw.volUp", "volumeUp", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", true)
bindMedia("hw.volDown", "volumeDown", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", true)
bindMedia("hw.mute", "volumeMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
bindMedia("hw.micMute", "micMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")

bindMedia("hw.brightUp", "brightnessUp", "brightnessctl -e4 -n2 set 5%+", true)
bindMedia("hw.brightDown", "brightnessDown", "brightnessctl -e4 -n2 set 5%-", true)

-- laptops: touchpad on / off (Settings > Input keeps the state) and keyboard backlight
bindMedia("hw.touchpad", "touchpadToggle", "notify-send Touchpad 'Quickshell is not running'")
bindMedia("hw.kbdUp", "kbdUp", "brightnessctl -q -d '*::kbd_backlight' set +1", true)
bindMedia("hw.kbdDown", "kbdDown", "brightnessctl -q -d '*::kbd_backlight' set 1-", true)
bindMedia("hw.kbdLight", "kbdCycle", "brightnessctl -q -d '*::kbd_backlight' set +1")

bindMedia("hw.next", "mediaNext", "playerctl next")
bindMedia("hw.prev", "mediaPrev", "playerctl previous")
bindMedia("hw.play", "mediaToggle", "playerctl play-pause")
bindMedia("hw.pause", "mediaToggle", "playerctl play-pause")
