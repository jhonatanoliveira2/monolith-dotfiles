# Design tokens of the MONOLITH "Nothing" theme (dot matrix / LED identity, inspired by NIHIL Shell by poligle,
# MIT, and by the look of Nothing devices; MONOLITH is not affiliated with Nothing Technology Limited).
# Plain data: the NixOS / Home Manager modules write them to ~/.config/monolith/nothing.json, which the
# shell reads (core/Nothing.qml). Grey levels only; red interrupts, it never decorates.
{
  palette = {
    void = "000000"; # bar, menus, wallpaper background
    surface = "0e0e0e"; # cards
    raised = "1a1a1a"; # hover, tracks
    line = "2a2a2a"; # 1 px lines
    off = "333333"; # unlit LEDs of the interface
    muted = "7a7a7a"; # metadata, inactive icons
    dim = "a3a3a3"; # secondary text
    ink = "f2f2f2"; # primary text, lit LEDs
    alert = "d71921"; # critical alerts only
  };
  # three voices, all SIL OFL (nix/pkgs/nothing-fonts.nix); the shell falls back when one is missing
  fonts = {
    dot = "Doto"; # dot matrix: clocks, big numbers (>= ~20 px)
    sans = "Space Grotesk"; # headings, notification text
    mono = "Space Mono"; # interface text and labels
    icons = "JetBrainsMono Nerd Font"; # glyphs
  };
  # motion (ms): short, decelerating, no bounce
  motion = {
    fast = 140;
    normal = 240;
    slow = 480;
  };
  # wallpaper LEDs that are off: dimmer than the interface's, so the picture stays readable
  wallpaperOff = "0e0e0e";
}
