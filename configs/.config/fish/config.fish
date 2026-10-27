# ===== AUTO START HYPRLAND (TTY1) =====
# terminal palette + fish colours: conf.d/monolith-theme.fish (Settings > Themes; default = ~/.config/wpg/sequences)

set -U fish_greeting

if test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = 1
    exec start-hyprland
end

if status is-interactive

    # PATH
    fish_add_path ~/.local/bin

    # ===== PYWAL =====
    #if test -f "$HOME/.cache/wal/colors.fish"
       #source "$HOME/.cache/wal/colors.fish"
    #end

    # ===== FASTFETCH =====
    # fastfetch                 # MONOLITH logo + system box (fastfetch/config.jsonc)
    
    # ===== ATUIN =====
    atuin init fish | source

    # ===== STARSHIP =====
    starship init fish | source

end


