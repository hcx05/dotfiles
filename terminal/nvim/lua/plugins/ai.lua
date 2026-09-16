return {
  -- Copilot 補全
  {
    "github/copilot.vim",
    lazy = false,
    config = function()
      vim.g.copilot_no_tab_map = true
      vim.keymap.set("i", "<C-j>", 'copilot#Accept("<CR>")', {
        expr = true,
        replace_keycodes = false,
      })
      vim.keymap.set("i", "<C-]>", "<Plug>(copilot-next)")
      vim.keymap.set("i", "<M-[>", "<Plug>(copilot-previous)")
    end,
  },

  -- Copilot Chat（選代碼問問題）
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    build = "make utf8",
    dependencies = {
      "github/copilot.vim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("CopilotChat").setup({
        show_help = true,
        window = {
          layout = "vertical",
          width = 0.4,
        },
      })
    end,
    keys = {
      { "<leader>cc", "<cmd>CopilotChatToggle<CR>", mode = { "n", "v" }, desc = "開啟聊天" },
      { "<leader>ce", "<cmd>CopilotChatExplain<CR>", mode = "v", desc = "解釋代碼" },
      { "<leader>cm", "<cmd>CopilotChatOptimize<CR>", mode = "v", desc = "優化代碼" },
      { "<leader>cf", "<cmd>CopilotChatFix<CR>", mode = "v", desc = "修 Bug" },
      { "<leader>ct", "<cmd>CopilotChatTests<CR>", mode = "v", desc = "生成測試" },
  },
  },
}
