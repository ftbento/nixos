{
  benjidev = ./benjidev.nix;

  # Second/other users: copy home/_template-username.nix to home/<username>.nix,
  # then register it here and import it per-host:
  #   sara = ./sara.nix;
}