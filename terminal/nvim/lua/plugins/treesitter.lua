return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      -- 加入 pcall (protected call) 確保即便套件還沒載入完也不會報紅字
      local status, ts = pcall(require, "nvim-treesitter.configs")
      if not status then return end

      ts.setup({
        ensure_installed = { "lua", "python", "cpp", "c", "vim", "vimdoc", "query", "markdown" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  }
}
