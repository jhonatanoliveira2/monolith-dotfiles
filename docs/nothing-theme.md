# Nothing theme (LED / dot matrix)

[Português (Brasil)](nothing-theme.pt-br.md) · **English**

The `feature/nothing-theme` branch (made from `feature/nixos-support`, NixOS only) adds an optional visual
identity to the MONOLITH Shell inspired by [NIHIL Shell](https://github.com/poligle/Nihil-Shell) (MIT) and by
the dot-matrix look of Nothing devices. It is **on by default on this branch**; turned off, the shell is exactly
the `feature/nixos-support` one.

> This project is not affiliated with Nothing Technology Limited. No Nothing logo or proprietary font (Ndot) is
> used; the type is Doto, Space Grotesk and Space Mono (SIL OFL). Credits: [`THIRD-PARTY-CREDITS.md`](../THIRD-PARTY-CREDITS.md).

## Contents

- [What changes](#what-changes)
- [How it is built](#how-it-is-built)
- [Options (`monolith.nothingTheme`)](#options-monolithnothingtheme)
- [Settings app: runtime vs. rebuild](#settings-app-runtime-vs-rebuild)
- [Wallpapers](#wallpapers)
- [Switching a system from `feature/nixos-support` to `feature/nothing-theme`](#switching-a-system-from-featurenixos-support-to-featurenothing-theme)
- [Troubleshooting](#troubleshooting)

## What changes

| Area | Nothing theme |
|---|---|
| Colours | greys from OLED black to `#F2F2F2` (replaces Settings > Themes while `monochrome` is on); red `#D71921` **only** for critical alerts (critical toast border and LED, critical bar items) |
| Type | Space Mono for the interface (monospaced, so layouts keep their widths), Space Grotesk for headings and notification text, Doto for the clocks (bar and widget); Nerd Font glyphs fall back to JetBrainsMono Nerd Font |
| Meters | the OSD (volume, brightness...), every slider and the circular gauges become rows / rings of LEDs; switches are pills with an LED knob |
| Bar | frame style: OLED-black frame with a 1 px line along its inner edge and 20 px corners (NIHIL Shell's frame); on a side bar the clock is hours over minutes in Doto; side-bar modules show icons only |
| Center menu | Doto clock, LED tab markers, calendar with an outlined day, LED columns for CPU / GPU / RAM, LED rows for every progress, usage and temperature bar; with a side bar it opens at the top centre when the pointer rests on the middle of the top edge (or on a click on the clock), as a drawer of the frame (frame style: same black, concave joints, the frame line running around it) |
| Battery | the charge as LEDs (a row; eight in a column on a side bar), red when low, a light scanning up while charging |
| Widgets | every widget of a size has the same width (small 256, medium 320, large 416 px), the clock centred in its card; every widget, saved or temporary, shows only on the workspace it was added on; the lyrics widget's audio spectrum (cava) is drawn as columns of LEDs |
| Cursor | **MONOLITH Dots**: a "+" of LEDs as the pointer and LED shapes for links, text, waiting (animated), moving and resizing; white LEDs with a dark rim and shadow, visible on light and dark backgrounds (Hyprland, GTK, Qt) |
| Surfaces | a faint grid of unlit LEDs behind cards and desktop widgets; Settings headings with an LED marker |
| Notifications | app name as an upper-case label with an LED, Space Grotesk text; optional **edge glow**: a segment of light runs around the inside of the screen edge on each toast, twice and red for critical ones |
| Wallpapers | still wallpapers shown as LED matrices at each monitor's native resolution (the original files are never changed); live (video) wallpapers are left alone |

Contrast and brightness of the wallpapers can be raised by hand (`monolith-dotmatrix --contrast` /
`--brightness`, 1 = the default curve). For legibility, Settings > Bar > **No transparency in the shell** makes the bar, menus and
widgets opaque in one switch (the terminal and other apps keep their own transparency; it works with or without
the theme).

Motion stays short and decelerating; everything follows Settings > Appearance > animations (off = no glow, no fades).

## How it is built

```
nix/nothing/tokens.nix          palette, fonts, motion (single source of truth)
nix/modules/nothing-options.nix options, shared by NixOS (monolith.nothingTheme) and Home Manager
nix/modules/nixos/nothing.nix   fonts system-wide, forwards the options to Home Manager
nix/modules/home-nothing.nix    ~/.config/monolith/nothing.json, fonts + renderer on PATH, build-time wallpapers
nix/nothing/dotmatrix.py        monolith-dotmatrix (Python + numpy + Pillow): picture -> LED matrix
nix/pkgs/nothing-fonts.nix      Doto, Space Grotesk, Space Mono (single files from google/fonts, hashed)
nix/pkgs/nothing-wallpapers.nix every still picture x every declared monitor, one derivation each
configs/.config/quickshell/core/Nothing.qml   reads nothing.json + the runtime overrides (Settings.nothing)
```

Nix generates the tokens as JSON; `core/Nothing.qml` exposes them to the QML (`Theme.p`, `Theme.font`,
`Theme.fontSans`, `Theme.fontDot`, `Theme.alert`, `Theme.nothing`). Without `nothing.json` (the theme
off) `Nothing.available` is false and no file of the shell behaves differently.

## Options (`monolith.nothingTheme`)

Set them in `/etc/nixos/configuration.nix` (or per user as `programs.monolith.nothingTheme` in Home Manager).
"Runtime" options can also be changed in the Settings app; the Nix value is the default it starts from.

| Option | Default | | Effect |
|---|---|---|---|
| `enable` | `true` | rebuild | the whole theme (fonts, tokens, renderer, build-time wallpapers) |
| `led.size` | `6` | runtime | LED diameter in px (wallpapers; interface meters scale it) |
| `led.spacing` | `3` | runtime | gap between LEDs in px |
| `led.shape` | `"circle"` | runtime | `circle`, `rounded` or `square` (wallpapers and interface LEDs) |
| `monochrome` | `true` | runtime | grey palette for the shell and grey wallpaper LEDs; off: the colour theme stays and LEDs take the picture's hues |
| `cursor.enable`, `cursor.size` | `true`, `28` | rebuild | the LED cursor theme (Monolith-Dots) and its size; log in again to see it everywhere |
| `edgeGlow` | `true` | runtime | light along the screen edge on notifications |
| `wallpaper.style` | `"dotmatrix"` | runtime | `dotmatrix` or `original` |
| `wallpaper.dither` | `"none"` | runtime | `none` (LED size and brightness follow the picture), `floyd` (Floyd-Steinberg), `bayer` (ordered) |
| `wallpaper.levels` | `2` | runtime | brightness steps with dithering (`2` = on / off) |
| `wallpaper.invert` | `false` | runtime | light the dark parts |
| `wallpaper.contrast`, `wallpaper.brightness` | `100`, `100` | runtime | contrast and brightness of the wallpapers in % (50 to 200; Settings has a button back to the default) |
| `wallpaper.colors.{lit,off,background}` | `f2f2f2`, `141414`, `000000` | rebuild | LED colours of the wallpapers |
| `wallpaper.outputs` | `{ }` | rebuild | monitors rendered at build time, `{ eDP-1 = { width = 1920; height = 1200; }; }` |
| `wallpaper.dirs` | `[ <repo>/wallpapers/static ]` | rebuild | folders whose still pictures are rendered at build time |

Example:

```nix
monolith.nothingTheme = {
  led = { size = 5; spacing = 3; shape = "rounded"; };
  wallpaper.outputs = {
    eDP-1 = { width = 1920; height = 1200; };   # names and sizes: hyprctl monitors
    DP-1 = { width = 2560; height = 1440; };
  };
};
# monolith.nothingTheme.enable = false;   # back to the feature/nixos-support look
```

## Settings app: runtime vs. rebuild

**Settings > Themes > Nothing** (shown only when `nothing.json` exists):

- **Apply at once:** theme on / off, monochrome, edge glow, LED shape, size and spacing, wallpaper style,
  dithering, brightness levels, invert, wallpaper contrast and brightness (with a button back to the default). They are saved as overrides in
  `~/.local/state/quickshell-monolith/settings.json` (`nothing`); changing a wallpaper option shows the current
  still wallpaper again with the new look.
- **Reset to defaults:** drops the overrides, back to the values of the Nix configuration.
- **Delete converted wallpapers (cache):** empties `~/.cache/monolith/dotmatrix`.
- **Need a rebuild** (listed at the bottom of the section): `enable` as the default, the fonts, the defaults
  themselves, the wallpaper colours and the build-time renderings (`wallpaper.outputs`, `wallpaper.dirs`).

## Wallpapers

Only **still** pictures (PNG, JPEG, WebP, BMP) are converted; an animated GIF is shown as it is (with a
notice) and live wallpapers (mpvpaper) are not touched. **The original file is only read**: the rendering goes
to the store (build) or to `~/.cache/monolith/dotmatrix` (runtime), and the wallpaper state keeps pointing at
the original, so turning the style back to `original` shows it again.

### Applying a wallpaper

Pick it as usual: Settings > Wallpapers (or the picker), or the rofi menu (`wallpaper-menu`). With the style
`dotmatrix`, `wallpaper-menu` renders the picture for **each monitor at its native resolution** (rotated
monitors swapped) and gives each monitor its own matrix:

1. a build-time rendering, when the picture has the same content (sha256), the look in effect has the same
   key and the monitor has that size;
2. else the cache, `~/.cache/monolith/dotmatrix/<hash>.png` (the hash covers the picture, the size and the look);
3. else it renders now (about a second for 4K) and caches it.

From a terminal: `wallpaper-menu --set static ~/Pictures/Wallpapers/blue_sky.png` (all monitors) or
`... ALL|DP-1,eDP-1`. After a change of look in Settings the current wallpaper is rendered again by itself;
`wallpaper-menu --restore` (autostart) does the same at login.

### Converting by hand: `monolith-dotmatrix`

Installed on PATH by the theme:

```sh
# one picture for one resolution
monolith-dotmatrix ~/Pictures/photo.jpg -o ~/Pictures/photo-dots.png --resolution 2560x1440
# several monitors at once (one PNG per name)
monolith-dotmatrix photo.jpg --outdir ~/Pictures/dots --output eDP-1:1920x1200 --output DP-1:2560x1440
# the look
monolith-dotmatrix photo.jpg -o out.png -r 1920x1080 --size 5 --spacing 2 --shape square \
  --dither floyd --levels 3 --invert --lit ffffff --off 101010 --background 000000 [--color]
monolith-dotmatrix --key [options]     # the cache key of a look (what the build and wallpaper-menu compare)
```

`--size` / `--spacing` in px, `--shape circle|rounded|square`, `--dither none|floyd|bayer`, `--levels 2..16`,
`--color` keeps the picture's hues, `--gamma`, `--black`, `--contrast` (1) and `--brightness` (1) tune the curve. It refuses to write over its source
and to convert animated pictures (exit code 2). The result is a normal PNG: apply it with
`wallpaper-menu --set static out.png` (set the style to `original` first, or it would be converted again).

### Build-time rendering

With `wallpaper.outputs` set, every still picture of `wallpaper.dirs` is rendered for every listed monitor
during `nixos-rebuild` (one derivation per picture x monitor: a rebuild only renders what changed). The
renderings live in the store, listed in `nothing.json` (`wallpapers.dir`), and are used only while the look in
Settings matches the Nix one; any other look falls back to the runtime cache.

## Switching a system from `feature/nixos-support` to `feature/nothing-theme`

The flake in `/etc/nixos` follows a branch through its `monolith` input. Point it at this branch:

```sh
sudo sed -i 's|monolith-dotfiles/feature/nixos-support|monolith-dotfiles/feature/nothing-theme|' /etc/nixos/flake.nix
sudo nix flake update monolith --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos
```

Log out and in (or restart the shell) to load the new fonts. Settings > Update then follows
`feature/nothing-theme`. To go back, run the same with the two branch names swapped (or set
`monolith.nothingTheme.enable = false;` to stay on this branch without the theme). A new install from the ISO:
`sudo nix --extra-experimental-features "nix-command flakes" run github:jhonatanoliveira2/monolith-dotfiles/feature/nothing-theme#install`.

## Troubleshooting

- **Square boxes instead of Doto / Space fonts:** log out and in after the first rebuild (font cache); the shell
  falls back to JetBrainsMono Nerd Font for any family it cannot find.
- **The wallpaper stays the original:** check Settings > Themes > Nothing > Wallpaper = LED matrix; animated
  pictures and videos are never converted; `monolith-dotmatrix --help` must work in a terminal.
- **A rendering looks stale:** Settings > Themes > Nothing > Delete converted wallpapers, then pick it again.
- **No section in Settings:** `~/.config/monolith/nothing.json` is missing: the theme is off
  (`monolith.nothingTheme.enable`) or the system is not on this branch.
