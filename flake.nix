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
    cop3223cShell = pkgs: pkgs.mkShell {
      packages = with pkgs; [ gcc gnumake gdb valgrind openssh agenix ];
      shellHook = ''
        if [ -f secrets/cop3223c.age ]; then
          EUSTIS_TARGET=$(agenix -d secrets/cop3223c.age 2>/dev/null | tr -d '\n')
          if [ -n "$EUSTIS_TARGET" ]; then
            alias eustis="ssh $EUSTIS_TARGET"
            echo "COP 3223C loaded — eustis alias ready"
          else
            echo "Warning: Could not decrypt cop3223c.age (missing private key in ~/.ssh/)"
          fi
        fi
      '';
    };
  in {
    nixosConfigurations = {
      radon = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs users; };
        modules = [
          ./hosts/radon
        ];
      };
    };

    devShells.x86_64-linux.default = cop3223cShell (pkgsFor "x86_64-linux");
  };
}