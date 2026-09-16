return {
  -- 圖示支援
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- 檔案樹
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    init = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
    end,
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 30,
          side = "left",
        },
      })
      -- 設定快捷鍵 <leader>e
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })
    end
  }
}
