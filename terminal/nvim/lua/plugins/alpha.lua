return {
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      -- ==============================
      -- 🖍️ 設定霓虹粉紫顏色
      -- ==============================
      vim.api.nvim_set_hl(0, "AlphaHeaderColor", {
        fg = "#E81EE1",  -- 你指定的顏色
        bold = true,     -- 粗體讓字更明顯
      })

      -- ==============================
      -- 2. 設定 ASCII 文字標題 (NEOVIM)
      -- ==============================
      dashboard.section.header.val = {
        "                                                     ",
        "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
        "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
        "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
        "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
        "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
        "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
        "                                                     ",
      }

      -- 將顏色套用到標題
      dashboard.section.header.opts.hl = "AlphaHeaderColor"

      -- ==============================
      -- 3. 設定按鈕與選單
      -- ==============================
      dashboard.section.buttons.val = {
        dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
        dashboard.button("f", "󰈞  Find file", ":Telescope find_files <CR>"),
        dashboard.button("r", "󰄉  Recent files", ":Telescope oldfiles <CR>"),
        dashboard.button("s", "  Settings", ":e $MYVIMRC <CR>"),
        dashboard.button("q", "󰅚  Quit", ":qa<CR>"),
      }

      -- 設定底部文字 (選填)
      local stats = require("lazy").stats()
      local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
      dashboard.section.footer.val = "⚡ Neovim loaded " .. stats.count .. " plugins in " .. ms .. "ms"
      dashboard.section.footer.opts.hl = "Type"

      alpha.setup(dashboard.config)
    end,
  },
}
