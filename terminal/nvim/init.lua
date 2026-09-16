-- 1. 確保 Leader 鍵放在最上面
vim.g.mapleader = " "

-- 2. 基本選項設定
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"

-- 3. Bootstrap lazy.nvim (自動安裝套件管理器)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
})

-- 5. LSP 設定 (Neovim 0.10+ 原生寫法)
-- 取得 CMP 提供的 capabilities 以支援補全
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Clangd 設定
vim.lsp.config("clangd", {
  cmd = { "clangd" },
  filetypes = { "c", "cpp", "objc", "objcpp" },
  root_markers = { ".clangd", "compile_commands.json", ".git" },
  capabilities = capabilities,
})
vim.lsp.enable("clangd")

-- Pyright 設定
vim.lsp.config("pyright", {
  capabilities = capabilities,
})
vim.lsp.enable("pyright")

-- 6. 自訂快捷鍵
-- 一鍵編譯/執行 (C / C++ / Python)
vim.keymap.set("n", "<leader>r", function()
  vim.cmd("w") -- 先存檔
  local filename = vim.fn.expand("%:t:r")
  local ext = vim.fn.expand("%:e")

  if ext == "c" then
    -- 只編譯，不執行，成功後 echo 提示
    vim.cmd("TermExec cmd='gcc % -o " .. filename .. " && echo \"✅ C Build Success\"'")
  elseif ext == "cpp" then
    -- 同理，只用 g++ 編譯
    vim.cmd("TermExec cmd='g++ % -o " .. filename .. " && echo \"✅ C++ Build Success\"'")
  elseif ext == "py" then
    -- Python 不需要編譯，你可以保留執行或者純粹做語法檢查
    vim.cmd("TermExec cmd='python3 %'")
  else
    print("❌ Unsupported file type: " .. ext)
  end

end, { noremap = true, silent = false, desc = "Save and Run" })

-- 顯示 Hover 資訊 (診斷彈窗)
vim.keymap.set("n", "K", vim.diagnostic.open_float, { noremap = true, silent = true })

-- 系統剪貼簿複製 (支援 Normal 與 Visual 模式)
vim.keymap.set({ "n", "v" }, "<Leader>y", '"+y', { noremap = true, silent = true })

-- Python Ruff 格式化
vim.keymap.set("n", "<leader>f", function()
  if vim.bo.filetype == "python" then
    vim.cmd("w")
    vim.cmd("!ruff format %")
    vim.cmd("edit!")
    
    -- 如果有安裝 notify，彈出漂亮通知
    local n_status, notify = pcall(require, "notify")
    if n_status then
      notify("Ruff: 格式化完成 ✨", "info", { title = "Python Format" })
    end
  else
    print("Formatting currently set up for Python only")
  end
end, { noremap = true, silent = false })

-- 7. 診斷 (Diagnostics) UI 設定
vim.diagnostic.config({
  virtual_text = false,
  float = {
    source = "always",
    border = "rounded",
  },
})

local signs = { Error = "❌", Warn = "❗", Hint = "💡", Info = "🔵" }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end
