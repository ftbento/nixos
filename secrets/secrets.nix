let
  # username = "ssh-ed25519 PUBLIC_KEY";
  benjidev_nixos-workstation = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGESGigvG8ZWWQIv5S+Kg7ECkbwFxSoBIX29tNh/BmZu benjidev@nixos-workstation";
in
{
  # "github-ssh-key.age".publicKeys = [ USERNAME-HOSTNAME ];
  "github-ftbento.age".publicKeys = [ benjidev_nixos-workstation ];
}

# paste the private key in the editor
# agenix -e SERVICE_NAME.age

# rekey all secrets with new recipients using private key in ~/.ssh
# agenix -r