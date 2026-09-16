return {
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.5',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local builtin = require('telescope.builtin')
      
      -- 設定快捷鍵
      vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = '尋找檔案' })
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = '全域文字搜尋' })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = '開啟中的分頁' })
      vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = '查看說明文件' })
      
      require('telescope').setup({
        defaults = {
          mappings = {
            i = {
              ["<C-j>"] = "move_selection_next",
              ["<C-k>"] = "move_selection_previous",
            },
          },
          -- 讓搜尋視窗看起來更現代 (浮動邊框)
          sorting_strategy = "ascending",
          layout_config = {
            horizontal = { prompt_position = "top" },
          },
        },
      })
    end
  }
}
