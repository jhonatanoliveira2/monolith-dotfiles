# MONOLITH greeter: Quickshell (greeter/ + the shell's components) inside cage, on greetd.
#
# The wrapper is the safety net: if Quickshell fails to load or does not show its window within
# `startTimeout` seconds, the text greeter (tuigreet) takes over, so a broken greeter never locks anyone out.
# cage runs with -s (Ctrl+Alt+F<n> switches VTs) and the greeter offers a "Console" session (login shell).
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
  cfg = config.monolith.greeter;
  mpkgs = import ../../pkgs { inherit pkgs; };
  greeter = mpkgs.greeter;
  inherit (mpkgs) branding;
  sessions = config.services.displayManager.sessionData.desktops;
  xkb = config.services.xserver.xkb;
  tuigreet = pkgs.tuigreet or pkgs.greetd.tuigreet;

  keyboard =
    if cfg.keyboard != null then
      cfg.keyboard
    else
      xkb.layout + lib.optionalString (xkb.variant != "") " (${xkb.variant})";

  settings = {
    inherit (config.monolith) language;
    inherit (meta) version;
    inherit (cfg)
      defaultUser
      defaultSession
      allowOtherUsers
      clock24
      animations
      ;
    console = cfg.consoleSession;
    users = map (u: {
      inherit (u) name;
      description = u.description or "";
    }) (lib.filter (u: u.isNormalUser) (lib.attrValues config.users.users));
    sessionDirs = [ "${sessions}/share/wayland-sessions" ];
    background = if cfg.background == null then "" else "${cfg.background}";
    branding = "${branding}/${branding.dir}";
    sweepFrames = 36;
    statePath = "/var/lib/monolith-greeter/state.json";
    keyboard = keyboard;
  };
  settingsFile = pkgs.writeText "monolith-greeter.json" (builtins.toJSON settings);

  launcher = pkgs.writeShellScript "monolith-greeter" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnused
        pkgs.gnugrep
        pkgs.systemd
        pkgs.quickshell
        pkgs.cage
      ]
    }:$PATH
    export MONOLITH_GREETER_CONFIG=${settingsFile}
    export XDG_CACHE_HOME=/var/cache/monolith-greeter XDG_STATE_HOME=/var/cache/monolith-greeter/state
    export XDG_DATA_HOME=/var/cache/monolith-greeter/data
    export XKB_DEFAULT_LAYOUT=${lib.escapeShellArg xkb.layout} XKB_DEFAULT_VARIANT=${lib.escapeShellArg xkb.variant}
    export XKB_DEFAULT_OPTIONS=${lib.escapeShellArg xkb.options}
    export QT_QPA_PLATFORM=wayland

    run=$(mktemp -d)
    export MONOLITH_GREETER_READY=$run/ready
    cage -s -d -- sh -c 'qs -p "$1"; echo $? >"$2"' sh ${greeter}/${greeter.configDir} "$run/status" &
    pid=$!
    # watchdog: no window after the timeout = fall back below
    ( sleep ${toString cfg.startTimeout}; [ -e "$run/ready" ] || kill "$pid" 2>/dev/null ) &
    watchdog=$!
    wait "$pid"
    kill "$watchdog" 2>/dev/null
    code=$(cat "$run/status" 2>/dev/null || echo 1)
    rm -rf "$run"
    [ "$code" = 0 ] && exit 0
    ${
      if cfg.fallback then
        ''
          echo "monolith-greeter: the graphical greeter failed (status $code); starting the text greeter" >&2
          exec ${tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks \
            --greeting "MONOLITH · NixOS" --sessions ${sessions}/share/wayland-sessions
        ''
      else
        ''exit "$code"''
    }
  '';
in
{
  options.monolith.greeter = {
    enable = mkEnableOption "the MONOLITH greeter (Quickshell on greetd)";
    background = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Wallpaper behind the login (darkened). Null = black, continuous with the boot splash.";
    };
    defaultUser = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "User selected when no previous login is remembered.";
    };
    defaultSession = mkOption {
      type = types.str;
      default = "hyprland";
      description = "Session (.desktop file name without extension) selected when none is remembered.";
    };
    allowOtherUsers = mkOption {
      type = types.bool;
      default = true;
      description = "Let the user type a name not in the list (system / LDAP users).";
    };
    consoleSession = mkOption {
      type = types.bool;
      default = true;
      description = "Offer a \"Console\" session (login shell on the VT), useful for recovery.";
    };
    clock24 = mkOption {
      type = types.bool;
      default = true;
      description = "24-hour clock.";
    };
    animations = mkOption {
      type = types.bool;
      default = true;
      description = "Opening, light sweep and fade animations.";
    };
    keyboard = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Keyboard label in the footer (default: services.xserver.xkb layout and variant).";
    };
    startTimeout = mkOption {
      type = types.ints.positive;
      default = 25;
      description = "Seconds the graphical greeter has to show its window before the text greeter takes over.";
    };
    fallback = mkOption {
      type = types.bool;
      default = true;
      description = "Start tuigreet when the graphical greeter fails.";
    };
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${launcher}";
        user = "greeter";
      };
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/monolith-greeter 0755 greeter greeter -"
      "d /var/cache/monolith-greeter 0755 greeter greeter -"
    ];
    # fonts of the greeter (JetBrains Mono Nerd Font) without requiring monolith.enable
    fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  };
}
