{ lib, ... }: {
  # Primary desktop user account. Persona modules (desktop profile, gaming,
  # ...) key their Home Manager blocks off this
  # instead of hardcoding a username, so a host picks its user here (or relies
  # on the default) and the user module (home/<user>.nix) follows it.
  options.workstation.user = lib.mkOption {
    type = lib.types.str;
    default = "benjidev";
    description = "Primary desktop user account used by the desktop persona modules";
  };
}