#!/usr/bin/env bash
# debian-server.sh — headless HTB attack box provisioning (Debian 13 trixie).
#
# 為什麼不用 insta11.sh / ubuntu.sh：
#   - insta11.sh 是 Kali 桌面用的（裝 dunst/brightnessctl/playerctl 等 i3 rice 依賴）
#   - ubuntu.sh 針對 Ubuntu，但這類雲端機是 Debian，套件名稱與版本都不同
#   - 兩者都裝 Nerd Font；字型是「本地終端機」渲染的，裝在遠端伺服器上完全無用
#
# 這台機器的角色是真正的攻擊機（openvpn 跑在這裡），本地只當終端機。
# 工具必須裝在這台而非靠 pivot，因為 proxychains 只代理 TCP connect()：
# nmap -sS/-sU、ICMP 會直接掉，而反向 shell 的 listener 必須綁在持有 tun0 的這端。
#
# 用法（在本機）：
#   rsync -az --delete ~/dotfiles/ htb:~/dotfiles/ --exclude .git
#   ssh htb '~/dotfiles/debian-server.sh'
#
#   --no-msf   跳過 Metasploit（約 1.5GB，且會加入 Rapid7 第三方 apt repo）
#
# 可重複執行。

set -uo pipefail

BLUE="\033[1;34m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"; RED="\033[1;31m"; RESET="\033[0m"
info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok()   { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err()  { echo -e "${RED}[ERROR]${RESET} $1"; }
phase(){ echo; echo -e "${BLUE}### $1${RESET}"; }

WITH_MSF=1
for arg in "$@"; do
    case "$arg" in
        --no-msf) WITH_MSF=0 ;;
        -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
        *) err "unknown option: $arg"; exit 1 ;;
    esac
done

export DEBIAN_FRONTEND=noninteractive
BIN=/usr/local/bin
DF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -d "$DF/terminal" ] || { err "找不到 $DF/terminal，請先同步整個 dotfiles"; exit 1; }

# 抓 GitHub repo 最新 release 中符合 pattern 的 asset
gh_release_asset() {
    local repo="$1" pattern="$2" dest="$3" url
    url=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
          | jq -r --arg p "$pattern" '.assets[]|select(.name|test($p))|.browser_download_url' \
          | head -1)
    [ -z "$url" ] && { warn "$repo: 找不到符合 $pattern 的 asset"; return 1; }
    curl -fsSL "$url" -o "$dest"
}

apt_install() {
    local pkg="$1"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        ok "$pkg already installed"
    else
        sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1 && ok "$pkg installed" || warn "FAILED: $pkg"
    fi
}

phase "0. 前置檢查"
. /etc/os-release
info "OS: $PRETTY_NAME"
[ "${ID:-}" = "debian" ] || warn "這支腳本是針對 Debian 寫的，當前是 ${ID:-unknown}"
sudo -n true 2>/dev/null && ok "sudo 可用" || info "sudo 會要密碼"
[ -c /dev/net/tun ] && ok "/dev/net/tun 存在（VPN / ligolo 可用）" || err "沒有 /dev/net/tun，VPN 無法運作"

phase "1. apt 基礎套件 + 滲透工具"
sudo apt-get update -qq

# gnupg 必須先裝：沒有它，第三方 apt repo 的簽章金鑰無法匯入，
# apt 會（正確地）拒絕未簽章來源。Metasploit 官方安裝器就是這樣失敗的。
# ncurses-term 提供 tmux.conf 要的 tmux-256color terminfo。
# libreadline-dev / libncurses-dev 是 evil-winrm 編 readline-ext 原生擴充用的。
PACKAGES=(
    gnupg ca-certificates git curl wget unzip build-essential jq
    zsh tmux ncurses-term zsh-autosuggestions zsh-syntax-highlighting
    lsd bat ripgrep fzf fd-find fastfetch
    libreadline-dev libncurses-dev ruby ruby-dev
    # 連線層。mosh 需要 GCP 防火牆另外開 UDP 60000-61000，否則裝了也連不進來。
    mosh openvpn proxychains4 iperf3 mtr-tiny rsync
    # recon / exploit
    nmap socat sqlmap hydra john
    smbclient ldap-utils bind9-dnsutils snmp
    python3-pip python3-venv pipx
)
for pkg in "${PACKAGES[@]}"; do apt_install "$pkg"; done

