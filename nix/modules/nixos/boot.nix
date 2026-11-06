# Boot experience: GRUB theme -> Plymouth splash -> greeter, one visual line (black, the NixOS snowflake in the
# Monolith style, the MONOLITH wordmark, a 2 px line: GRUB's timeout empties it, Plymouth fills it, the greeter
# starts from Plymouth's last frame).
#
# Never at the expense of recovery:
#   * the GRUB menu keeps the NixOS timeout and every generation; "e" / "c" still edit and open the console;
#   * a "recovery" specialisation (own boot entry) boots without splash, with kernel and systemd messages,
#     and without the graphical greeter (plain text login on the console);
#   * Esc in Plymouth shows the boot log; LUKS passwords are asked by Plymouth itself;
#   * nothing changes when another bootloader is used (the GRUB part only applies to GRUB).
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
    mkMerge
    mkDefault
    mkForce
    types
    ;
  cfg = config.monolith.boot;
  mpkgs = import ../../pkgs { inherit pkgs; };
  grubTheme = mpkgs.grub-theme.override {
    inherit (cfg.grub) resolution;
    inherit (config.monolith) language;
  };
  plymouthTheme = mpkgs.plymouth-theme;
in
{
  options.monolith.boot = {
    enable = mkEnableOption "the MONOLITH boot experience (GRUB theme, Plymouth splash, silent boot)";

    silent = mkOption {
      type = types.bool;
      default = true;
      description = "Hide kernel / systemd messages behind the splash (they stay in the journal; Esc shows them).";
    };

    plymouth.enable = mkOption {
      type = types.bool;
      default = true;
      description = "MONOLITH Plymouth theme (also asks for LUKS passwords).";
    };

    gpuModules = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "amdgpu" ];
      description = ''
        GPU kernel modules loaded in the initrd ("early KMS": i915 / xe, amdgpu, nouveau, virtio_gpu...). The splash
        then starts on the real display at once instead of on the firmware framebuffer, and is not interrupted
        when the driver loads later. The guided installer detects them. (Not for the proprietary NVIDIA driver.)
      '';
    };

    splashMinSeconds = mkOption {
      type = types.ints.between 0 15;
      default = 6;
      description = ''
        The splash stays at least until this many seconds after the kernel started, so the animation completes
        on very fast boots (NVMe). Never delays a boot that is already slower; 0 disables it.
      '';
    };

    seamless = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Keep the splash's last frame on screen until the MONOLITH greeter draws the same frame
        (plymouth quit --retain-splash). Only applies with monolith.greeter.enable.
      '';
    };

    grub = {
      enable = mkOption {
        type = types.bool;
        default = config.boot.loader.grub.enable;
        defaultText = lib.literalExpression "config.boot.loader.grub.enable";
        description = "MONOLITH GRUB theme (only meaningful when GRUB is the bootloader).";
      };
      resolution = mkOption {
        type = types.strMatching "[0-9]+x[0-9]+";
        default = "1920x1080";
        description = "Resolution the theme is drawn for; also GRUB's preferred mode (falls back to auto).";
      };
    };

    recovery = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Add a "recovery" boot entry (NixOS specialisation): no splash, verbose boot, no graphical greeter.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.silent {
      # (boot.initrd.verbose is gone with the scripted stage 1: the systemd initrd follows the kernel params)
      boot.consoleLogLevel = mkDefault 3;
      boot.kernelParams = [
        "quiet"
        "loglevel=3"
        "udev.log_level=3"
        "rd.udev.log_level=3"
        "systemd.show_status=auto"
        "rd.systemd.show_status=auto"
        "vt.global_cursor_default=0"
      ];
    })

    (mkIf cfg.plymouth.enable {
      boot.plymouth = {
        enable = true;
        theme = "monolith";
        themePackages = [ plymouthTheme ];
        font = "${plymouthTheme}/${plymouthTheme.font}";
      };
      # early KMS: the splash starts on the real display instead of the firmware framebuffer
      boot.initrd.kernelModules = cfg.gpuModules;
      # minimum splash time, then quit; with the MONOLITH greeter the last frame stays until it draws the same one
      systemd.services.plymouth-quit.serviceConfig.ExecStart = [
        ""
        "${pkgs.writeShellScript "monolith-plymouth-quit" ''
          up=$(${pkgs.coreutils}/bin/cut -d. -f1 /proc/uptime)
          wait=$((${toString cfg.splashMinSeconds} - up))
          [ "$wait" -gt 0 ] && ${pkgs.coreutils}/bin/sleep "$wait"
          exec ${config.boot.plymouth.package}/bin/plymouth quit ${
            lib.optionalString (cfg.seamless && config.monolith.greeter.enable) "--retain-splash"
          }
        ''}"
      ];
    })

    (mkIf cfg.grub.enable {
      boot.loader.grub = {
        theme = grubTheme;
        splashImage = "${grubTheme}/background.png";
        gfxmodeEfi = mkDefault "${cfg.grub.resolution},auto";
        gfxmodeBios = mkDefault "${cfg.grub.resolution},auto";
        # the kernel keeps GRUB's mode: no mode switch (flash) before Plymouth
        gfxpayloadEfi = mkDefault "keep";
        gfxpayloadBios = mkDefault "keep";
      };
    })

    (mkIf cfg.recovery {
      specialisation.recovery.configuration = {
        system.nixos.tags = [ "recovery" ];
        monolith.boot = {
          silent = mkForce false;
          plymouth.enable = mkForce false;
          recovery = mkForce false;
        };
        monolith.greeter.enable = mkForce false;
        boot.kernelParams = [ "systemd.show_status=true" ];
      };
    })
  ]);
}
