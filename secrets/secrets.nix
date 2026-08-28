let
  # username = "ssh-ed25519 PUBLIC_KEY";
  benjidev_radon = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGESGigvG8ZWWQIv5S+Kg7ECkbwFxSoBIX29tNh/BmZu benjidev@radon";
  benjidev_elitebook_wsl   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4kXVbiNiirKZkljHnD+t15Hd9iTocub0TbKU8s8m00 benjidev@Ben-Elitebook";

  argon = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHwQD95sH8vf07H/67xLHN1+ziv+RgWmS5/+dHhU5w0G root@argon";
in
{
  # "github-ssh-key.age".publicKeys = [ USERNAME-HOSTNAME ];
  "github-ftbento.age".publicKeys = [ benjidev_radon benjidev_elitebook_wsl argon ];
  "cop3223c.age".publicKeys = [ benjidev_radon benjidev_elitebook_wsl];

  "couchdb-env.age".publicKeys = [ benjidev_radon benjidev_elitebook_wsl argon ];
}

# paste the private key in the editor
# agenix -e SERVICE_NAME.age

# rekey all secrets with new recipients using private key in ~/.ssh
# agenix -r