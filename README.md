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
│   └── desktop.nix            # Interactive desktop (Hyprland, gaming, noctalia,
│                              #   stylix, sddm/qylock) — imported by radon, laptop, ...
├── modules/                   # Fine-grained NixOS modules (opt-in via import)
│   ├── core/                  #   core, nix, systemd, agenix, home-manager,
│   │                          #   nh, tailscale, graphics, pipewire, bluetooth,
│   │                          #   stylix, user, gpu/{amd,nvidia}
│   ├── software/              #   gaming, flatpak
│   ├── services/              #   monitoring (Prometheus/Grafana + agents),
│   │                          #   proxmox (native PVE), dashboard (Homepage
│   │                          #   service landing page behind nginx)
│   ├── tweaks/                #   man
│   └── wm/                    #   hyprland
├── home/                      # Home-manager user profiles + shared HM modules
│   ├── users.nix              # User registry (users.<username> = ./<username>.nix)
│   ├── benjidev.nix           # User profile (imported per-host via users.<username>)
│   ├── _template-username.nix # User configuration template
│   └── modules/               # Shared home-manager modules (fish, git, kitty, ...)
│       ├── default.nix
│       ├── fish.nix           # concrete aliases baked in
│       ├── git.nix            # git identity (parameterized; defaults to benjidev)
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
| `desktop.nix` | Interactive machines | graphics, pipewire, bluetooth, stylix, systemd (display-manager tweak), hyprland/hypridle/hyprlock, noctalia, gaming, flatpak, rustdesk, vpn, sddm/qylock, desktop home-manager (lock screen: hyprlock) |

Each host imports `core.nix` plus the appropriate persona, then the host file
keeps only what is truly host-specific. Headless servers (like argon) are
single-purpose machines, so their entire server stack (SSH, firewall, docker,
containers) lives directly in the host file instead of a profile.

The **user account is imported per-host**, not by the desktop profile: a desktop
host imports its user module (e.g. `users.benjidev`) and sets `workstation.user`
(see `modules/core/user.nix`) so the persona's Home Manager blocks key off that
name instead of a hardcoded username.

**What stays in the host file (not the profile):**
- Hostname, `system.stateVersion`
- The user import (`users.benjidev` or a new one) + `workstation.user`
- Hardware: `hardware-configuration.nix`, GPU driver (`gpu/amd.nix` / `gpu/nvidia.nix` — each pulls in graphics automatically)
- Bootloader (grub theme vs systemd-boot), mountpoints
- Hyprland **monitors and keybinds** (multi-monitor layout — host specific)
- Hyprlock **backgrounds/wallpapers** and Noctalia **wallpaper + desktop widgets** (monitor- and layout-specific)
- Server host bits: static IP, authorized keys, agenix secrets, the full server
  stack (SSH, firewall, docker, containers — unique per server)

This means adding a laptop that mirrors radon is just: copy `hosts/radon`, swap
`hardware-configuration.nix` + GPU driver + `workstation.user` + hostname, and
adjust the host display bits (host.lua, wallpapers/widgets).

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
   - Import the host GPU driver (`gpu/amd.nix` / `gpu/nvidia.nix`; either pulls
     in the base graphics stack itself)
   - Import a user module and set `workstation.user` (desktop hosts): `users.benjidev`
   - Set host display bits: `hypr/host.lua` (monitors/workspaces), Noctalia
     backgrounds, Noctalia wallpapers/widgets
   - Set host-specific packages, bootloader, mountpoints
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
option. Generic starter values (fish aliases, git identity, kitty settings,
yazi/fastfetch layout) are baked into each module file; user-specific values
(git identity, machine-specific aliases) are set via options instead. A user
profile just enables them:

```nix
home-manager.users.benjidev = {
  imports = [ ./modules ];
  home.git = {
    enable = true;
    userName = "ftbento";
    userEmail = "ftbento@users.noreply.github.com";
  };
  home.fish = {
    enable = true;
    # machine- or secret-dependent aliases (need NixOS config scope for secrets)
    extraAliases = {
      argon = "ssh argon";                                  # radon-only
      cop3223c = "ssh $(cat ${config.age.secrets.cop3223c.path})";
    };
  };
};
```

A second user can be added by copying `home/_template-username.nix`, filling in
their own `home.git.userName`/`userEmail` and `extraAliases`, registering the
file in `home/users.nix`, and importing it per-host — no copy of a module needed.

## Theming (Stylix)

Global theming is provided by [Stylix](https://github.com/nix-community/stylix)
via `modules/core/stylix.nix` (imported by the desktop profile):

- Colors come from a base16 scheme (`catppuccin-mocha` by default); switch schemes by changing `stylix.base16Scheme` or derive colors from a wallpaper with `stylix.image`.
- Applies to supported targets automatically: kitty, Hyprland (window borders), GTK/Qt, btop, and more.
- The custom GRUB theme is preserved (`targets.grub.enable = false`).
- Hyprland is configured through the Lua API. Locks are handled by hyprlock (hypridle after idle, Super+Escape, Noctalia Lock); the SDDM login screen is themed by qylock. Not Stylix.
