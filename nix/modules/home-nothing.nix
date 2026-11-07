# Home Manager side of the Nothing theme (options: nothing-options.nix, programs.monolith.nothingTheme; on NixOS
# they come from monolith.nothingTheme). Writes the design tokens and the defaults for the shell to
# ~/.config/monolith/nothing.json (read by core/Nothing.qml and by wallpaper-menu), installs the fonts and
# the dot-matrix renderer, and renders the wallpapers of `wallpaper.outputs` at build time.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.monolith.nothingTheme;
  mpkgs = import ../pkgs { inherit pkgs; };
  tokens = import ../nothing/tokens.nix;
  w = cfg.wallpaper;
  bare = c: lib.toLower (lib.removePrefix "#" c);
  colors = lib.mapAttrs (_: bare) w.colors;
  # the same string as `monolith-dotmatrix --key` (nix/nothing/dotmatrix.py): equal keys = identical output
  key = lib.concatStringsSep "-" [
    "v4" # LOOK in dotmatrix.py
    (toString cfg.led.size)
    (toString cfg.led.spacing)
    cfg.led.shape
    w.dither
    (toString w.levels)
    (if w.invert then "inv" else "pos")
    (if cfg.monochrome then "mono" else "color")
    colors.lit
    colors.off
    colors.background
  ];
  args = [
    "--size"
    (toString cfg.led.size)
    "--spacing"
    (toString cfg.led.spacing)
    "--shape"
    cfg.led.shape
    "--dither"
    w.dither
    "--levels"
    (toString w.levels)
    "--lit"
    colors.lit
    "--off"
    colors.off
    "--background"
    colors.background
  ]
  ++ lib.optional w.invert "--invert"
  ++ lib.optional (!cfg.monochrome) "--color";
  rendered = w.style == "dotmatrix" && w.outputs != { };
  wallpapers = pkgs.callPackage ../pkgs/nothing-wallpapers.nix {
    inherit (mpkgs) dotmatrix;
    inherit args key;
    inherit (w) dirs outputs;
  };
in
{
  options.programs.monolith.nothingTheme = import ./nothing-options.nix { inherit lib; };

  config = lib.mkIf (config.programs.monolith.enable && cfg.enable) {
    home.packages = [
      mpkgs.dotmatrix
      mpkgs.nothing-fonts
    ];
    xdg.configFile."monolith/nothing.json".text = builtins.toJSON {
      version = 1;
      # what the shell starts from; Settings > Themes > Nothing changes them at runtime
      defaults = {
        enabled = true;
        inherit (cfg) monochrome edgeGlow;
        ledSize = cfg.led.size;
        ledSpacing = cfg.led.spacing;
        ledShape = cfg.led.shape;
        wallpaperStyle = w.style;
        inherit (w) dither levels invert;
        inherit (colors) lit off background;
      };
      palette = lib.mapAttrs (_: c: "#${c}") tokens.palette;
      inherit (tokens) fonts motion;
      # build-time renderings: used by wallpaper-menu when the file and the look (key) match
      wallpapers = {
        dir = if rendered then "${wallpapers}" else "";
        key = if rendered then key else "";
        outputs = lib.attrNames w.outputs;
      };
    };
  };
}
