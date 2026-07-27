{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: let
    users = import ./home-manager/users.nix;
  in {
    nixosConfigurations = {
      kvm-test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs users; };
        modules = [
          ./hosts/kvm-test/configuration.nix
        ];
      };
      benjidev-nixos = nixpkgs.lib.nixosSystem {
 	system = "x86_64-linux";
	specialArgs = { inherit inputs users; };
	modules = [
	  ./hosts/benjidev-nixos/configuration.nix
	];
      };
      # hostname = nixpkgs.lib.nixosSystem {
      #   system = "x86_64-linux";
      #   specialArgs = { inherit inputs users; };
      #   modules = [
      #     ./hosts/hostname/configuration.nix
      #   ];
      # };
    };
  };
}
