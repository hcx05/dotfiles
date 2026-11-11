# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
#
# fzf-tab (gh0stzk-style fuzzy tab-completion previews: Tab on `cd`/`kill`/
# etc. opens an fzf picker with a live preview instead of a plain list) is
# cloned into $ZSH_CUSTOM/plugins/fzf-tab -- NOT part of this git repo
# (external runtime dependency, same as oh-my-zsh/powerlevel10k themselves):
#   git clone --depth 1 https://github.com/Aloxaf/fzf-tab ~/.oh-my-zsh/custom/plugins/fzf-tab
# Needs `fzf` itself installed (apt install fzf) to do anything -- silently
# falls back to zsh's normal completion menu if fzf isn't on PATH.
# Must come before zsh-autosuggestions/zsh-syntax-highlighting below (its
# own README's ordering requirement -- it wraps the completion widget, and
# needs to do that before those wrap OTHER widgets).
plugins=(git fzf-tab)

source $ZSH/oh-my-zsh.sh

# zsh-autosuggestions / zsh-syntax-highlighting: Kali ships these as plain
# Debian packages under /usr/share, not as oh-my-zsh custom plugins, so
# they're sourced directly here instead of listed in plugins=() above.
#   sudo apt install zsh-autosuggestions zsh-syntax-highlighting
# (already installed on this machine). syntax-highlighting's own upstream
# docs require it be the LAST thing sourced in the whole file -- anything
# sourced after it that defines/wraps a zle widget breaks its highlighting
# -- see the matching source line at the very end of this file.
[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# Suggest from command history first, then fall back to zsh tab-completion
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# -- Better completion behavior (ArchDotfiles / gh0stzk style) --
zstyle ':completion:*' menu select                         # arrow-key menu once there's >1 match
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"     # color completions like `ls`
zstyle ':completion:*' matcher-list \
    'm:{a-zA-Z}={A-Za-z}' \
    '+r:|[._-]=* r:|=*' \
    '+l:|=*'
zstyle ':completion:*:*:*:*:processes' command 'ps -u $USER -o pid,user,comm -w'

# fzf-tab styling & preview panes from hcx05/ArchDotfiles
zstyle ':fzf-tab:*' fzf-flags --style=full --height=90% --pointer '>' --gutter ' ' \
    --color 'pointer:green:bold,bg+:-1:,fg+:green:bold,info:blue:bold,marker:yellow:bold,hl:gray:bold,hl+:gray:bold' \
    --input-label ' Search ' --color 'input-border:blue,input-label:blue:bold' \
    --list-label ' Results ' --color 'list-border:green,list-label:green:bold' \
    --preview-label ' Preview ' --preview-label-pos '27:bottom' --color 'preview-border:magenta,preview-label:magenta:bold'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -1 --icon=always --color=always -a $realpath 2>/dev/null || ls --color=always $realpath'
zstyle ':fzf-tab:complete:(ls|lsd):*' fzf-preview 'lsd -1 --icon=always --color=always -a $realpath 2>/dev/null || ls --color=always $realpath'
zstyle ':fzf-tab:complete:(nvim|vim|cat|bcat|bat|batcat):*' fzf-preview 'batcat --color=always --theme=base16 --style=numbers $realpath 2>/dev/null || cat $realpath'
zstyle ':fzf-tab:*' fzf-bindings 'space:accept'
zstyle ':fzf-tab:*' accept-line enter
zstyle ':fzf-tab:*' switch-group ',' '.'

# fzf itself (Ctrl+R history search, Ctrl+T file picker, Alt+C cd picker) --
# Debian's fzf package ships these under /usr/share/doc/fzf/examples/.
# No-op (keys just do nothing extra) until `sudo apt install fzf`.
[[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && \
    source /usr/share/doc/fzf/examples/key-bindings.zsh
[[ -r /usr/share/doc/fzf/examples/completion.zsh ]] && \
    source /usr/share/doc/fzf/examples/completion.zsh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# i3 黑白主題 (mono) 用自己的 p10k 設定檔：跟這份 .zshrc 同資料夾的 .p10k-mono.zsh。
# 在黑白主題開的終端機裡跑 `p10k configure` 只會改到它，其他主題照舊用 ~/.p10k.zsh。
# (terminal-style 由 apply-theme.sh 寫入；切換主題後新開的終端機生效)
# 目前主題以「桌面使用者」的 ~/.config/rice 為準。用 sudo 開的 root shell
# (sudo su / sudo -i) 會先看 $SUDO_USER 的 ~/.config/rice，並用那個使用者 dotfiles
# 裡的 .p10k-mono.zsh -- root 自己的家目錄或 dotfiles clone (/root/dotfiles) 不知道
# 桌面現在是哪個主題。都找不到才用這份 .zshrc 旁邊的 repo。
zmodload -F zsh/parameter p:userdirs 2>/dev/null
_rice_zsh_dir=${${(%):-%x}:A:h}
for _rice_dir in ${SUDO_USER:+${userdirs[$SUDO_USER]}/.config/rice} ~/.config/rice \
                 $_rice_zsh_dir/../../i3/rice; do
  [[ -r $_rice_dir/terminal-style ]] && break
done
POWERLEVEL9K_CONFIG_FILE=~/.p10k.zsh
if [[ -r $_rice_dir/terminal-style && "$(<$_rice_dir/terminal-style)" == mono ]]; then
  # rice 資料夾是 <dotfiles>/i3/rice 的連結 -> 同一份 dotfiles 的 terminal/zsh
  for _rice_p10k in ${_rice_dir:A}/../../terminal/zsh/.p10k-mono.zsh $_rice_zsh_dir/.p10k-mono.zsh; do
    if [[ -f $_rice_p10k ]]; then
      POWERLEVEL9K_CONFIG_FILE=${_rice_p10k:A}
      break
    fi
  done
fi
unset _rice_zsh_dir _rice_dir _rice_p10k
[[ ! -f $POWERLEVEL9K_CONFIG_FILE ]] || source $POWERLEVEL9K_CONFIG_FILE
export HOSTNAME=$(cat /etc/hostname)
PROMPT='%n@%m %~ %# '
neofetch

export PATH="$HOME/.npm-global/bin:$PATH"
alias ls='lsd'
alias vim="nvim"

alias cat='batcat -p'
alias bcat='batcat'

export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bini
alias penenv="source ~/Arsenal/pen-venv/bin/activate"

# ~/Arsenal 工具說明 (已透過 ~/.local/bin 的 symlink/wrapper 加入 PATH，可直接執行)
#   chisel            - TCP/UDP tunnel over HTTP           (~/Arsenal/chisel/chisel_prod)
#   dehashed          - DeHashed API 搜尋 CLI               (~/Arsenal/deHaSHed/dehashed_cli.py)
#   finalrecon        - 網站偵察/footprinting              (~/Arsenal/FinalRecon/finalrecon.py)
#   username-anarchy  - 依姓名產生帳號猜測清單              (~/Arsenal/username-anarchy/username-anarchy)
#   xsstrike          - XSS 偵測/利用掃描                   (~/Arsenal/XSStrike/xsstrike.py)
#   xxeinjector       - XXE 自動化注入/檔案讀取             (~/Arsenal/XXEinjector/XXEinjector.rb)
#   zap               - OWASP ZAP 啟動器                    (~/Arsenal/ZAP_2.17.0/zap.sh)
#   reconspider       - Scrapy 爬蟲式網站偵察 (需 scrapy)   (~/Arsenal/Scrapy/ReconSpider.py)

# I3SOCK points at i3's IPC socket, named after its PID. A shell that
# outlives the X session it was started under (e.g. one kept alive by a
# detached tmux server across a logout/login) keeps this exported with the
# OLD i3 process's path baked in forever -- env vars don't self-refresh.
# Checking the path is a live socket isn't enough to catch this: i3 doesn't
# clean up the old socket FILE on exit, so a dead one still passes a `-S`
# test and i3-msg/i3ipc still fail to connect to it. Just always unset it
# instead -- i3 tooling falls back to its own live discovery (the
# I3_SOCKET_PATH property on the X root window) when the var isn't set, so
# there's no downside to never trusting an inherited value.
unset I3SOCK

# zsh-syntax-highlighting MUST be loaded before history-substring-search and
# after all other widgets -- see the comment next to zsh-autosuggestions above.
[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# zsh-history-substring-search (from hcx05/ArchDotfiles): type part of a command
# and press Up/Down arrows to cycle through matching history entries.
[[ -r $ZSH/plugins/history-substring-search/history-substring-search.zsh ]] && \
    source $ZSH/plugins/history-substring-search/history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" history-substring-search-up
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" history-substring-search-down


# Added by Antigravity CLI installer
export PATH="/home/kali/.local/bin:$PATH"
