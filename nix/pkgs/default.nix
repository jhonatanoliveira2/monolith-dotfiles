# Every derivation of the flake. Sources come straight from the shared tree (configs/, branding/, greeter/):
# nothing is copied or duplicated for NixOS, the same files serve the Arch installer.
{ pkgs }:
let
  inherit (pkgs) callPackage;
in
rec {
  # the Quickshell configuration (configs/.config/quickshell), linked as ~/.config/quickshell
  shell = callPackage ./shell.nix { };
  # ~/.local/bin helpers (wallpaper-menu, monolith-theme, monolith-vscode) with their tools on PATH
  scripts = callPackage ./scripts.nix { };
  # prctl(PR_SET_THP_DISABLE) launcher used by scripts/start.sh instead of python3
  nothp = callPackage ./nothp.nix { };
  # logo, wordmark and animation frames rendered from branding/*.svg (one source for every boot stage)
  branding = callPackage ./branding.nix { };
  plymouth-theme = callPackage ./plymouth-theme.nix { inherit branding; };
  grub-theme = callPackage ./grub-theme.nix { inherit branding; };
  # Quickshell greeter for greetd (greeter/ + shared components of the shell)
  greeter = callPackage ./greeter.nix { inherit branding shell; };
}
