return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      -- flavour / 黑白色票依 i3 主題決定，見 lua/rice_theme.lua
      require("rice_theme").apply(true)
    end,
  },
}