# Debian 把 bat 叫 batcat、fd 叫 fdfind
mkdir -p "$HOME/.local/bin"
[ -x /usr/bin/batcat ] && ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
[ -x /usr/bin/fdfind ] && ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

phase "2. neovim（Debian 倉庫只有 0.10.4，lazy-lock.json 需要 0.11.x）"
NVIM_WANT=v0.11.6
if [ "$(nvim --version 2>/dev/null | head -1 | grep -oE '0\.[0-9]+\.[0-9]+')" = "${NVIM_WANT#v}" ]; then
    ok "neovim ${NVIM_WANT} already installed"
elif curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_WANT}/nvim-linux-x86_64.tar.gz" -o /tmp/nvim.tar.gz; then
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf /tmp/nvim.tar.gz
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim $BIN/nvim
    rm -f /tmp/nvim.tar.gz
    ok "neovim $(nvim --version | head -1)"
else
    warn "上游 tarball 下載失敗，退回 apt 版 (0.10.4)"
    apt_install neovim
fi

phase "3. pipx 工具"
export PATH="$HOME/.local/bin:$PATH"
pipx ensurepath >/dev/null 2>&1
pipx_install() {
    local name="$1" spec="$2"
    if pipx list --short 2>/dev/null | grep -q "^$name "; then
        ok "$name already installed"
    else
        pipx install "$spec" >/dev/null 2>&1 && ok "$name installed" || warn "FAILED: $name"
    fi
}
# NetExec 在 PyPI 上沒有發布，只能從 git 裝
pipx_install netexec       "git+https://github.com/Pennyw0rth/NetExec"
pipx_install impacket      impacket
pipx_install bloodhound-ce bloodhound-ce
pipx_install bloodhound    bloodhound

phase "4. GitHub release 二進位檔"
install_gh_bin() {
    local cmd="$1" repo="$2" pattern="$3" kind="$4"
    command -v "$cmd" >/dev/null 2>&1 && { ok "$cmd already installed"; return; }
    info "$cmd"
    local tmp=/tmp/ghbin.$$ && rm -rf "$tmp" && mkdir -p "$tmp"
    case "$kind" in
        gz)  gh_release_asset "$repo" "$pattern" "$tmp/f.gz"  && gunzip -f "$tmp/f.gz"  && sudo install -m755 "$tmp/f" "$BIN/$cmd" ;;
        zip) gh_release_asset "$repo" "$pattern" "$tmp/f.zip" && unzip -oq "$tmp/f.zip" -d "$tmp" && sudo install -m755 "$(find "$tmp" -type f -name "$cmd" | head -1)" "$BIN/$cmd" ;;
        tgz) gh_release_asset "$repo" "$pattern" "$tmp/f.tgz" && tar -C "$tmp" -xzf "$tmp/f.tgz" && sudo install -m755 "$(find "$tmp" -type f -name "${5:-$cmd}" | head -1)" "$BIN/$cmd" ;;
    esac
    command -v "$cmd" >/dev/null 2>&1 && ok "$cmd installed" || warn "FAILED: $cmd"
    rm -rf "$tmp"
}
install_gh_bin nuclei       projectdiscovery/nuclei 'nuclei_.*_linux_amd64\.zip$'            zip
install_gh_bin chisel       jpillora/chisel         'chisel_.*_linux_amd64\.gz$'             gz
install_gh_bin feroxbuster  epi052/feroxbuster      'x86_64-linux-feroxbuster\.tar\.gz$'     tgz
install_gh_bin ligolo-proxy nicocha30/ligolo-ng     'ligolo-ng_proxy_.*_linux_amd64\.tar\.gz$' tgz proxy

