# NixOS module of the MONOLITH Shell. Options live under `monolith`:
#   monolith.enable           desktop: Hyprland, the services the shell talks to, fonts, portals, polkit
#   monolith.boot.enable      GRUB theme (when GRUB is the bootloader), Plymouth splash, silent boot, recovery entry
#   monolith.greeter.enable   Quickshell greeter on greetd (text greeter fallback)
# The per-user part (configs, packages) is the Home Manager module, shared automatically when Home Manager
# runs as a NixOS module; `monolith.homeUsers` turns it on for the listed users.
{ self, meta }:
{
  imports = [
    (import ./system.nix { inherit self meta; })
    (import ./boot.nix { inherit meta; })
    (import ./greeter.nix { inherit meta; })
  ];
}
