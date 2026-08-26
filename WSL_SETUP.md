# WSL + Nix + Agenix Setup (COP 3223C Dev Shell)

One-time setup to get the C development environment on a Windows laptop via WSL.

---

## Phase 1: Enable WSL2 on Windows

Open **PowerShell as Administrator**:

```powershell
wsl --install
```

Restart your laptop when prompted. Ubuntu will launch and ask you to create a Linux username/password.

---

## Phase 2: Install Nix in WSL

Open the **Ubuntu terminal**:

```bash
# Install Nix (multi-user, handles flakes + daemon)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Reload your shell
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Verify
nix --version
```

Enable flakes:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

---

## Phase 3: Install Git + Generate SSH Key

```bash
sudo apt update && sudo apt install git -y

# Generate key pair for agenix
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Copy this output (you need it in Phase 4)
cat ~/.ssh/id_ed25519.pub
```

---

## Phase 4: Add WSL Key to Agenix (on radon)

Switch to your **NixOS machine**. Edit `secrets/secrets.nix` and add the WSL public key:

```nix
let
  benjidev_radon = "ssh-ed25519 AAAAC3... benjidev@radon";
  benjidev_wsl   = "ssh-ed25519 AAAAC3... benjidev@wsl";  # paste from Phase 3
in
{
  "github-ftbento.age".publicKeys = [ benjidev_radon benjidev_wsl ];
  "cop3223c.age".publicKeys      = [ benjidev_radon benjidev_wsl ];
}
```

Create the COP 3223C secret (contains your full SSH connection string):

```bash
agenix -e cop3223c.age
# Paste: your_nid@eustis.eecs.ucf.edu
# Save and exit
```

Rekey all secrets so both keys can decrypt:

```bash
agenix -r
```

Commit and push:

```bash
git add secrets/ && git commit -m "add cop3223c secret + wsl key" && git push
```

---

## Phase 5: Clone and Use (in WSL)

```bash
git clone git@github.com:YOUR_USER/nixos.git ~/nixos
cd ~/nixos
nix develop
```

First run takes a while (downloads packages). After that it's instant.

The shellHook decrypts `secrets/cop3223c.age` using your SSH key and sets up the `eustis` alias.

```bash
# Test it
eustis
```

---

## Where things live

| Machine | What it has |
|---|---|
| **Radon (NixOS)** | Full NixOS module, agenix secrets decrypted at boot, fish alias |
| **WSL laptop** | Dev shell via `nix develop`, agenix CLI decrypts on shell entry, bash alias |
| **Both** | Same `secrets/cop3223c.age`, same `secrets.nix` with both public keys |
