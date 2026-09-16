#!/usr/bin/env bash
set -uo pipefail # 移除 -e 避免中間小報錯就中斷，改用邏輯判斷

# --- 顏色定義 (保持原樣) ---
BLUE="\033[1;34m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"; RED="\033[1;31m"; RESET="\033[0m"
info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err() { echo -e "${RED}[ERROR]${RESET} $1"; }

# --- 1. 系統更新與基礎工具安裝 ---
info "Updating package list"
sudo apt-get update

info "Installing required packages"
# 這裡把 neofetch 從 apt 清單移除，改為後面手動安裝
PACKAGES=(
    git curl zsh tmux unzip lsd htop bat ripgrep nodejs npm pipx xclip fastfetch
)

for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        ok "$pkg already installed"
    else
        sudo apt-get install -y "$pkg" && ok "$pkg installed" || warn "Failed to install $pkg"
    fi
done

# --- 【新增】手動安裝 Neofetch 執行檔 ---
if ! command -v neofetch >/dev/null 2>&1; then
    info "Downloading Neofetch from GitHub (Kali repo fallback)..."
    sudo curl -fLo /usr/local/bin/neofetch https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch
    sudo chmod +x /usr/local/bin/neofetch
    ok "Neofetch binary installed"
fi

# --- 2. 安裝 Nerd Fonts (保持原樣) ---
FONT_DIR="${HOME}/.local/share/fonts"
if [ ! -f "$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" ]; then
    info "Installing JetBrainsMono Nerd Font..."
    mkdir -p "$FONT_DIR"
    curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.tar.xz
    tar -xf JetBrainsMono.tar.xz -C "$FONT_DIR"
    rm JetBrainsMono.tar.xz
    fc-cache -fv >/dev/null
    ok "Nerd Font installed"
fi

# --- 3. 建立軟連結 ---
# Layout: dotfiles/terminal/{zsh,tmux,bash,nvim,fastfetch}/ + dotfiles/i3/{i3,polybar,picom,rofi,dunst,rice}/
info "Setting up symbolic links for dotfiles..."
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 連結 Zsh / P10k / Tmux / Bash (terminal/)
ln -sf "$DOTFILES_DIR/terminal/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/terminal/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
ln -sf "$DOTFILES_DIR/terminal/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOTFILES_DIR/terminal/tmux/.tmux_status.sh" "$HOME/.tmux_status.sh"
ln -sf "$DOTFILES_DIR/terminal/bash/.bashrc" "$HOME/.bashrc"

mkdir -p "$HOME/.config"

# nvim (terminal/nvim)
ln -sf "$DOTFILES_DIR/terminal/nvim" "$HOME/.config/nvim"

# fastfetch -- cyan Kali-dragon logo config, see terminal/fastfetch/config.jsonc
ln -sf "$DOTFILES_DIR/terminal/fastfetch" "$HOME/.config/fastfetch"

# 【關鍵】連結你的 neofetch 設定資料夾 (legacy fallback binary, kept for compat)
ln -sf "$DOTFILES_DIR/neofetch" "$HOME/.config/neofetch"

# i3 rice (i3/i3, i3/polybar, i3/picom, i3/rofi, i3/dunst, i3/rice)
for d in i3 polybar picom rofi dunst rice; do
    ln -sf "$DOTFILES_DIR/i3/$d" "$HOME/.config/$d"
done

ok "All symbolic links created"

# --- 4. 處理 Oh My Zsh (保持原樣) ---
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 【關鍵】連結 fastfetch 龍圖示用的 neofetch() sched wrapper -- 這個 oh-my-zsh
# custom snippet必須在 oh-my-zsh 裝好、~/.oh-my-zsh/custom 存在之後才能連結
mkdir -p "${HOME}/.oh-my-zsh/custom"
ln -sf "$DOTFILES_DIR/terminal/zsh/fastfetch-dragon.zsh" "${HOME}/.oh-my-zsh/custom/fastfetch-dragon.zsh"

# --- 5. 安裝 Powerlevel10k 主題 (採用穩健路徑) ---
P10K_DIR="${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# --- 6.5 處理 Tmux Plugin Manager (TPM) ---
TPM_DIR="${HOME}/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

info "Refreshing tmux config & installing plugins..."
tmux start-server
tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
bash "$TPM_DIR/bin/install_plugins"
ok "Tmux environment ready"

# --- btop Installation Block (The Simple & Stable Way) ---
echo "────── Installing btop via APT ──────"

# 檢查是否已安裝，沒安裝就補上
if ! command -v btop &> /dev/null; then
    sudo apt update
    sudo apt install -y btop
    echo "btop installed successfully."
else
    echo "btop is already installed."
fi

# 自動幫你建立設定檔目錄並寫入「東邪配置」
mkdir -p ~/.config/btop
cat << EOF > ~/.config/btop/btop.conf
color_theme = "HotPurpleTrafficLight"
graph_symbol = "braille"
update_ms = 1000
EOF

echo "Aesthetic config applied: HotPurpleTrafficLight + Braille"
echo "─────────────────────────────────────────"

# --- 7. 最終檢查 ---
if [ "$SHELL" != "$(which zsh)" ]; then
    sudo chsh -s "$(which zsh)" "$USER"
fi

ok "Dotfiles environment setup finished!"
info "Please run: exec zsh"