# ligolo agent 不是裝在這台，是要丟給目標機執行的
mkdir -p "$HOME/payloads"
if [ ! -f "$HOME/payloads/ligolo-agent-linux" ]; then
    t=/tmp/lig.$$ && mkdir -p "$t"
    gh_release_asset nicocha30/ligolo-ng 'ligolo-ng_agent_.*_linux_amd64\.tar\.gz$' "$t/a.tgz" \
      && tar -C "$t" -xzf "$t/a.tgz" && cp "$t/agent" "$HOME/payloads/ligolo-agent-linux" \
      && ok "ligolo linux agent -> ~/payloads/"
    gh_release_asset nicocha30/ligolo-ng 'ligolo-ng_agent_.*_windows_amd64\.zip$' "$t/w.zip" \
      && unzip -oq "$t/w.zip" -d "$t" && cp "$t/agent.exe" "$HOME/payloads/ligolo-agent.exe" \
      && ok "ligolo windows agent -> ~/payloads/"
    rm -rf "$t"
else
    ok "ligolo agents already present"
fi

phase "5. evil-winrm (ruby gem)"
if command -v evil-winrm >/dev/null 2>&1; then
    ok "evil-winrm already installed"
else
    # 需要 libreadline-dev（phase 1 已裝），否則 readline-ext 原生擴充編譯失敗
    sudo gem install evil-winrm --no-document >/dev/null 2>&1 \
      && ok "evil-winrm $(evil-winrm --version 2>/dev/null)" || warn "FAILED: evil-winrm"
fi

phase "6. Responder（Debian 沒有打包）"
if [ -d /opt/Responder ]; then
    ok "Responder already present"
else
    sudo git clone -q --depth 1 https://github.com/lgandx/Responder /opt/Responder \
      && sudo chown -R "$USER:$USER" /opt/Responder && ok "Responder -> /opt/Responder" \
      || warn "FAILED: Responder"
fi

phase "7. SecLists + rockyou（Debian 沒有打包）"
if [ -d /usr/share/seclists ]; then
    ok "seclists already present ($(du -sh /usr/share/seclists 2>/dev/null | cut -f1))"
else
    info "clone SecLists（shallow，約 2.5GB）"
    sudo git clone -q --depth 1 https://github.com/danielmiessler/SecLists /usr/share/seclists \
      && ok "seclists -> /usr/share/seclists" || warn "FAILED: seclists"
fi
sudo mkdir -p /usr/share/wordlists
sudo ln -sfn /usr/share/seclists /usr/share/wordlists/seclists
ROCKYOU_TGZ=/usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz
if [ ! -f /usr/share/wordlists/rockyou.txt ] && [ -f "$ROCKYOU_TGZ" ]; then
    sudo tar -C /usr/share/wordlists -xzf "$ROCKYOU_TGZ" && ok "rockyou.txt 解壓完成"
fi
# tar 保留了原本的擁有者與限制權限，不修的話一般使用者讀不到
[ -f /usr/share/wordlists/rockyou.txt ] && sudo chmod 644 /usr/share/wordlists/rockyou.txt \
  && ok "rockyou.txt readable ($(wc -l < /usr/share/wordlists/rockyou.txt) lines)"

