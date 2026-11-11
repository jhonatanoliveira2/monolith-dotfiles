# Design tokens of the MONOLITH "Nothing" theme (dot matrix / LED identity, inspired by NIHIL Shell by poligle,
# MIT, and by the look of Nothing devices; MONOLITH is not affiliated with Nothing Technology Limited).
# Plain data, kept in tokens.json so both install paths read the same values: the NixOS / Home Manager modules
# (here) and scripts/nothing-theme.sh on Arch Linux / CachyOS write them to ~/.config/monolith/nothing.json,
# which the shell reads (core/Nothing.qml). Grey levels only; red interrupts, it never decorates.
#   palette:      void (bar, menus, wallpaper background), surface (cards), raised (hover, tracks),
#                 line (1 px lines), off (unlit LEDs of the interface), muted (metadata, inactive icons),
#                 dim (secondary text), ink (primary text, lit LEDs), alert (critical alerts only)
#   fonts:        three voices, all SIL OFL (nix/pkgs/nothing-fonts.nix); the shell falls back when one is
#                 missing - dot (Doto: clocks, big numbers >= ~20 px), sans (Space Grotesk: headings,
#                 notification text), mono (Space Mono: interface text and labels), icons (glyphs)
#   motion:       ms; short, decelerating, no bounce
#   wallpaperOff: wallpaper LEDs that are off, dimmer than the interface's so the picture stays readable
builtins.fromJSON (builtins.readFile ./tokens.json)
