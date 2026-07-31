# NixOS Configuration

My personal NixOS configurations with flake dependency management for managing multiple hosts with shared modules.

## Structure

```
.
├── flake.nix               # Flake entry point, inputs, nixosConfigurations
├── hosts/                  # Per-host NixOS configurations
│   ├── _template/          # Template for new hosts
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
├── modules/                # Shared NixOS modules
│   ├── default.nix         # Global module imports
│   ├── core/               # Core system modules (incl. stylix.nix, home-manager.nix)
│   ├── software/           # System software modules
│   ├── tweaks/             # System tweaks
│   ├── de/                 # Desktop environment modules
│   └── wm/                 # Window manager modules (hyprland.nix)
├── home/                   # User home-manager configurations
│   ├── users.nix           # User registry (users.<username> = ./<username>.nix)
│   ├── benjidev.nix        # User profile
│   ├── _template-username.nix  # User configuration template
│   └── modules/            # Shared home-manager modules (myUser.* options)
│       ├── default.nix
│       ├── fish.nix        # Fish shell
│       ├── git.nix         # Git
│       ├── kitty.nix       # Kitty terminal
│       ├── yazi.nix        # Yazi file manager
│       ├── quickshell.nix  # Quickshell panel
│       └── fastfetch/      # Fastfetch
├── config/                 # Static dotfiles copied via xdg.configFile
│   ├── hypr/               # hyprpaper.conf (hyprland/hyprlock are HM-managed)
│   └── quickshell/
└── secrets/                # Age-encrypted secrets (agenix)
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
   - Replace `<hostname>` with your actual hostname in `hosts/<hostname>/default.nix`
   - Update `system.stateVersion` to match your current NixOS version (check with `nixos-version`)
   - Add host-specific packages in the `environment.systemPackages` list in `hosts/<hostname>/default.nix`

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
   - Replace `<hostname>` with the actual hostname in `hosts/<hostname>/default.nix`
   - Update `system.stateVersion`
   - Add host-specific packages in the `environment.systemPackages` list in `hosts/<hostname>/default.nix`

### Next Steps

4. **Add host to flake.nix:**
   Add the host to the `nixosConfigurations` in `flake.nix`:
   ```nix
   nixosConfigurations = {
     <hostname> = nixpkgs.lib.nixosSystem {
       system = "x86_64-linux";
       specialArgs = { inherit inputs users; };
       modules = [
         ./hosts/<hostname>
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

- System user creation and Home Manager settings are combined in `home/<username>.nix`
- Shared home-manager modules live in `home/modules/` and expose options under the `myUser.<module>` namespace
- Users must be added to `home/users.nix` to appear through `users.<username>`

### Adding a New User

1. **Copy the user configuration template:**
   ```bash
   cp home/_template-username.nix home/<username>.nix
   ```

2. **Register the user in `home/users.nix`:**
   ```nix
   {
     <username> = ./<username>.nix;
   }
   ```

3. **Edit the user profile:**
   - Replace `<username>` and `<shell>` placeholders
   - Set `myUser.*` options to enable/configure shared modules (fish, git, kitty, yazi, fastfetch)
   - Add user-specific packages in the `home.packages` list

4. **Add the user to a host:**
   ```nix
   # hosts/<hostname>/default.nix
   imports = [
     ./hardware-configuration.nix
     ../../modules/default.nix
     users.<username>
   ];
   ```

## Theming (Stylix)

Global theming is provided by [Stylix](https://github.com/nix-community/stylix) via `modules/core/stylix.nix`:

- Colors come from a base16 scheme (`catppuccin-mocha` by default); switch schemes by changing `stylix.base16Scheme` or derive colors from a wallpaper with `stylix.image`.
- Applies to supported targets automatically: kitty, Hyprland (window borders/hyprlock/hyprpaper), GTK/Qt, fuzzel, swaync, btop, and more.
- The custom GRUB theme (`targets.grub.enable = false`) and per-monitor hyprlock wallpapers are preserved.
- Hyprland and hyprlock configs are managed through Home Manager (`wayland.windowManager.hyprland` / `programs.hyprlock` in `home/benjidev.nix`) so Stylix can theme them.
