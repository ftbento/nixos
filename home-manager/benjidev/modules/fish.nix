{ config, pkgs, ... }: {
  programs.fish = {
    enable = true; # primary global shell set in user.nix
    generateCompletions = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting

      # start tmux, etc.
    '';
    plugins = [
      # Enable a plugin (here grc for colorized command output) from nixpkgs
      { name = "grc"; src = pkgs.fishPlugins.grc.src; }
    ];

    # TODO: make global somehow?
    shellAliases = {
      nhswitch = "nh os switch ~/nixos";       
      nhboot = "nh os boot  ~/nixos";
      nhupdate = "nix flake update --flake ~/nixos && nh os switch  ~/nixos"; 
      nhclean = "nh clean all"; 

      ff = "fastfetch";

      ".." = "cd ..";
    };
  };
}