return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      -- 跟 catppuccin.lua 同一個設定，見 lua/rice_theme.lua
      require("rice_theme").apply(true)
    end,
  },
}

