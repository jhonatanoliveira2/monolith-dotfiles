{
  description = "MONOLITH Shell for NixOS: Hyprland + Quickshell desktop, boot splash, greeter and GRUB theme";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      # metadata of this checkout, shown by Settings > System / Update (nix.json, see nix/modules/home.nix)
      meta = import ./nix/meta.nix { inherit self lib; };
    in
    {
      overlays.default = final: _prev: {
        monolith = import ./nix/pkgs {
          pkgs = final;
          rev = self.rev or "";
        };
      };

      packages = forAllSystems (
        pkgs:
        let
          # rev: the installer writes the same source (branch / commit) into the configuration it generates
          set = import ./nix/pkgs {
            inherit pkgs;
            rev = self.rev or "";
          };
        in
        {
          inherit (set)
            shell
            scripts
            nothp
            branding
            plymouth-theme
            grub-theme
            greeter
            installer
            ;
          default = set.shell;
        }
      );

      # sudo nix --extra-experimental-features "nix-command flakes" run github:<repo>#install
      apps = forAllSystems (pkgs: {
        install = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.installer}/bin/monolith-install";
          meta.description = "Guided NixOS + MONOLITH installer (run from the NixOS installer ISO)";
        };
      });

      homeManagerModules = rec {
        monolith = import ./nix/modules/home.nix { inherit meta; };
        default = monolith;
      };

      nixosModules = rec {
        monolith = import ./nix/modules/nixos { inherit self meta; };
        default = monolith;
      };

      templates.default = {
        path = ./templates/nixos;
        description = "NixOS + Home Manager configuration with the MONOLITH Shell, boot splash, greeter and GRUB theme";
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      # `nix flake check`: every package builds and a full example system evaluates (no VM, no system build)
      checks = forAllSystems (
        pkgs:
        let
          example = lib.nixosSystem {
            inherit (pkgs.stdenv.hostPlatform) system;
            modules = [
              home-manager.nixosModules.home-manager
              self.nixosModules.default
              ./nix/checks/example-host.nix
            ];
          };
        in
        builtins.removeAttrs self.packages.${pkgs.stdenv.hostPlatform.system} [ "default" ]
        // {
          # the context is dropped: evaluating the system is the test, building it is not
          example-eval = pkgs.writeText "monolith-example-eval" (
            builtins.unsafeDiscardStringContext example.config.system.build.toplevel.drvPath
          );
        }
      );
    };
}
