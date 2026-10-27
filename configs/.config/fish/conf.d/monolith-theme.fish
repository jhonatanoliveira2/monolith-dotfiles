# Monolith Shell colour theme (Settings > Themes)
# The shell writes the active theme to ~/.local/state/quickshell-monolith/fish-theme.fish and then changes the
# universal variable __monolith_theme_rev: fish passes that change to every open session, which runs the
# handler below at once (no polling). New sessions apply the theme here, at startup.
# Default theme (or no file): fish's own colours and the original terminal palette (~/.config/wpg/sequences).
status is-interactive; or return

set -l __state_home $XDG_STATE_HOME
test -n "$__state_home"; or set __state_home $HOME/.local/state
set -g __monolith_theme_file $__state_home/quickshell-monolith/fish-theme.fish

# fish's own colours, remembered once per session before any theme touches them
set -g __monolith_theme_orig (set -n | string match -r '^fish_(?:pager_)?color_.*')
for __v in $__monolith_theme_orig
    set -g __monolith_orig_$__v $$__v
end
set -e __v

function __monolith_theme_restore
    for v in (set -n | string match -r '^fish_(?:pager_)?color_.*')
        contains -- $v $__monolith_theme_orig; or set -eg $v
    end
    for v in $__monolith_theme_orig
        set -l o __monolith_orig_$v
        set -g $v $$o
    end
end

function __monolith_theme_apply --on-variable __monolith_theme_rev
    functions -e __monolith_theme_colors __monolith_theme_terminal
    test -r $__monolith_theme_file; and source $__monolith_theme_file
    __monolith_theme_restore
    functions -q __monolith_theme_colors; and __monolith_theme_colors
    # terminal palette (OSC 4/10/11/12), only on a real terminal
    if isatty stdout
        if functions -q __monolith_theme_terminal
            __monolith_theme_terminal
        else if test -r ~/.config/wpg/sequences
            cat ~/.config/wpg/sequences
        end
    end
    # an open session redraws its prompt with the new colours
    status is-interactive-read 2>/dev/null; and commandline -f repaint 2>/dev/null
    return 0
end

__monolith_theme_apply
