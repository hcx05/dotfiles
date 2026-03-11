#!/usr/bin/env bash
set -euo pipefail

# --- 顏色定義 ---
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# --- 輔助函式 ---
info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err() { echo -e "${RED}[ERROR]${RESET} $1"; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

install_apt_pkg() {
    local pkg="$1"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        ok "$pkg already installed"
    else
        info "Installing $pkg"
        sudo apt-get install -y "$pkg"
        ok "$pkg installed"
    fi
}

# --- 1. 系統更新與基礎工具安裝 ---
info "Updating package list"
sudo apt-get update

info "Installing required packages (System & CLI Tools)"
PACKAGES=(
    git curl zsh tmux neofetch unzip
    lsd htop bat ripgrep
    nodejs npm pipx
)

for pkg in "${PACKAGES[@]}"; do
    install_apt_pkg "$pkg"
done

# --- 2. 安裝 Nerd Fonts (解決圖示問號問題) ---
FONT_DIR="${HOME}/.local/share/fonts"
if [ ! -d "$FONT_DIR" ] || [ ! -f "$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" ]; then
    info "Installing JetBrainsMono Nerd Font..."
    mkdir -p "$FONT_DIR"
    curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.tar.xz
    tar -xf JetBrainsMono.tar.xz -C "$FONT_DIR"
    rm JetBrainsMono.tar.xz
    fc-cache -fv >/dev/null
    ok "Nerd Font installed successfully"
else
    ok "Nerd Font already exists"
fi

# --- 3. 建立軟連結 ---
info "Setting up symbolic links for dotfiles..."
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 連結 Zsh / P10k / Tmux / Bash
ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
ln -sf "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOTFILES_DIR/.tmux_status.sh" "$HOME/.tmux_status.sh"
ln -sf "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"

ok "All symbolic links created from $DOTFILES_DIR"

# --- 4. 處理 Oh My Zsh ---
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh (KEEP_ZSHRC=yes to protect your symlink)"
    KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh base installed"
else
    ok "Oh My Zsh directory already exists"
fi

# --- 5. 安裝 Powerlevel10k 主題 ---
ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"
P10K_DIR="${ZSH_CUSTOM}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    info "Cloning Powerlevel10k theme"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    ok "Powerlevel10k ready"
else
    info "Powerlevel10k already exists"
    git -C "$P10K_DIR" pull --ff-only || warn "P10k update failed"
fi

# --- 6. 檔案權限處理 ---
if [ -f "$DOTFILES_DIR/.tmux_status.sh" ]; then
    info "Ensuring executable permission for .tmux_status.sh"
    chmod +x "$DOTFILES_DIR/.tmux_status.sh"
fi

# --- 7. 最終檢查與清理 ---
echo
ok "Core dotfiles environment setup finished!"
info "To apply Zsh changes immediately, run: exec zsh"
info "Remember to set your Terminal Font to 'JetBrainsMono Nerd Font'!"

if [ "$SHELL" != "$(which zsh)" ]; then
    info "Changing default shell to zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
fi
