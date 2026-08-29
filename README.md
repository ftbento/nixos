# NixOS Configuration

My personal NixOS configurations. A flake-based setup using reusable **profiles**
(personas) composed of fine-grained modules, so that adding a new device means
picking the right profile(s) rather than copying/replicating config.

## Structure

```
.
├── flake.nix                  # Flake entry point, inputs, nixosConfigurations
├── hosts/                     # Per-host config (hardware + host-specific bits)
│   ├── radon/                 # Personal workstation
│   ├── argon/                 # Home server (headless)
│   └── _template/             # Template for new hosts
├── profiles/                  # Reusable personas (the key layer)
│   ├── core.nix               # Shared by EVERY device (barebones: flakes, secrets,
│   │                          #   home-manager base, tailscale, nh, man)
│   └── desktop.nix            # Interactive desktop (Hyprland, gaming, ambxst,
│                              #   stylix, sddm/qylock) — imported by radon, laptop, ...
├── modules/                   # Fine-grained NixOS modules (opt-in via import)
│   ├── core/                  #   core, nix, systemd, agenix, home-manager,
│   │                          #   nh, tailscale, graphics, pipewire, bluetooth,
│   │                          #   stylix, gpu/{amd,nvidia}
│   ├── software/              #   gaming, flatpak, fuzzel
│   ├── shell/                 #   ambxst
│   ├── tweaks/                #   man
│   └── wm/                    #   hyprland, hyprlock
├── home/                      # Home-manager user profiles + shared HM modules
│   ├── users.nix              # User registry (users.<username> = ./<username>.nix)
│   ├── benjidev.nix           # User profile
│   ├── _template-username.nix # User configuration template
│   └── modules/               # Shared home-manager modules (fish, git, kitty, ...)
│       ├── default.nix
│       ├── fish.nix           # concrete aliases baked in
│       ├── git.nix            # concrete identity baked in
│       ├── kitty.nix          # concrete settings baked in
│       ├── yazi.nix
│       └── fastfetch/
├── config/                    # Static dotfiles copied via xdg.configFile
└── secrets/                   # Age-encrypted secrets (agenix)
```

## The two profiles

| Profile     | Applies to            | Contents |
|-------------|-----------------------|----------|
| `core.nix`  | Every device          | nix flakes, agenix, home-manager base, nh, tailscale, man, timezone/locale |
| `desktop.nix` | Interactive machines | graphics, pipewire, bluetooth, stylix, systemd (display-manager tweak), hyprland, hyprlock, ambxst, gaming, fuzzel, flatpak, sddm/qylock, desktop home-manager, user account |

Each host imports `core.nix` plus the appropriate persona, then the host file
keeps only what is truly host-specific. Headless servers (like argon) are
single-purpose machines, so their entire server stack (SSH, firewall, docker,
containers) lives directly in the host file instead of a profile.

**What stays in the host file (not the profile):**
- Hostname, `system.stateVersion`
- Hardware: `hardware-configuration.nix`, GPU driver (`gpu/amd.nix` / `gpu/nvidia.nix`)
- Bootloader (grub theme vs systemd-boot), mountpoints
- Hyprland **monitors and keybinds** (multi-monitor layout — host specific)
- Server host bits: static IP, authorized keys, agenix secrets, the full server
  stack (SSH, firewall, docker, containers — unique per server)

This means adding a laptop that mirrors radon is just: copy `hosts/radon`, swap
`hardware-configuration.nix` + GPU driver + hostname.

## Adding a New Machine

1. **Copy the template:**
   ```bash
   cp -r hosts/_template hosts/<hostname>
   ```
2. **Generate/replace hardware configuration:**
   ```bash
   sudo nixos-generate-config --root /mnt   # fresh install
   cp -f /etc/nixos/hardware-configuration.nix hosts/<hostname>/hardware-configuration.nix
   ```
3. **Edit `hosts/<hostname>/default.nix`:**
   - Set `networking.hostName`
   - Import the right profile: `profiles/desktop.nix` (interactive) — headless
     servers skip this and define their server stack directly in the host file
   - Import the host GPU driver (`gpu/amd.nix` / `gpu/nvidia.nix`)
   - Set host-specific packages, bootloader, mountpoints, monitors/keybinds
   - Set `system.stateVersion`
4. **Register the host in `flake.nix`:**
   ```nix
   <hostname> = nixpkgs.lib.nixosSystem {
     system = "x86_64-linux";
     specialArgs = { inherit inputs users; };
     modules = [ ./hosts/<hostname> ];
   };
   ```
5. **Deploy:**
   ```bash
   sudo nixos-rebuild switch --flake .#<hostname>
   ```

## Shared home-manager modules

The home-manager modules (`home/modules/*`) expose a simple `home.<name>.enable`
option. Because you have a single user, concrete values (fish aliases, git
identity, kitty settings, yazi/fastfetch layout) are **baked directly into each
module file** rather than configured per-user. A user profile just enables them:

```nix
home-manager.users.benjidev = {
  imports = [ ./modules ];
  home.git.enable = true;
  home.fish = {
    enable = true;
    # extraAliases for secret-dependent aliases (need NixOS config scope)
    extraAliases = { cop3223c = "ssh $(cat ${config.age.secrets.cop3223c.path})"; };
  };
};
```

If you later add a second user, either bake their own values in a copy of the
module, or reintroduce per-user options — don't hardcode values for more than
one user.

## Theming (Stylix)

Global theming is provided by [Stylix](https://github.com/nix-community/stylix)
via `modules/core/stylix.nix` (imported by the desktop profile):

- Colors come from a base16 scheme (`catppuccin-mocha` by default); switch schemes by changing `stylix.base16Scheme` or derive colors from a wallpaper with `stylix.image`.
- Applies to supported targets automatically: kitty, Hyprland (window borders/hyprlock/hyprpaper), GTK/Qt, fuzzel, swaync, btop, and more.
- The custom GRUB theme (`targets.grub.enable = false`) and per-monitor hyprlock wallpapers are preserved.
- Hyprland and hyprlock configs are managed through Home Manager so Stylix can theme them.
