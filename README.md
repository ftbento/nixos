# NixOS Configuration

My personal NixOS configurations with flake dependency management for managing multiple hosts with shared modules.

## Structure

```
.
├── hosts/
│   ├── _template/          # Template for new hosts
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── ...
├── modules/                # Shared NixOS modules
│   ├── default.nix         # Global modules
│   ├── core/               # Core system modules
│   ├── software/           # System software modules
│   ├── tweaks/             # System tweaks
│   ├── de/                 # Desktop environment modules
│   └── home/               # Shared home-manager modules
│       ├── default.nix     # Imports all shared home modules
│       ├── fish.nix        # Fish shell (myUser.fish.*)
│       ├── git.nix         # Git (myUser.git.*)
│       ├── kitty.nix       # Kitty terminal (myUser.kitty.*)
│       └── fastfetch/      # Fastfetch (myUser.fastfetch.*)
└── home-manager/           # User configurations
    ├── users.nix           # Export each user with host accessible names
    ├── benjidev.nix        # Thin user profile (sets myUser.* options)
    └── _template-username.nix  # User configuration template
```

## Adding a New Host

### For Existing Systems

1. **Copy the template:**
   ```bash
   cp -r hosts/_template hosts/<hostname>
   ```

2. **Replace hardware configuration:**
   ```bash
   cp -f /etc/nixos/hardware-configuration.nix hosts/<hostname>/hardware-configuration.nix
   ```

3. **Edit host configuration:**
   - Replace `<hostname>` with your actual hostname in `hosts/<hostname>/configuration.nix`
   - Update `system.stateVersion` to match your current NixOS version (check with `nixos-version`)
   - Add host-specific packages in the `environment.systemPackages` list in `hosts/<hostname>/configuration.nix`

### For Fresh Install

1. **Copy the template:**
   ```bash
   cp -r hosts/_template hosts/<hostname>
   ```

2. **Generate and replace hardware configuration:**
   After mounting filesystem to `/mnt`:
   ```bash
   sudo nixos-generate-config --root /mnt
   cp -f /mnt/etc/nixos/hardware-configuration.nix hosts/<hostname>/hardware-configuration.nix
   ```

3. **Edit host configuration:**
   - Copy /etc/nixos/configuration.nix as neccesary
   - Replace `<hostname>` with the actual hostname in `hosts/<hostname>/configuration.nix`
   - Update `system.stateVersion`
   - Add host-specific packages in the `environment.systemPackages` list in `hosts/<hostname>/configuration.nix`

### Next Steps

4. **Add host to flake.nix:**
   Add the host to the `nixosConfigurations` in `flake.nix`:
   ```nix
   nixosConfigurations = {
     <hostname> = nixpkgs.lib.nixosSystem {
       system = "x86_64-linux";
       specialArgs = { inherit inputs; };
       modules = [
         ./hosts/<hostname>/configuration.nix
       ];
     };
   };
   ```

5. **Deploy the configuration:**
   ```bash
   sudo nixos-rebuild switch --flake .#<hostname>
   ```

## Shared Modules

Add/remove modules in `modules/default.nix` to control what applies to all hosts,
per-host imports in configuration.nix

## User Management

Users are managed through thin profile files that import shared modules and set per-user options:

- System user creation and Home Manager settings are combined in `home-manager/<username>.nix`
- Shared home-manager modules live in `modules/home/` and expose options under the `myUser.<module>` namespace
- Users must be added to `home-manager/users.nix` to appear through `users.<username>`

### Adding a New User

1. **Copy the user configuration template:**
   ```bash
   cp home-manager/_template-username.nix home-manager/<username>.nix
   ```

2. **Register the user in `home-manager/users.nix`:**
   ```nix
   {
     <username> = ./<username>.nix;
   }
   ```

3. **Edit the user profile:**
   - Replace `<username>` and `<shell>` placeholders
   - Set `myUser.*` options to enable/configure shared modules (fish, git, kitty, fastfetch)
   - Add user-specific packages in the `home.packages` list

4. **Add the user to a host:**
   ```nix
   # hosts/<hostname>/configuration.nix
   imports = [
     ./hardware-configuration.nix
     ../../modules/default.nix
     users.<username>
   ];
   ```
