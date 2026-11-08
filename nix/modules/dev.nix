# Development mode of the Home Manager module (programs.monolith.dev).
#
# Normally every file of configs/.config is linked from the Nix store (read-only: an edit needs a rebuild).
# With dev.enable the same links point into a checkout of this repository instead
# (config.lib.file.mkOutOfStoreSymlink): ~/.config/<file> -> <checkout>/configs/.config/<file>. Editing the
# checkout changes the desktop at once (Quickshell reloads itself; Hyprland on `hyprctl reload`), with no
# rebuild, no Home Manager run and no permission changes: the checkout is the user's own folder.
#
#   * Only the links change: everything else stays declarative (packages, services, generated files such as
#     nix.json or programs.lua, the copies of `mutableFiles`).
#   * A rebuild never writes into the checkout and never replaces its files; turning dev mode off (and
#     rebuilding) puts the store links back.
#   * Files are linked one by one, as in the normal mode, so what programs write next to them (fish_variables,
#     hypr/generated/...) stays in ~/.config and never ends up in the repository. Quickshell's folder is linked
#     whole, so new QML files show up at once; a new file elsewhere needs one rebuild to get its link.
#
# Other modules use `config.programs.monolith.dev.link` for their own files, so they follow the same switch:
#   source = dev.link { module = "fastfetch"; path = "nix/nothing/fastfetch.jsonc"; store = ../nothing/fastfetch.jsonc; };
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.programs.monolith.dev;
  on = config.programs.monolith.enable && cfg.enable && cfg.source != null;
  # is this module taken from the checkout?
  selected = module: on && (cfg.modules == null || lib.elem module cfg.modules);
in
{
  options.programs.monolith.dev = {
    enable = lib.mkEnableOption ''
      development mode: the configuration files are linked to an editable checkout of the repository
      (`source`) instead of the read-only Nix store, so changes apply without a rebuild
    '';
    source = mkOption {
      type = types.nullOr (types.strMatching "/.+");
      default = null;
      example = "/home/me/monolith-dotfiles";
      description = ''
        Absolute path of a checkout (git clone) of this repository, on the branch the system is built from.
        Required by dev.enable. A string, not a Nix path: a path would be copied into the store.
      '';
    };
    modules = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      example = [
        "quickshell"
        "hypr"
        "fastfetch"
      ];
      description = ''
        Which configurations come from the checkout: top-level folders of configs/.config ("quickshell",
        "hypr", "fish", "fastfetch"...) and the extra modules that use dev.link ("fetch"). null = all of them.
      '';
    };
    link = mkOption {
      type = types.functionTo types.anything;
      readOnly = true;
      internal = true;
      default =
        {
          module,
          path,
          store,
        }:
        if selected module then config.lib.file.mkOutOfStoreSymlink "${cfg.source}/${path}" else store;
      description = ''
        Source for one managed file: { module; path (in the repository); store (the normal source) } ->
        the checkout's file in dev mode for that module, else `store`.
      '';
    };
    active = mkOption {
      type = types.bool;
      readOnly = true;
      internal = true;
      default = on;
      description = "Whether dev mode is in effect.";
    };
  };

  config = lib.mkIf config.programs.monolith.enable {
    assertions = [
      {
        assertion = !cfg.enable || cfg.source != null;
        message = "programs.monolith.dev.enable needs programs.monolith.dev.source (the absolute path of a checkout of the repository).";
      }
    ];
    # a missing or wrong checkout would leave dangling links: say so at activation, change nothing
    home.activation.monolithDevCheck = lib.mkIf on (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -d ${lib.escapeShellArg cfg.source}/configs/.config ]; then
          echo "monolith: dev mode: ${cfg.source} is not a checkout of the repository (no configs/.config):" >&2
          echo "monolith: the configuration links point to missing files until it is (or dev.enable = false)" >&2
        else
          echo "monolith: dev mode: configuration linked from ${cfg.source}"
        fi
      ''
    );
  };
}
