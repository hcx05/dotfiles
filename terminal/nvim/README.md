==================================================
NVIM CONFIG MANUAL
==================================================

This is my personal Neovim config.

Main goals:
- clean interface
- C/C++ workflow
- clangd LSP
- autocomplete
- Treesitter highlighting
- fast daily use

==================================================
FEATURES
==================================================

- lazy.nvim plugin manager
- relative line numbers
- 4-space indentation
- true color support
- system clipboard support
- floating diagnostics
- custom diagnostic signs
- nvim-cmp completion
- LuaSnip snippets
- nvim-autopairs
- nvim-treesitter
- clangd LSP for C/C++

Diagnostic signs:
- Error   : [X]
- Warning : [!]
- Hint    : [*]
- Info    : [i]


==================================================
INSTALLED PLUGINS
==================================================

Core:
- folke/lazy.nvim
- nvim-lua/plenary.nvim
- nvim-telescope/telescope.nvim

Editing:
- windwp/nvim-autopairs
- nvim-treesitter/nvim-treesitter

Completion and LSP:
- neovim/nvim-lspconfig
- hrsh7th/nvim-cmp
- hrsh7th/cmp-nvim-lsp
- L3MON4D3/LuaSnip

Theme / extras:
- catppuccin
- copilot plugins if enabled

==================================================
SYSTEM REQUIREMENTS
==================================================

Install these first:
- git
- gcc
- g++
- clangd
- ripgrep
- neovim 0.11+

Example on Debian / Ubuntu / Kali:

sudo apt update
sudo apt install git gcc g++ clangd ripgrep

==================================================
INSTALLATION
==================================================

Clone the repo:

git clone https://github.com/hcx05/nvim_config ~/.config/nvim

Start Neovim:

nvim

If plugins do not install automatically, run:

:Lazy sync

==================================================
DEFAULT SETTINGS
==================================================

Leader key:
SPACE

Enabled by default:
- relative line numbers
- tabstop = 4
- shiftwidth = 4
- expandtab = true
- smartindent = true
- termguicolors = true
- clipboard = unnamedplus

==================================================
KEYBINDINGS
==================================================

Leader key:
SPACE

Main shortcuts:

[SPACE] r
Save file, compile, and run current C or C++ file.

Behavior:
- If current file is .c
  gcc file.c -o file && ./file

- If current file is .cpp
  g++ file.cpp -o file && ./file

K
Open diagnostic float under cursor.

[SPACE] y
Copy to system clipboard.

==================================================
AUTOCOMPLETE
==================================================

Autocomplete is powered by nvim-cmp.

Insert mode keys:

TAB
- select next completion item

SHIFT-TAB
- select previous completion item

ENTER
- confirm selected completion

CTRL-SPACE
- trigger completion manually

Completion sources:
- LSP
- LuaSnip
- buffer
- path

==================================================
LSP
==================================================

This config uses clangd.

Enabled for:
- c
- cpp
- objc
- objcpp

Project root markers:
- .clangd
- compile_commands.json
- .git

If LSP is not working, make sure clangd is installed:

clangd --version

==================================================
DIAGNOSTICS
==================================================

Diagnostic behavior:
- virtual text disabled
- float popup enabled
- rounded border
- source always shown

Signs:
- Error   -> [X]
- Warning -> [!]
- Hint    -> [*]
- Info    -> [i]

==================================================
TREESITTER
==================================================

Installed parsers:
- c
- cpp
- lua
- vim
- vimdoc
- query
- markdown

Update parsers with:

:TSUpdate

==================================================
PLUGIN MANAGEMENT
==================================================

Open lazy.nvim UI:

:Lazy

Common commands:

:Lazy sync
- install / update / clean plugins

:Lazy update
- update plugins only

:Lazy clean
- remove unused plugins

==================================================
COMMON WORKFLOW
==================================================

1. Open a C or C++ file:
   nvim main.cpp

2. Edit normally

3. Use autocomplete while typing:
   TAB / SHIFT-TAB / ENTER

4. Check diagnostics:
   K

5. Build and run:
   SPACE r

==================================================
USEFUL COMMANDS
==================================================

:Lazy
Open plugin manager

:TSUpdate
Update Treesitter parsers

:checkhealth
Check Neovim health

:LspInfo
Show LSP information

==================================================
TROUBLESHOOTING
==================================================

Problem:
Plugins not loading

Fix:
Run:
:Lazy sync

Problem:
Treesitter parser issues

