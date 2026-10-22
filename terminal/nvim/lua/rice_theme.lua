-- 依目前 i3 主題設定 catppuccin 顏色。
-- ~/.config/rice/terminal-style（由 ~/.config/rice/apply-theme.sh 寫入）：
--   classic（purple / green，或檔案不存在）= 原本的 catppuccin-mocha
--   mono                                     = 同一套 catppuccin，色票全部換成黑白灰
-- 切換主題時 switch-theme.sh 會叫已經開著的 nvim 重新套用；視窗重新取得焦點時
-- (FocusGained) 也會再檢查一次，所以開著的 nvim 不用重開。
local M = {}

local style_file = vim.fn.expand("~/.config/rice/terminal-style")

-- catppuccin mocha 的每個色票都換成灰階：越重要越亮，錯誤保留紅色
-- (跟 i3 的 URGENT 一樣，每個主題都是同一個紅)。
local mono_palette = {
  rosewater = "#E0E0E0",
  flamingo = "#CCCCCC",
  pink = "#B8B8B8",
  mauve = "#FFFFFF", -- keywords
  red = "#FF1855", -- errors
  maroon = "#D6D6D6",
  peach = "#CFCFCF", -- numbers / constants
  yellow = "#DADADA", -- types, warnings
  green = "#A6A6A6", -- strings
  teal = "#BDBDBD",
  sky = "#9E9E9E", -- operators
  sapphire = "#C2C2C2",
  blue = "#F0F0F0", -- functions
  lavender = "#D9D9D9",
  text = "#E8E8E8",
  subtext1 = "#C8C8C8",
  subtext0 = "#A8A8A8",
  overlay2 = "#8A8A8A",
  overlay1 = "#737373",
  overlay0 = "#5C5C5C", -- comments
  surface2 = "#464646",
  surface1 = "#333333",
  surface0 = "#232323",
  base = "#0A0A0A",
  mantle = "#060606",
  crust = "#000000",
}

local function read_style()
  local f = io.open(style_file, "r")
  if not f then
    return "classic"
  end
  local style = (f:read("*l") or ""):gsub("%s+", "")
  f:close()
  return style ~= "" and style or "classic"
end

M.style = nil

-- 套用目前的主題；跟上一次一樣就什麼都不做（除非 force）。
function M.apply(force)
  local style = read_style()
  if style == M.style and not force then
    return
  end
  M.style = style

  local opts = { flavour = "mocha" }
  if style == "mono" then
    opts.color_overrides = { mocha = mono_palette }
    -- 沒有顏色可以分辨語法，改用粗體 / 斜體補
    opts.styles = { comments = { "italic" }, keywords = { "bold" }, conditionals = { "bold" } }
  end
  require("catppuccin").setup(opts)
  vim.cmd.colorscheme("catppuccin-mocha")
end

vim.api.nvim_create_autocmd("FocusGained", {
  group = vim.api.nvim_create_augroup("RiceTheme", { clear = true }),
  callback = function()
    M.apply()
  end,
})

return M
