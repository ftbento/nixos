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
│   └── ...
└── home-manager/           # User configurations
    ├── users/              # Individual user files
    │   └── username.nix    # Combined system + Home Manager config
    │   └── default.nix     # Export each user with host accessible names
    │   └── _template.nix   # User configuration template
    ├── modules/            # Shared home-manager modules
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

Users are managed through combined system and Home Manager configuration:
- System user creation and Home Manager settings are combined in `home-manager/<username>/default.nix`
- Users must be added to `users.nix` to appear through `users.username`

### Adding a New User

1. **Copy the user configuration template:**
   ```bash
   cp home-manager/_template-username home-manager/<username>
   ```

2. **Add the user to a host:**
   ```nix
   # hosts/<hostname>/configuration.nix
   imports = [
     ./hardware-configuration.nix
     ../../modules/default.nix
     users.<username>
   ];
   ```
