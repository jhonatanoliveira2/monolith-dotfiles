{ self, meta }:
{
  config,
  lib,
  pkgs,
  options,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkMerge
    mkDefault
    types
    ;
  cfg = config.monolith;

  # Settings > Battery > charge limit: the shell stores the value here (services/Battery.qml, via pkexec);
  # this applies it at every boot. /etc/udev is generated from the configuration on NixOS.
  applyChargeLimit = pkgs.writeShellScript "monolith-charge-limit" ''
    f=/var/lib/monolith/charge-limit
    [ -r "$f" ] || exit 0
    n=$(cat "$f")
    case $n in "" | *[!0-9]*) exit 0 ;; esac
    for b in /sys/class/power_supply/BAT*; do
      e="$b/charge_control_end_threshold"; s="$b/charge_control_start_threshold"
      [ -w "$e" ] || continue
      if [ -w "$s" ] && [ "$(cat "$s")" -ge "$n" ]; then echo $((n - 5)) >"$s"; fi
      echo "$n" >"$e"
    done
  '';
in
{
  options.monolith = {
    enable = mkEnableOption "the MONOLITH desktop (Hyprland, the services the shell uses, fonts, portals)";

    language = mkOption {
      type = types.enum [
        "pt"
        "en"
      ];
      default = "pt";
      description = "Language of the boot menu, splash prompts and greeter (the shell has its own setting).";
    };

    homeUsers = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "alice" ];
      description = "Users that get programs.monolith.enable through the Home Manager NixOS module.";
    };

    battery.chargeLimit = mkOption {
      type = types.nullOr (types.ints.between 50 100);
      default = null;
      example = 80;
      description = ''
        Initial battery charge limit (%), on laptops that support charge_control_end_threshold. The value set
        later in Settings > Battery wins (it is kept in /var/lib/monolith/charge-limit).
      '';
    };

    gpuScreenRecorder = mkOption {
      type = types.bool;
      default = true;
      description = "Install gpu-screen-recorder with its capabilities (SUPER+R recording bind).";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = mkDefault true;
      };
      programs.hyprlock.enable = true; # also its PAM service
      programs.dconf.enable = true;
      programs.fish.enable = mkDefault true;
      programs.gpu-screen-recorder.enable = mkIf cfg.gpuScreenRecorder true;

      security.polkit.enable = true; # pkexec: storage cleanup, charge limit
      security.rtkit.enable = mkDefault true;
      services.pipewire = {
        enable = mkDefault true;
        alsa.enable = mkDefault true;
        pulse.enable = mkDefault true;
        wireplumber.enable = mkDefault true;
      };
      networking.networkmanager.enable = mkDefault true;
      hardware.bluetooth.enable = mkDefault true;
      services.blueman.enable = mkDefault true;
      services.upower.enable = true;
      services.power-profiles-daemon.enable = mkDefault true;
      services.udisks2.enable = true;
      services.gvfs.enable = mkDefault true; # trash (gio) and Nautilus
      services.accounts-daemon.enable = mkDefault true; # profile pictures shown by the greeter

      xdg.portal = {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; # file chooser next to the Hyprland portal
      };

      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        jetbrains-mono
        material-icons
      ];

      systemd.tmpfiles.rules = [
        "d /var/lib/monolith 0755 root root -"
      ]
      ++ lib.optional (
        cfg.battery.chargeLimit != null
      ) "f /var/lib/monolith/charge-limit 0644 root root - ${toString cfg.battery.chargeLimit}";

      systemd.services.monolith-charge-limit = {
        description = "Battery charge limit chosen in the MONOLITH settings";
        wantedBy = [ "multi-user.target" ];
        after = [
          "local-fs.target"
          "systemd-tmpfiles-setup.service"
        ];
        unitConfig.ConditionPathExists = "/var/lib/monolith/charge-limit";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = applyChargeLimit;
        };
      };

      warnings = lib.optional (
        cfg.homeUsers != [ ] && !(options ? home-manager)
      ) "monolith.homeUsers is set but the Home Manager NixOS module is not imported: enable programs.monolith in your Home Manager configuration instead.";
    }

    # Home Manager as a NixOS module: share ours, enable it for monolith.homeUsers
    (lib.optionalAttrs (options ? home-manager) {
      home-manager.sharedModules = [ self.homeManagerModules.default ];
      home-manager.users = lib.genAttrs cfg.homeUsers (_: {
        programs.monolith.enable = mkDefault true;
      });
    })
  ]);
}
