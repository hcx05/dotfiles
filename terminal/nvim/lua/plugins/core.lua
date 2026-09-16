return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    priority = 1000,
    config = function()
      require("nvim-treesitter.config").setup({
        ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "query", "markdown" },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  { "nvim-lua/plenary.nvim" },
  { "nvim-telescope/telescope.nvim" },

  { "neovim/nvim-lspconfig" },

  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
}