if [ "$WITH_MSF" = 1 ]; then
    phase "8. Metasploit（Rapid7 第三方 apt repo，約 1.5GB）"
    if command -v msfconsole >/dev/null 2>&1; then
        ok "metasploit already installed"
    else
        curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
            -o /tmp/msfinstall && chmod 755 /tmp/msfinstall
        sudo /tmp/msfinstall >/dev/null 2>&1
        command -v msfconsole >/dev/null 2>&1 && ok "metasploit installed" || warn "FAILED: metasploit"
        rm -f /tmp/msfinstall
    fi
    if command -v msfconsole >/dev/null 2>&1; then
        apt_install postgresql
        sudo systemctl enable --now postgresql >/dev/null 2>&1
        # msfdb init 要寫 framework 的 tmp/，但它是 root 所有，一般使用者建不起來
        MSF_TMP=/opt/metasploit-framework/embedded/framework/tmp
        sudo mkdir -p "$MSF_TMP" && sudo chown -R "$USER:$USER" "$MSF_TMP"
        if msfconsole -q -x 'db_status; exit' 2>/dev/null | grep -qi connected; then
            ok "msf db 已連線"
        else
            msfdb init >/dev/null 2>&1 && ok "msfdb 初始化完成" || warn "msfdb init 失敗"
        fi
    fi
else
    phase "8. Metasploit — 依 --no-msf 跳過"
fi

phase "9. 系統設定"
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-htb-forward.conf >/dev/null
sudo /usr/sbin/sysctl -q -p /etc/sysctl.d/99-htb-forward.conf && ok "ip_forward=1（持久化，pivot 用）"

# 雲端機器預設 UTC，但 tmux 狀態列的時間要跟使用者所在時區一致才有用
TZ_WANT=Asia/Taipei
if [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = "$TZ_WANT" ]; then
    ok "時區已是 $TZ_WANT"
else
    sudo timedatectl set-timezone "$TZ_WANT" && ok "時區 -> $TZ_WANT" || warn "FAILED: set-timezone"
fi

phase "10. dotfiles：oh-my-zsh + p10k + fzf-tab"
# .zshrc 無條件呼叫 neofetch，Debian 13 已經把它移出倉庫（上游封存），所以抓 binary
if command -v neofetch >/dev/null 2>&1; then
    ok "neofetch already installed"
else
    sudo curl -fsSLo $BIN/neofetch https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch \
      && sudo chmod +x $BIN/neofetch && ok "neofetch installed" || warn "FAILED: neofetch"
fi
if [ -d "$HOME/.oh-my-zsh" ]; then
    ok "oh-my-zsh already present"
else
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >/dev/null 2>&1 \
      && ok "oh-my-zsh installed" || warn "FAILED: oh-my-zsh"
fi
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
clone_if_absent() {
    [ -d "$2" ] && { ok "$(basename "$2") already present"; return; }
    git clone -q --depth 1 "$1" "$2" && ok "$(basename "$2") cloned" || warn "FAILED: $1"
}
clone_if_absent https://github.com/romkatv/powerlevel10k "$ZSH_CUSTOM/themes/powerlevel10k"
clone_if_absent https://github.com/Aloxaf/fzf-tab        "$ZSH_CUSTOM/plugins/fzf-tab"
ln -sfn "$DF/terminal/zsh/fastfetch-dragon.zsh" "$ZSH_CUSTOM/fastfetch-dragon.zsh"

phase "11. symlink 設定檔（只有 terminal/，i3/ 需要 X11 不搬）"
ln -sfn "$DF/terminal/zsh/.zshrc"           "$HOME/.zshrc"          && ok ".zshrc"
ln -sfn "$DF/terminal/zsh/.p10k.zsh"        "$HOME/.p10k.zsh"       && ok ".p10k.zsh"
ln -sfn "$DF/terminal/tmux/.tmux_status.sh" "$HOME/.tmux_status.sh" && ok ".tmux_status.sh"
mkdir -p "$HOME/.config" "$HOME/Pictures"
ln -sfn "$DF/terminal/nvim"                 "$HOME/.config/nvim"      && ok ".config/nvim"
ln -sfn "$DF/terminal/fastfetch"            "$HOME/.config/fastfetch" && ok ".config/fastfetch"
ln -sfn "$DF/terminal/fastfetch/dragon.png" "$HOME/Pictures/dragon.png"

