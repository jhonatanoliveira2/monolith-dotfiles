# Home Manager module: the MONOLITH Shell for one user.
#
# Every file of configs/.config is linked from the Nix store (the same tree the Arch installer copies), except:
#   * ~/.config/quickshell        -> the shell package (one link to the whole directory);
#   * mutableFiles                -> files the programs themselves rewrite (btop, micro, nvim, nwg-look, GTK
#                                    settings, wpgtk, HyprMod). They are copied once and kept writable; a later
#                                    version replaces them only if the user never changed them (sha256 stamp).
# Generated state stays where the shell writes it (~/.config/hypr/generated, ~/.local/state/quickshell-monolith,
# ~/.cache), so the Settings app works exactly as on Arch.
{ meta }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
  cfg = config.programs.monolith;
  mpkgs = import ../pkgs { inherit pkgs; };
  lists = import ../packages.nix pkgs;

  # configs/.config as one store path (its name must not start with a dot)
  root = ../../configs/.config;
  src = builtins.path {
    path = root;
    name = "monolith-config";
  };
  relative = p: lib.removePrefix (toString root + "/") (toString p);
  ignored =
    rel:
    lib.hasPrefix "quickshell/" rel
    || lib.elem (baseNameOf rel) [
      ".gitkeep"
      ".gitignore"
    ];
  isMutable = rel: lib.any (m: rel == m || (lib.hasSuffix "/" m && lib.hasPrefix m rel)) cfg.mutableFiles;
  files = lib.filter (rel: !ignored rel) (map relative (lib.filesystem.listFilesRecursive root));
  linked = lib.filter (rel: !isMutable rel) files;
  seeded = lib.filter isMutable files;

  manifest = pkgs.writeText "monolith-seed-manifest" (
    lib.concatMapStrings (rel: "${src}/${rel}\t${rel}\n") seeded
  );
  seed = pkgs.writeShellScript "monolith-seed" ''
    # $1 = manifest ("<store file>\t<path under ~/.config>" per line)
    set -u
    cfgdir=''${XDG_CONFIG_HOME:-$HOME/.config}
    state=''${XDG_STATE_HOME:-$HOME/.local/state}/monolith/seeded
    sum() { ${pkgs.coreutils}/bin/sha256sum <"$1" | ${pkgs.coreutils}/bin/cut -d' ' -f1; }
    put() { # put <src> <dst> <stamp> <sum>
      ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$2")" "$(${pkgs.coreutils}/bin/dirname "$3")"
      mode=644; [ -x "$1" ] && mode=755
      ${pkgs.coreutils}/bin/install -m "$mode" "$1" "$2" && printf '%s\n' "$4" >"$3"
    }
    while IFS="$(printf '\t')" read -r from rel; do
      [ -n "$rel" ] || continue
      dst=$cfgdir/$rel stamp=$state/$rel.sha256 new=$(sum "$from")
      # linked by an older generation (or by hand) into the store: replace the link with a writable copy
      if [ -L "$dst" ]; then
        case $(${pkgs.coreutils}/bin/readlink "$dst") in /nix/store/*) ${pkgs.coreutils}/bin/rm -f "$dst" ;; esac
      fi
      if [ ! -e "$dst" ]; then
        put "$from" "$dst" "$stamp" "$new"
      elif [ -f "$stamp" ] && [ "$(sum "$dst")" = "$(${pkgs.coreutils}/bin/cat "$stamp")" ] && [ "$new" != "$(${pkgs.coreutils}/bin/cat "$stamp")" ]; then
        put "$from" "$dst" "$stamp" "$new"   # never edited since it was seeded: follow the new version
      fi
    done <"$1"
  '';

  wallpapers = builtins.path {
    path = ../../wallpapers;
    name = "monolith-wallpapers";
  };
in
{
  options.programs.monolith = {
    enable = mkEnableOption "the MONOLITH Shell (Hyprland + Quickshell desktop)";

    optionalPackages = mkOption {
      type = types.bool;
      default = true;
      description = "Install the optional programs of packages.txt (RNNoise, cava, pavucontrol, btop, neovim...).";
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "More packages for the session.";
    };

    apps = mkOption {
      type = types.attrsOf types.str;
      default = {
        browser = "firefox";
      };
      example = {
        browser = "zen-browser";
        ide = "codium";
        terminal = "ghostty";
      };
      description = ''
        Programs started by the key binds (keys of hypr/modules/programs.lua: terminal, fileManager, ide,
        browser, lockScreen). Written to ~/.config/monolith/programs.lua, which overrides the defaults.
      '';
    };
    browserPackage = mkOption {
      type = types.nullOr types.package;
      default = pkgs.firefox;
      defaultText = lib.literalExpression "pkgs.firefox";
      description = "Package providing apps.browser (null if installed some other way).";
    };

    updateCommand = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "nix flake update monolith --flake ~/nixos && sudo nixos-rebuild switch --flake ~/nixos";
      description = "Run in a terminal by Settings > Update > Update now (the shell has no clone to pull on NixOS).";
    };

    mutableFiles = mkOption {
      type = types.listOf types.str;
      default = [
        "btop/btop.conf"
        "hypr/hyprland-gui.lua"
        "micro/"
        "nvim/"
        "nwg-look/config"
        "gtk-3.0/settings.ini"
        "gtk-4.0/settings.ini"
        "wpg/"
      ];
      description = ''
        Paths under ~/.config (a trailing "/" means the whole folder) copied instead of linked, because a
        program writes them. Later versions replace a copy only when the user has not changed it.
      '';
    };

    wallpapers = mkOption {
      type = types.bool;
      default = true;
      description = "Copy the repository wallpapers into ~/Pictures/Wallpapers (existing files are never replaced).";
    };
    gtk = mkOption {
      type = types.bool;
      default = true;
      description = "Set the GTK theme Materia-dark and the dark colour scheme (dconf), as the Arch installer does.";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      lists.required
      ++ lib.optionals cfg.optionalPackages lists.optional
      ++ [
        mpkgs.scripts
        mpkgs.nothp
      ]
      ++ lib.optional (cfg.browserPackage != null) cfg.browserPackage
      ++ cfg.extraPackages;

    fonts.fontconfig.enable = true;

    xdg.configFile =
      lib.listToAttrs (map (rel: lib.nameValuePair rel { source = "${src}/${rel}"; }) linked)
      // {
        "quickshell".source = "${mpkgs.shell}/${mpkgs.shell.configDir}";
        "monolith/programs.lua".text = "-- Generated by Home Manager (programs.monolith.apps)\nreturn ${lib.generators.toLua { } cfg.apps}\n";
        "monolith/nix.json".text = builtins.toJSON {
          managed = true;
          inherit (meta)
            version
            rev
            shortRev
            lastModified
            repo
            branch
            ;
          updateCommand = if cfg.updateCommand == null then "" else cfg.updateCommand;
        };
      };

    # the shell and the binds call these by full path
    home.file = lib.listToAttrs (
      map (name: lib.nameValuePair ".local/bin/${name}" { source = "${mpkgs.scripts}/bin/${name}"; }) [
        "monolith-theme"
        "monolith-vscode"
        "wallpaper-menu"
      ]
    );

    home.activation.monolithFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      ''
        run ${seed} ${manifest}
        run mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Videos/wallpaper-live" "''${XDG_CONFIG_HOME:-$HOME/.config}/hypr/generated"
      ''
      + lib.optionalString cfg.wallpapers ''
        for f in ${wallpapers}/static/*; do
          [ -e "$f" ] && [ ! -e "$HOME/Pictures/Wallpapers/''${f##*/}" ] && run install -m 644 "$f" "$HOME/Pictures/Wallpapers/"
        done
        for f in ${wallpapers}/live/*; do
          [ -e "$f" ] && [ ! -e "$HOME/Videos/wallpaper-live/''${f##*/}" ] && run install -m 644 "$f" "$HOME/Videos/wallpaper-live/"
        done
        true
      ''
    );

    dconf.settings = mkIf cfg.gtk {
      "org/gnome/desktop/interface" = {
        gtk-theme = "Materia-dark";
        color-scheme = "prefer-dark";
      };
    };
  };
}
