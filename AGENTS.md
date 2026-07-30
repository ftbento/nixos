# AGENTS.md

## Repo Overview

Personal NixOS configuration flake. Manages one host (`nixos-workstation`) with shared NixOS modules and Home Manager user modules. Uses agenix for secrets and `nh` to build/manage generation output.

## Key Paths

- `flake.nix` — flake entrypoint; defines `nixosConfigurations.nixos-workstation` and inputs (nixpkgs `nixos-26.05`, home-manager `release-26.05`, zen-browser, agenix)
- `hosts/nixos-workstation/` — the only host config (contains `crt-amber/` and `tsushima/` boot theme dirs)
- `modules/` — shared NixOS modules (core, software, tweaks, wm, de)
- `home/` — Home Manager user configs (`benjidev.nix` + `users.nix`)
- `home/modules/` — shared Home Manager modules exposing `myUser.*` options (fish, git, kitty, hyprland, fastfetch)
- `secrets/` — agenix-encrypted secrets (`.age` files) + `secrets.nix` with public key mappings

## Deployment

```bash
sudo nixos-rebuild switch --flake .#nixos-workstation
```

## Adding a New Host

1. `cp -r hosts/_template hosts/<hostname>`
2. Copy `hardware-configuration.nix` from the target system
3. Edit `hosts/<hostname>/configuration.nix` (set hostname, stateVersion, packages)
4. Add the host to `nixosConfigurations` in `flake.nix`
5. Rebuild

## Adding a New User

1. `cp home/_template-username.nix home/<username>.nix`
2. Add entry to `home/users.nix`
3. Edit the user profile (set `myUser.*` options, packages, SSH identity)
4. Reference `users.<username>` in the host's `configuration.nix` imports

## Secrets (Agenix)

- Encrypt: `agenix -e secrets/<name>.age`
- Rekey (add new host): `agenix -r` (requires private key at `~/.ssh/id_ed25519`)
- Declare in host config: `age.secrets."<name>" = { file = ../secrets/<name>.age; };`
- Decrypted path on target: `/run/agenix/<name>`

## Conventions

- Home Manager shared modules use the `myUser.<module>` option namespace
- NixOS shared modules are imported via `../../modules` in host configs
- `system.stateVersion` must match the nixpkgs channel version (`26.05` at time of writing)
- `allowUnfree = true` is set in the host config for unfree packages (e.g., vscode, zen-browser)
- Boot themes are stored as git-tracked subdirectories inside the host dir

## Nix Validation

No CI or test suite. Validate changes with:

```bash
nix build .#nixos-workstation  # build the top-level config
```

## Notes

- The README refers to `home-manager/` and `modules/home/` but the actual directories are `home/` and `home/modules/` respectively
- The `nh` tool is used for garbage collection and generation management (aliases defined in fish shell config)