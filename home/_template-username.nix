# Template for a SECOND/OTHER user account (not the primary desktop user).
#
# The primary user is special: its name is set per-host via `workstation.user`
# (modules/core/user.nix), and the desktop persona (profiles/desktop.nix) keys
# its Home Manager / user bits off that name. Any OTHER user owns its own
# username here — no option, just the files you already see.
#
# To create a real user from this template:
#   1.  cp home/_template-username.nix home/<username>.nix
#   2.  Fill in <username>, the shell, groups, secrets and HM bits below.
#   3.  Register it:  home/users.nix  →  `<username> = ./<username>.nix;`
#   4.  Import it per-host (like the primary user):
#         hosts/<hostname>/default.nix → imports = [ ... users.<username> ];
#
# NOTE: the shared HM modules in home/modules/* expose simple options
# (home.git.userName/userEmail, home.fish.extraAliases) and generic starter
# values, so they're safe to enable for any user — override here as needed.

{ config, pkgs, lib, inputs, ... }: let
  username = "<username>";
  pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {
  # System-level user creation (pick your shell: fish, zsh, bash, ...)
  programs.fish.enable = true;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ]; # drop "wheel" for non-admin
    shell = pkgs.fish;
  };

  # secrets (agenix) — a user file can own secrets, e.g. a GitHub deploy key.
  # First add the recipient public key to secrets/secrets.nix (publicKeys),
  # then declare the decrypt here:
  # age.identityPaths = [ "/home/${username}/.ssh/id_ed25519" ];
  # age.secrets."github-${username}" = {
  #   file = ../secrets/github-${username}.age;
  #   owner = username;
  # };

  # SDDM/accountsservice avatar for this user (desktop hosts) — place the image
  # at config/<username>.png in the repo:
  # systemd.tmpfiles.rules = [
  #   "f+ /var/lib/AccountsService/users/${username} 0600 root root - [User]\\nIcon=/var/lib/AccountsService/icons/${username}\\n"
  #   "L+ /var/lib/AccountsService/icons/${username} - - - - ${../config}/${username}.png"
  # ];

  # Home Manager configuration for this user. Shared modules are opt-in via
  # the home.<name>.enable options; the desktop persona's HM config (noctalia,
  # cava, hypr cursor, ...) is tied to `workstation.user` in profiles/desktop.nix
  # and does NOT apply here.
  home-manager.users.${username} = {
    imports = [
      ./modules
    ];

    home = {
      username = username;
      homeDirectory = "/home/${username}";
      stateVersion = "26.05";

      packages = with pkgs; [
        # Generic modules are safe to enable for any user:
      ];
    };

    home.fastfetch.enable = true;
    home.kitty.enable = true;
    home.yazi.enable = true;
    # home.fish.enable = true;   # starter aliases are generic (nh*, ff, cd ..);
    #                            # keep machine-specific aliases (e.g. argon ssh)
    #                            # in extraAliases on the host that owns them.
    home.git = {
      enable = true;
      # userName = "<their name>";    # defaults to "ftbento" — set your own
      # userEmail = "<their email>";  # defaults to ftbento's email
    };
  };
}