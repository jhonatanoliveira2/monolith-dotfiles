hl.env("LANG", "pt_BR.UTF-8")
hl.env("LC_TIME", "pt_BR.UTF-8")
hl.env("XCURSOR_SIZE", "23")
hl.env("HYPRCURSOR_SIZE", "24")
-- Cursor theme chosen by the system configuration (NixOS, Nothing theme: "Monolith-Dots 24" in
-- ~/.config/monolith/cursor); without the file the default theme and the sizes above stay.
do
    local f = io.open(os.getenv("HOME") .. "/.config/monolith/cursor", "r")
    if f then
        local theme, size = (f:read("l") or ""):match("^(%S+)%s+(%d+)")
        f:close()
        if theme then
            hl.env("XCURSOR_THEME", theme)
            hl.env("XCURSOR_SIZE", size)
            hl.env("HYPRCURSOR_SIZE", size)
        end
    end
end
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")


-- NVIDIA (nvidia-drm loaded: the proprietary driver or its open kernel modules). When it draws the desktop - the
-- only GPU, or the one the firmware starts on - video decoding (VA-API) and GLX use NVIDIA's libraries. On a
-- hybrid laptop (the integrated GPU first) nothing is set: the integrated GPU draws the desktop and the NVIDIA
-- one sleeps until an app asks for it (prime-run on Arch, nvidia-offload on NixOS). MONOLITH_NVIDIA=1 in the
-- session's environment forces these variables, MONOLITH_NVIDIA=0 leaves them out.
do
    local function read(path)
        local f = io.open(path, "r")
        if not f then
            return nil
        end
        local v = f:read("l")
        f:close()
        return v
    end
    local primary = false
    if read("/sys/module/nvidia_drm/initstate") or read("/sys/module/nvidia_drm/parameters/modeset") then
        local nvidia, nvidiaFirst, other = false, false, false
        for i = 0, 15 do
            local dev = "/sys/class/drm/card" .. i .. "/device/"
            local vendor = read(dev .. "vendor")
            if vendor == "0x10de" then
                nvidia = true
                nvidiaFirst = nvidiaFirst or read(dev .. "boot_vga") == "1"
            elseif vendor then
                other = true
            end
        end
        primary = nvidia and (nvidiaFirst or not other)
    end
    local forced = os.getenv("MONOLITH_NVIDIA")
    if forced == "1" or (forced ~= "0" and primary) then
        hl.env("LIBVA_DRIVER_NAME", "nvidia")
        hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
        hl.env("NVD_BACKEND", "direct") -- nvidia-vaapi-driver (libva-nvidia-driver)
    end
end
