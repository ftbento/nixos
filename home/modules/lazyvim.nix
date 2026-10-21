{ config, lib, pkgs, ... }:

# LazyVim-based Neovim, opt-in per host (import this file in the host's
# home-manager block and set home.lazyvim.enable = true). Intentionally NOT
# imported by home/modules/default.nix — same pattern as tmux.nix — so hosts
# can pick either this or the simpler shared home.nvim config.
{
  options.home.lazyvim.enable =
    lib.mkEnableOption "LazyVim Neovim with C++/OpenGL and Nix tooling";

  config = lib.mkIf config.home.lazyvim.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withRuby = false;
      withPython3 = false;
      withNodeJs = false;

      extraPackages = with pkgs; [
        clang-tools # clangd + clang-format (LazyVim extras.lang.clangd)
        nil # nix LSP (LazyVim extras.lang.nix)
        nixfmt # nix formatter used by extras.lang.nix
        gcc # treesitter parser compilation fallback
        git # lazy.nvim bootstrap + plugin sync
        ripgrep # live_grep pickers
        fd # find_files pickers
        gnumake # native plugin builds (telescope-fzf-native)
        tree-sitter
      ];

      # Treesitter grammars from nixpkgs: highlighting for C++, GLSL and Nix
      # works immediately, before lazy.nvim has cloned anything.
      plugins = with pkgs.vimPlugins; [ nvim-treesitter.withAllGrammars ];

      initLua = ''
        -- Leader keys must be set before lazy.nvim loads any mappings.
        vim.g.mapleader = " "
        vim.g.maplocalleader = "\\"

        -- GLSL shader files get the glsl treesitter parser (C-family rules).
        vim.filetype.add({
          extension = {
            vert = "glsl",
            frag = "glsl",
            geom = "glsl",
            tesc = "glsl",
            tese = "glsl",
            comp = "glsl",
          },
        })

        -- Bootstrap lazy.nvim (LazyVim starter pattern).
        local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
        if not vim.uv.fs_stat(lazypath) then
          vim.fn.system({
            "git",
            "clone",
            "--filter=blob:none",
            "https://github.com/folke/lazy.nvim.git",
            "--branch=stable",
            lazypath,
          })
        end
        vim.opt.rtp:prepend(lazypath)

        require("lazy").setup({
          spec = {
            -- LazyVim distribution + the extras for this environment.
            { "LazyVim/LazyVim", import = "lazyvim.plugins" },
            { import = "lazyvim.plugins.extras.lang.clangd" },
            { import = "lazyvim.plugins.extras.lang.nix" },

            -- Parsers are provided by nixpkgs (plugins.nvim-treesitter
            -- .withAllGrammars above), so never download/compile them at
            -- runtime; vim.treesitter finds them on the runtimepath.
            {
              "nvim-treesitter/nvim-treesitter",
              opts = {
                ensure_installed = {},
                sync_install = false,
                auto_install = false,
              },
            },

            -- On NixOS the system binaries come from nix (clang-tools, nil),
            -- so never let mason try to install them (it fails for nil_ls).
            -- clangd also needs --query-driver to discover the nix gcc
            -- wrapper's implicit include paths (libstdc++, GL/GLEW headers).
            {
              "neovim/nvim-lspconfig",
              opts = {
                servers = {
                  clangd = {
                    mason = false,
                    cmd = {
                      "clangd",
                      "--background-index",
                      "--clang-tidy",
                      "--header-insertion=iwyu",
                      "--completion-style=detailed",
                      "--function-arg-placeholders",
                      "--fallback-style=llvm",
                      "--query-driver=/nix/store/*/bin/g++,/nix/store/*/bin/gcc",
                    },
                  },
                  nil_ls = { mason = false },
                },
              },
            },
          },
          install = { missing = true }, -- plugin sync on first start (needs network)
          checker = { enabled = false },
          change_detection = { enabled = true, notify = false },
          ui = { border = "rounded" },
        })
      '';
    };
  };
}
