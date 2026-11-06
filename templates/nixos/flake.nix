{
  description = "My NixOS machine with the MONOLITH Shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    monolith = {
      url = "github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      monolith,
      ...
    }:
    {
      # rename "monolith-pc" to your hostname: sudo nixos-rebuild switch --flake .#monolith-pc
      nixosConfigurations.monolith-pc = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hardware-configuration.nix # copy yours from /etc/nixos
          ./configuration.nix
          home-manager.nixosModules.home-manager
          monolith.nixosModules.default
        ];
      };
    };
}
