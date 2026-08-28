**Phase 1: Boot & Live Environment Setup**

1. Boot server `argon` into the NixOS Minimal Live ISO.


2. Set a temporary installer password and start SSH:

```bash
sudo passwd
sudo systemctl start sshd

```

3. Connect remotely from your workstation:

```bash
ssh root@IP

```

---

**Phase 2: Partitioning (2GB Boot) & Mounting**

1. Wipe disk and create a new GPT partition table:

```bash
sudo parted /dev/nvme0n1 --script mklabel gpt

```

2. Create a 2GB EFI boot partition and allocate the remaining space to root:

```bash
sudo parted /dev/nvme0n1 --script mkpart ESP fat32 1MiB 2049MiB
sudo parted /dev/nvme0n1 --script set 1 boot on
sudo parted /dev/nvme0n1 --script mkpart primary ext4 2049MiB 100%

```

3. Format the partitions:

```bash
sudo mkfs.vfat -F32 -n boot /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2

```

4. Mount the filesystems:

```bash
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot

```

---

**Phase 3: Hardware Config & Host Keys**

1. Generate the base hardware configuration:

```bash
sudo nixos-generate-config --root /mnt

```

*Copy `/mnt/etc/nixos/hardware-configuration.nix` into your repository at `./hosts/argon/hardware-configuration.nix`.*

2. Pre-generate `argon`'s host SSH key for Agenix:

```bash
sudo mkdir -p /mnt/etc/ssh
sudo ssh-keygen -t ed25519 -N "" -f /mnt/etc/ssh/ssh_host_ed25519_key
cat /mnt/etc/ssh/ssh_host_ed25519_key.pub

```

3. On your workstation (`radon` or `wsl`):

* Add `argon`'s public host key to `secrets.nix`.
* Rekey secrets:

```bash
agenix -r

```

* Push updated repository changes to GitHub.

---

**Phase 4: Installation via Flake**

1. Clone your configuration repository into the mounted filesystem:

```bash
git clone https://github.com/ftbento/nixos /mnt/etc/nixos

```

2. Run the Flake installation:

```bash
sudo nixos-install --flake /mnt/etc/nixos#argon

```

3. Reboot the server:

```bash
sudo reboot

```

---

**Phase 5: Post-Install Verification & Data Restore**

1. SSH into the deployed server using port 205:

```bash
ssh -p 205 root@10.8.90.205

```

2. Authenticate Tailscale:

```bash
sudo tailscale up

```