# NVIDIA GPUs (monolith.nvidia): the driver with its open kernel modules (Turing / GTX 16xx and newer; `open = false`
# for older cards), KMS for Hyprland, suspend that keeps the video memory, VA-API, and PRIME offload on a hybrid
# laptop (the integrated GPU draws the desktop, `nvidia-offload <app>` runs an app on the NVIDIA one). The guided
# installer detects the card and writes these options. The driver's userspace is unfree: list it in
# nixpkgs.config.allowUnfreePredicate (the installer does; see docs/nixos.md). Hyprland's NVIDIA variables are set
# at login by hypr/modules/environment.lua, which detects the GPU itself.
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
    mkDefault
    types
    ;
  cfg = config.monolith.nvidia;
  busId = mkOption {
    type = types.str;
    default = "";
    description = "PCI bus ID, as `PCI:<bus>:<device>:<function>` in decimal (lspci shows it in hex).";
  };
  hybrid = cfg.prime.nvidiaBusId != "" && (cfg.prime.intelBusId != "" || cfg.prime.amdgpuBusId != "");
in
{
  options.monolith.nvidia = {
    enable = mkEnableOption "the NVIDIA driver (open kernel modules, KMS, suspend, VA-API, PRIME offload on hybrid laptops)";

    open = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Open kernel modules (NVIDIA's own, required from driver 590). They need a Turing card or newer
        (GTX 16xx, RTX 20xx and later); set false for Maxwell / Pascal / Volta, with a legacy `package`.
      '';
    };

    package = mkOption {
      type = types.package;
      default = config.boot.kernelPackages.nvidiaPackages.stable;
      defaultText = lib.literalExpression "config.boot.kernelPackages.nvidiaPackages.stable";
      description = "Driver package (another branch: `config.boot.kernelPackages.nvidiaPackages.<name>`).";
    };

    prime = {
      nvidiaBusId = busId // {
        example = "PCI:1:0:0";
      };
      intelBusId = busId // {
        example = "PCI:0:2:0";
      };
      amdgpuBusId = busId // {
        example = "PCI:6:0:0";
      };
    };
  };

  config = mkIf (config.monolith.enable && cfg.enable) {
    hardware.graphics.enable = true;
    # also on Wayland: this is what loads the driver and its kernel modules
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      inherit (cfg) open package;
      modesetting.enable = true; # nvidia-drm.modeset=1: Hyprland needs KMS
      nvidiaSettings = mkDefault false; # an X11 tool
      # suspend / hibernate keep the video memory (nvidia-suspend, nvidia-hibernate, nvidia-resume)
      powerManagement.enable = mkDefault true;
      # hybrid laptop: the NVIDIA GPU turns off while unused (Turing and newer)
      powerManagement.finegrained = mkDefault (hybrid && cfg.open);
      prime = mkIf hybrid {
        offload.enable = true;
        offload.enableOffloadCmd = true; # nvidia-offload <app>
        nvidiaBusId = cfg.prime.nvidiaBusId;
        intelBusId = mkIf (cfg.prime.intelBusId != "") cfg.prime.intelBusId;
        amdgpuBusId = mkIf (cfg.prime.amdgpuBusId != "") cfg.prime.amdgpuBusId;
      };
    };
    hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ]; # VA-API (LIBVA_DRIVER_NAME=nvidia)
  };
}
