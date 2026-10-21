{ config, lib, pkgs, ... }:

{
  options.home.nvim.enable = lib.mkEnableOption "Neovim configuration with treesitter and common tools";

  config = lib.mkIf config.home.nvim.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withRuby = false;
      withPython3 = false;
      withNodeJs = false;

      extraPackages = with pkgs; [
        # Common LSPs / tools - adjust as needed
        nil # Nix LSP
        pkgs.nixfmt # Nix formatter
        lua-language-server
        stylua
        ripgrep
        fd
        git
        tree-sitter
        gcc
      ];

      # Treesitter grammars from nixpkgs (offline-ready, includes the nix parser).
      plugins = with pkgs.vimPlugins; [ nvim-treesitter.withAllGrammars ];

      initLua = ''
        -- Basic settings
        vim.g.mapleader = " "
        vim.g.maplocalleader = " "

        vim.opt.number = true
        vim.opt.relativenumber = true
        vim.opt.mouse = "a"
        vim.opt.clipboard = "unnamedplus"
        vim.opt.showmode = false

        vim.opt.expandtab = true
        vim.opt.shiftwidth = 2
        vim.opt.tabstop = 2
        vim.opt.softtabstop = 2
        vim.opt.smartindent = true

        vim.opt.wrap = false
        vim.opt.signcolumn = "yes"
        vim.opt.updatetime = 250
        vim.opt.timeoutlen = 300
        vim.opt.cursorline = true

        vim.opt.splitright = true
        vim.opt.splitbelow = true
        vim.opt.ignorecase = true
        vim.opt.smartcase = true

        -- Keymaps
        vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "NetRW" })
        vim.keymap.set("n", "<leader>h", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

        -- Lazy.nvim bootstrap if not present
        local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
        if not vim.loop.fs_stat(lazypath) then
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

        -- Plugins
        require("lazy").setup({
          {
            "nvim-treesitter/nvim-treesitter-textobjects",
            dependencies = { "nvim-treesitter/nvim-treesitter" },
          },
          {
            "nvim-lua/plenary.nvim",
            lazy = true,
          },
          {
            "nvim-telescope/telescope.nvim",
            tag = "0.1.8",
            dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope-fzf-native.nvim" },
            config = function()
              require("telescope").setup({})
              pcall(require("telescope").load_extension, "fzf")
            end,
          },
          {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make",
            lazy = true,
          },
          {
            "stevearc/oil.nvim",
            opts = {},
            dependencies = { "nvim-tree/nvim-web-devicons" },
          },
          {
            "nvim-tree/nvim-web-devicons",
            lazy = true,
          },
          {
            "neovim/nvim-lspconfig",
            config = function()
              -- Neovim 0.11+ LSP API
              vim.lsp.config('nil_ls', {})
              vim.lsp.config('lua_ls', {
                settings = {
                  Lua = {
                    diagnostics = { globals = { "vim" } },
                    workspace = { checkThirdParty = false },
                  },
                },
              })
              vim.lsp.enable({ 'nil_ls', 'lua_ls' })
            end,
          },
          {
            "hrsh7th/nvim-cmp",
            dependencies = {
              "hrsh7th/cmp-nvim-lsp",
              "hrsh7th/cmp-buffer",
              "hrsh7th/cmp-path",
              "L3MON4D3/LuaSnip",
              "saadparwaiz1/cmp_luasnip",
            },
            config = function()
              local cmp = require("cmp")
              cmp.setup({
                snippet = {
                  expand = function(args)
                    require("luasnip").lsp_expand(args.body)
                  end,
                },
                sources = cmp.config.sources({
                  { name = "nvim_lsp" },
                  { name = "luasnip" },
                }, {
                  { name = "buffer" },
                }),
                mapping = cmp.mapping.preset.insert({
                  ["<C-Space>"] = cmp.mapping.complete(),
                  ["<CR>"] = cmp.mapping.confirm({ select = true }),
                  ["<C-e>"] = cmp.mapping.abort(),
                }),
              })
            end,
          },
        })

        -- Treesitter highlighting (grammars provided by nix)
        vim.api.nvim_create_autocmd("FileType", {
          callback = function(args)
            pcall(vim.treesitter.start, args.buf)
          end,
        })
      '';
    };


  };
}
