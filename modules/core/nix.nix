{ ... }: {
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # Build as fast as possible: run one job per available core, and let each
    # build job use every core (cores = 0 -> all cores).
    max-jobs = "auto";
    cores = 0;
  };
}
