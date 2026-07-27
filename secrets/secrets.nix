let
  # username = "ssh-ed25519 PUBLIC_KEY";
  benjidev-kvm-test = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPerJClod7OwLvQXBJDlDq/avyV5l2nqW/RH2jqhfqbQ benjidev@kvm-test";
in
{
  # "github-ssh-key.age".publicKeys = [ USERNAME-HOSTNAME ];
  "github-ssh-key.age".publicKeys = [ benjidev-kvm-test ];
}

# paste the private key in the editor
# agenix -e SERVICE_NAME.age

# rekey all secrets with new recipients using private key in ~/.ssh
# agenix -r