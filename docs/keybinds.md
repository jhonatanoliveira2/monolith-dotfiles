# Keybinds

[Português (Brasil)](atalhos.md) · **English**

`SUPER` is the main modifier. Media keys (volume, brightness, player) are handled natively by the shell with an on-screen display.

## Apps and shell

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Return` | Terminal | Opens the terminal (`programs.terminal`) |
| `SUPER + X` | File Manager | Opens the file manager (`programs.fileManager`) |
| `SUPER + C` | Code | Opens VS Code / Cursor |
| `SUPER + TAB` | Browser | Opens Zen Browser |
| `SUPER + Z` | Lock | Locks the session with `hyprlock` |
| `SUPER + A` | App Launcher | Toggles Rofi launcher (`~/.config/hypr/rofi/launcher.sh`) |
| `SUPER + D` | Wallpaper Menu | Opens wallpaper selector (`~/.local/bin/wallpaper-menu`) |
| `SUPER + SHIFT + X` | Exit Session | Runs `hyprshutdown` if available, otherwise exits Hyprland |
| `SUPER + N` | Notifications | Opens the notification center |
| `SUPER + M` | Media | Opens the media player (cover, seek, volume, search) |
| `SUPER + ,` | Settings | Opens the Monolith Settings app |
| `SUPER + Escape` | Session | Opens the system / session menu |
| `SUPER + B` | Widgets | Arranges the desktop widgets (add, move, resize, remove) |
| Media keys | Volume / Brightness / Player | Handled natively by the shell with an on-screen display (CLI fallback when the shell is not running) |

## Windows

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Space` | Toggle Float + Center | Toggles floating mode and centers the window (70% of monitor size) |
| `SUPER + S` | Toggle Float | Toggles floating mode without centering |
| `SUPER + Q` | Close Window | Closes the active window |
| `SUPER + F` | Fullscreen | Toggles fullscreen mode |
| `SUPER + SHIFT + ←/→/↑/↓` | Move Window | Moves the active window in the given direction (group-aware) |
| `SUPER + ←/→/↑/↓` | Focus Window | Moves focus in the given direction |
| `SUPER + ALT + ←/→/↑/↓` | Resize Window | Resizes the active window (40px steps, repeating) |
| `SUPER + Left Click` | Drag Window | Moves/drags the window with the mouse |
| `SUPER + Right Click` | Resize Window | Resizes the window with the mouse |
| `SUPER + J` | Toggle Split | Toggles the dwindle split direction |
| `SUPER + G` | Group | Toggles a window group (tabs) |
| `SUPER + grave` | Urgent / Last | Focuses the urgent window, or the previous one |
| `SUPER + CTRL + H/J/K/L` | Swap Window | Swaps the active window with its neighbour |

## Workspaces and monitors

| Keybind | Action | Description |
|---|---|---|
| `SUPER + W` | Special Workspace | Toggles the special workspace `"magic"` |
| `SUPER + SHIFT + W` | Move to Special | Moves active window to the special workspace |
| `SUPER + ALT + W` | Move to Next Monitor | Moves active window to the next monitor (`m+`) |
| `SUPER + 1–0` | Focus Workspace | Switches to workspace 1–10 |
| `SUPER + SHIFT + 1–0` | Move to Workspace | Moves active window to workspace 1–10 |
| `SUPER + P` | Pin | Pins the active (floating) window on every workspace |
| `SUPER + CTRL + ←/→` | Previous / Next Workspace | Cycles through occupied workspaces |

## Capture and zoom

| Keybind | Action | Description |
|---|---|---|
| `SUPER + Delete` | Screenshot (Full) | Captures the focused monitor, saves to `~/Pictures` and copies to clipboard |
| `SUPER + SHIFT + Delete` | Screenshot (Area) | Captures selected area with `slurp` + `grim`, saves and copies to clipboard |
| `SUPER + R` | Screen Recording | Toggles GPU Screen Recorder (`toggle-gsr.sh`) saves to `~/Videos` |
| `SUPER + Mouse Wheel Down` | Zoom Out | Decreases cursor zoom factor (min 1.0) |
| `SUPER + Mouse Wheel Up` | Zoom In | Increases cursor zoom factor (max 1.5) |
| `SUPER + Numpad -` | Zoom Out | Decreases cursor zoom factor by 0.3 |
| `SUPER + Numpad +` | Zoom In | Increases cursor zoom factor by 0.3 |

