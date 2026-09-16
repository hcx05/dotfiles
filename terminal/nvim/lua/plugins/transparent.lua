return {
  {
    "xiyaowong/transparent.nvim",
    config = function()
      require("transparent").setup({
        extra_groups = { -- 額外把這些也拆了，保證全透
          "NormalFloat", 
          "NvimTreeNormal",
          "CmpNormal",
        },
      })
      -- 預設開啟
      vim.cmd("TransparentEnable")
    end,
  },
}
