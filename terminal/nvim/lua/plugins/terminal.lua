return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
    require("toggleterm").setup({
        -- 寬度或高度，橫向模式下 15~20 差不多
        size = 15, 
        open_mapping = [[<c-t>]],
        -- 關鍵修改：從 "float" 改成 "horizontal"
        direction = "horizontal", 
        shade_terminals = true,
        start_in_insert = false, -- 改成 false，編譯完才不會強制跳進輸入模式
        persist_size = true,
         -- 既然不是 float，float_opts 就不會生效，可以留著不理它
        })
      
        vim.keymap.set("n", "<leader>r", function()
        vim.cmd("w") -- 編譯前存檔
        local filename = vim.fn.expand("%:t:r")
        local ext = vim.fn.expand("%:e")

        -- 只進行編譯，不執行
        if ext == "cpp" then
          vim.cmd("TermExec cmd='g++ % -o " .. filename .. " && echo \"✅ C++ Build Success\"'")
        elseif ext == "c" then
          vim.cmd("TermExec cmd='gcc % -o " .. filename .. " && echo \"✅ C Build Success\"'")
        elseif ext == "py" then
          -- Python 不需要編譯，或許你可以設定成語法檢查，或者乾脆不對 py 做事
          print("🐍 Python file detected - No build needed")
        else
          print("❌ Unsupported file type: " .. ext)
        end
      end, { desc = "Compile Only with ToggleTerm" })
    end,
  },
}
