# monolith.nothingTheme (NixOS): installs the theme's fonts system-wide (the greeter and the lock screen see
# them too) and hands the options to the Home Manager module (programs.monolith.nothingTheme), which writes the
# tokens for the shell and renders the wallpapers. Set it here or per user in Home Manager.
{
  config,
  lib,
  pkgs,
  options,
  ...
}:
let
  cfg = config.monolith.nothingTheme;
  mpkgs = import ../../pkgs { inherit pkgs; };
  # every leaf as a default, so a user's Home Manager value still wins
  defaults =
    v: if builtins.isAttrs v && !lib.isDerivation v then lib.mapAttrs (_: defaults) v else lib.mkDefault v;
in
{
  options.monolith.nothingTheme = import ../nothing-options.nix { inherit lib; };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable { fonts.packages = [ mpkgs.nothing-fonts ]; })
    (lib.optionalAttrs (options ? home-manager) {
      home-manager.sharedModules = [ { programs.monolith.nothingTheme = defaults cfg; } ];
    })
  ];
}
