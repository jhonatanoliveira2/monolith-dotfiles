# Minimal machine used by `nix flake check` (checks.<system>.example-eval): evaluates the whole MONOLITH stack
# (desktop, boot, greeter, Home Manager for two users, one in development mode) without building or booting.
{ lib, ... }:
{
  system.stateVersion = "25.11";
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
  };
  users.users.alice = {
    isNormalUser = true;
    description = "Alice";
  };
  # a second user in development mode (configuration linked to a checkout), so its code is evaluated too
  users.users.bob.isNormalUser = true;

  monolith = {
    enable = true;
    homeUsers = [
      "alice"
      "bob"
    ];
    battery.chargeLimit = 80;
    boot.enable = true;
    greeter = {
      enable = true;
      defaultUser = "alice";
    };
    # a hybrid laptop (AMD integrated + NVIDIA), as the guided installer writes it
    nvidia = {
      enable = true;
      prime = {
        amdgpuBusId = "PCI:6:0:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "nvidia-settings"
      "nvidia-persistenced"
    ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.alice.home.stateVersion = "25.11";
  home-manager.users.bob = {
    home.stateVersion = "25.11";
    programs.monolith.dev = {
      enable = true;
      source = "/home/bob/monolith-dotfiles";
      modules = [
        "quickshell"
        "fastfetch"
      ];
    };
  };
}
