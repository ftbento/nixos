{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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

    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    qylock = {
      url = "github:Darkkal44/qylock";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spotatui = {
      url = "github:LargeModGames/spotatui";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ambxst = {
      url = "github:Axenide/Ambxst";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: let
    users = import ./home/users.nix;
    pkgsFor = system: nixpkgs.legacyPackages.${system};
    cop3223cShell = pkgs: agenixCli: pkgs.mkShell {
      packages = with pkgs; [ gcc13 gnumake gdb valgrind openssh ] ++ [ agenixCli ];
      shellHook = ''
        if [ -d ~/nixos/secrets ]; then
          export COP3223C=$( (cd ~/nixos/secrets && agenix -d cop3223c.age 2>/dev/null) | tr -d '\n')
          if [ -n "$COP3223C" ]; then
            echo "COP 3223C loaded — $COP3223C ready"
          fi
        fi
      '';
    };
  in {
    nixosConfigurations = {
      radon = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs users; };
        modules = [
          {
            nixpkgs.hostPlatform = "x86_64-linux";
          }
          ./hosts/radon
        ];
      };

      argon = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs users; };
        modules = [
          {
            nixpkgs.hostPlatform = "x86_64-linux";
          }
          ./hosts/argon
        ];
      };
    };

    devShells.x86_64-linux.default = cop3223cShell (pkgsFor "x86_64-linux") inputs.agenix.packages.x86_64-linux.default;
  };
}