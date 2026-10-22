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
plugins=(git)

source $ZSH/oh-my-zsh.sh

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
# (~/.config/rice/terminal-style 由 ~/.config/rice/apply-theme.sh 寫入；切換主題後新開的終端機生效)
POWERLEVEL9K_CONFIG_FILE=~/.p10k.zsh
if [[ -r ~/.config/rice/terminal-style && "$(<~/.config/rice/terminal-style)" == mono &&
      -f ${${(%):-%x}:A:h}/.p10k-mono.zsh ]]; then
  POWERLEVEL9K_CONFIG_FILE=${${(%):-%x}:A:h}/.p10k-mono.zsh
fi
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
