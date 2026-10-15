# ===== AUTO START HYPRLAND (TTY1) =====
cat ~/.config/wpg/sequences &

if test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = 1
    exec start-hyprland
end

function ai
    set -l tmp (mktemp)
    set -l last_command (history --max=2 | tail -n 1)
    set -l question (string join " " -- $argv)

    codex exec \
        --skip-git-repo-check \
        --sandbox read-only \
        --output-last-message "$tmp" \
        "Você está sendo usado dentro do Fish shell no Arch Linux.

Não consulte .bash_history nem assuma que Bash é o shell do usuário.

Comando anterior executado no Fish:
$last_command

NÃO use Markdown, NÃO use blocos de código, NÃO use \`\`\`.

Pergunta do usuário:
$question" >/dev/null 2>/dev/null

    if test $status -eq 0
        cat "$tmp"
    end

    rm -f "$tmp"
end

function aic
    set -l tmp (mktemp)
    set -l question (string join " " -- $argv)

    codex exec \
        --skip-git-repo-check \
        --sandbox read-only \
        --output-last-message "$tmp" \
        "Responda somente com o comando necessário, em texto puro. NÃO use Markdown, NÃO use blocos de código, NÃO use \`\`\`. Pergunta: $question" >/dev/null 2>/dev/null

    if test $status -eq 0
        cat "$tmp"
    end

    rm -f "$tmp"
end


if status is-interactive

    # PATH
    fish_add_path ~/.local/bin

    # ===== PYWAL =====
    #if test -f "$HOME/.cache/wal/colors.fish"
       #source "$HOME/.cache/wal/colors.fish"
    #end

    # ===== FASTFETCH =====
   # fastfetch --logo "$(~/.config/fastfetch/random_logo.sh)"
    
    # ===== ATUIN =====
    atuin init fish | source

    # ===== STARSHIP =====
    starship init fish | source

end


