{ pkgs, ... }: {
  # LibreOffice — full office suite (Writer, Calc, Impress, Draw, Base, Math).
  # The nixpkgs wrapper scans NIX_PROFILES for hunspell/hyphen dictionaries and
  # adds them to DICPATH, so the spellcheck/hyphenation packages below are
  # picked up automatically instead of needing per-app configuration.
  environment.systemPackages = with pkgs; [
    libreoffice-fresh
    hunspellDicts.en_US
    hyphenDicts.en_US
  ];
}
