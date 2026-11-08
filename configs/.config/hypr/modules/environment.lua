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