Fix:
Run:
:TSUpdate

Problem:
clangd not working

Fix:
Check:
clangd --version

Also make sure file is inside a project with one of:
- .git
- .clangd
- compile_commands.json

Problem:
Clipboard not working

Fix:
Check Neovim clipboard support and system clipboard package.

==================================================
NOTES
==================================================

This config is designed to stay simple and lightweight.
Main focus is C/C++ editing with LSP, completion, diagnostics,
and a clean UI.

==================================================
END

============================================================
NVIM CONFIG README
============================================================

Name:
- Personal Neovim configuration

Purpose:
- Store all Neovim settings in one Git repo
- Reuse on multiple computers
- Support C/C++ and Python workflow
- Keep plugin list, file structure, and shortcuts organized

============================================================
PLUGIN LIST
============================================================

Plugin manager:
- folke/lazy.nvim

Core libraries:
- nvim-lua/plenary.nvim

Search / navigation:
- nvim-telescope/telescope.nvim

Syntax highlighting / parsing:
- nvim-treesitter/nvim-treesitter

LSP / completion:
- neovim/nvim-lspconfig
- hrsh7th/nvim-cmp
- hrsh7th/cmp-nvim-lsp
- L3MON4D3/LuaSnip

Editing:
- windwp/nvim-autopairs

Theme / appearance:
- catppuccin

Other plugin files present:
- ai.lua
- colors.lua
- catppuccin.lua
- core.lua
- treesitter.lua.save

============================================================
CONFIG FILE STRUCTURE
============================================================

~/.config/nvim
|
|-- init.lua
|-- lazy-lock.json
`-- lua
    `-- plugins
        |-- ai.lua
        |-- catppuccin.lua
        |-- colors.lua
        |-- core.lua
        `-- treesitter.lua.save

============================================================
MAIN SETTINGS
============================================================

Leader key:
- Space

Editor settings:
- relative line numbers enabled
- tabstop = 4
- shiftwidth = 4
- expandtab = true
- smartindent = true
- termguicolors = true
- clipboard = unnamedplus

Diagnostic signs:
- Error   = [X]
- Warn    = [!]
- Hint    = [*]
- Info    = [i]

Current language support:
- C / C++ via clangd
- Python via pyright
- Python formatting via ruff

============================================================
CUSTOM KEYBINDINGS
============================================================

Space + r
- Save current file
- If file is .c:
  gcc file.c -o file && ./file
- If file is .cpp:
  g++ file.cpp -o file && ./file

K
- Show diagnostic popup under cursor

Space + y
- Copy selected text to system clipboard

Space + f
- Python only
- Save current file
- Run ruff format on current file
- Reload file

============================================================
COMPLETION KEYS
============================================================

Tab
- Select next completion item

Shift + Tab
- Select previous completion item

Enter
- Confirm current completion item

Ctrl + Space
- Open completion menu manually

============================================================
BUILT-IN NVIM BASICS
============================================================

File operations:
- :w       save file
- :q       quit current window
- :wq      save and quit
- :qa      quit all
- :q!      quit without saving

Movement:
- h        move left
- j        move down
- k        move up
- l        move right
- gg       go to top of file
- G        go to bottom of file
- 0        go to start of line
- $        go to end of line
- w        jump to next word
- b        jump to previous word

Insert / edit:
- i        insert before cursor
- a        insert after cursor
- o        open new line below
- O        open new line above
- x        delete character
- dd       delete current line
- yy       copy current line
- p        paste after cursor
- P        paste before cursor
- u        undo
- Ctrl + r redo

Visual mode:
- v        start visual mode
- V        start line visual mode
- y        copy selection
- d        cut selection

Search:
- /text    search forward
- n        next match
- N        previous match

Clipboard:
- yy       copy line to Vim register
- p        paste
- "+y      copy to system clipboard
- "+p      paste from system clipboard

============================================================
PLUGIN MANAGEMENT
============================================================

:Lazy
- Open lazy.nvim plugin manager UI

:Lazy sync
- Install, update, and clean plugins

:Lazy update
- Update plugins

:Lazy clean
- Remove unused plugins

============================================================
TREESITTER
============================================================

Installed parsers:
- c
- cpp
- lua
- vim
- vimdoc
- query
- markdown

Useful command:
- :TSUpdate

============================================================
LSP / HEALTH COMMANDS
============================================================

:LspInfo
- Show LSP information

:checkhealth
- Check Neovim health

============================================================
END
============================================================
