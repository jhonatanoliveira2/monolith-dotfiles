# Minimal machine used by `nix flake check` (checks.<system>.example-eval): evaluates the whole MONOLITH stack
# (desktop, boot, greeter, Home Manager for one user) without building or booting anything.
{ ... }:
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

  monolith = {
    enable = true;
    homeUsers = [ "alice" ];
    battery.chargeLimit = 80;
    boot.enable = true;
    greeter = {
      enable = true;
      defaultUser = "alice";
    };
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.alice.home.stateVersion = "25.11";
}
