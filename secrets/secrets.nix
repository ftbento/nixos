let
  # username = "ssh-ed25519 PUBLIC_KEY";
  benjidev_radon = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGESGigvG8ZWWQIv5S+Kg7ECkbwFxSoBIX29tNh/BmZu benjidev@radon";
in
{
  # "github-ssh-key.age".publicKeys = [ USERNAME-HOSTNAME ];
  "github-ftbento.age".publicKeys = [ benjidev_radon ];
}

# paste the private key in the editor
# agenix -e SERVICE_NAME.age

# rekey all secrets with new recipients using private key in ~/.ssh
# agenix -r