phase "12. headless 覆寫（刻意不改 repo 內的設定）"
# ~/.tmux.conf 故意「不是」symlink：它 source repo 版之後再疊上這台專屬的行為，
# 這樣 dotfiles 更新不會把覆寫沖掉，repo 也不必為伺服器加分支邏輯。
cat > "$HOME/.tmux.conf" <<'TMUXEOF'
# --- VM-local wrapper。先 source repo 設定，再覆寫 headless 行為。 ---
source-file ~/dotfiles/terminal/tmux/.tmux.conf

# 這台沒有 X display，repo 版綁定的 xclip 一定失敗。改用 OSC 52：
# 複製的內容會透過 ssh 送回「本地終端機」的剪貼簿。
# repo 的 tmux.conf 已經有 allow-passthrough on，這裡只需要開 set-clipboard。
set -g set-clipboard on
unbind -T copy-mode-vi y
bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel
bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel
unbind ]
bind ] paste-buffer

# 遠端 session 要活過斷線，scrollback 開大
set -g history-limit 50000

# mono 狀態列：跟本地桌面一致，去底色只留白字。repo 的 .tmux.conf 設的是
# bg=black，而它接著 source 的 ~/.config/rice/tmux-theme.conf（本地由
# apply-theme.sh 產生）在這台不存在，所以得在這裡覆寫。
set -g status-style bg=default,fg=white
TMUXEOF
ok "~/.tmux.conf wrapper"

# .tmux_status.sh 硬編碼讀 ~/.config/rice/terminal-style，內容是 mono 才走無色分支。
# 在有 i3 rice 的機器上那個路徑是 symlink 指進 repo（i3/rice/terminal-style），
# 寫下去會污染 repo 並改掉桌面主題，所以只在它不是 symlink 時才動。
if [ -L "$HOME/.config/rice" ]; then
    warn "~/.config/rice 是 symlink（i3 rice 存在）— 跳過 terminal-style，避免寫進 repo"
else
    mkdir -p "$HOME/.config/rice"
    printf 'mono\n' > "$HOME/.config/rice/terminal-style"
    ok "terminal-style = mono（狀態列走無色分支）"
fi

# /usr/sbin 不在 Debian 的非 root PATH 裡，但 openvpn、tcpdump、john 都在那
cat > "$HOME/.zshenv" <<'ENVEOF'
# VM-local。Debian 的一般使用者 PATH 不含 /usr/sbin，但 openvpn/tcpdump 在那裡。
typeset -U path
path=("$HOME/.local/bin" /usr/sbin /sbin $path)
export PATH
ENVEOF
ok "~/.zshenv"

clone_if_absent https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ] \
  && "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 && ok "tmux plugins"

phase "13. 預設 shell + nvim plugin"
if [ "$(getent passwd "$USER" | cut -d: -f7)" = "/usr/bin/zsh" ]; then
    ok "預設 shell 已是 zsh"
else
    sudo chsh -s /usr/bin/zsh "$USER" && ok "shell -> /usr/bin/zsh" || warn "FAILED: chsh"
fi
command -v nvim >/dev/null 2>&1 \
  && timeout 300 nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 \
  && ok "lazy.nvim synced" || warn "nvim sync 未完成（第一次互動啟動時會補完）"

phase "完成"
export PATH="$HOME/.local/bin:/usr/sbin:/sbin:$PATH"
for t in nvim tmux zsh openvpn nmap ffuf feroxbuster gobuster nuclei sqlmap hydra john \
         nxc evil-winrm chisel ligolo-proxy socat proxychains4 mtr iperf3 \
         msfconsole msfvenom smbclient bloodhound-python ldapsearch dig; do
    printf "  %-18s %s\n" "$t" "$(command -v $t 2>/dev/null || echo '-- MISSING --')"
done
echo
info "開工：tmux new -s htb  →  sudo openvpn --config ~/vpn/htb/US3.ovpn"
info "本地 Burp 穿進來：ssh -D 9050 -N htb，然後設 Burp 的 SOCKS proxy 127.0.0.1:9050"
warn "同一份 .ovpn 不要同時在本地和這台連線，HTB 會踢掉其中一條"
