# ~/.local/bin/toggle-gsr.sh
#!/bin/bash
PIDFILE=/tmp/osu-gsr.pid

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill -INT "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
    notify-send -a "GPU-Screen-Recorder" "Gravação" "Encerrando gravação..."
else
    mkdir -p "$HOME/Videos"
    file="$HOME/Videos/$(date +%Y-%m-%d_%H-%M-%S).mp4"
    cursor=$(hyprctl -j cursorpos)
    monitor=$(hyprctl -j monitors | jq -r --argjson c "$cursor" \
        '.[] | select($c.x >= .x and $c.x < (.x + .width) and $c.y >= .y and $c.y < (.y + .height)) | .name')

    if [ -z "$monitor" ]; then
        notify-send -u critical "Gravação" "Não foi possível identificar o monitor"
        exit 1
    fi

    gpu-screen-recorder -w "$monitor" -f 60 -k hevc -q ultra -bm qp -a default_output -o "$file" &
    pid=$!
    echo "$pid" > "$PIDFILE"

    sleep 0.8
    if kill -0 "$pid" 2>/dev/null; then
        notify-send -a "GPU-Screen-Recorder" "Gravação iniciada" "$monitor · HEVC · 60 FPS · Qualidade ultra"
    else
        rm -f "$PIDFILE"
        notify-send -u critical "Gravação" "Falha ao iniciar o gravador"
    fi
fi
