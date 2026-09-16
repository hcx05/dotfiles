return {
  {
    "rcarriga/nvim-notify",
    config = function()
      local notify = require("notify")
      notify.setup({
        background_colour = "#000000",
        fps = 30,
        render = "default",
        stages = "fade_in_slide_out", -- 淡入滑出效果
        timeout = 3000,               -- 顯示 3 秒後自動消失
      })
      -- 強制讓 Neovim 所有的通知都經由這個插件顯示
      vim.notify = notify
    end,
  },
}
