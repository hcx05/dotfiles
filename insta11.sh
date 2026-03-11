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
  lsd htop bat 
  ripgrep gcc g++ clangd neovim 
  nodejs npm pipx
)

for pkg in "${PACKAGES[@]}"; do
  install_apt_pkg "$pkg"
done

# --- 1.5 安裝 Nerd Fonts (解決圖示問號問題) ---
FONT_DIR="${HOME}/.local/share/fonts"
if [ ! -d "$FONT_DIR" ] || [ ! -f "$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" ]; then
    info "Installing JetBrainsMono Nerd Font..."
    mkdir -p "$FONT_DIR"
    # 下載壓縮包
    curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.tar.xz
    # 解壓縮到字體目錄
    tar -xf JetBrainsMono.tar.xz -C "$FONT_DIR"
    rm JetBrainsMono.tar.xz
    # 更新系統字體快取
    fc-cache -fv >/dev/null
    ok "Nerd Font installed successfully"
else
    ok "Nerd Font already exists"
fi

# --- 2. 處理 Oh My Zsh (保留現有軟連結) ---
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
  info "Installing Oh My Zsh (KEEP_ZSHRC=yes to protect your symlink)"
  KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  ok "Oh My Zsh base installed"
else
  ok "Oh My Zsh directory already exists"
fi

# --- 3. 安裝 Powerlevel10k 主題 ---
ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"
P10K_DIR="${ZSH_CUSTOM}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  info "Cloning Powerlevel10k theme"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  ok "Powerlevel10k ready"
else
  info "Powerlevel10k already exists, pulling latest updates"
  git -C "$P10K_DIR" pull --ff-only || warn "P10k update failed"
fi

# --- 4. 配置開發環境依賴 ---
if have_cmd pipx; then
  info "Ensuring pipx path"
  pipx ensurepath || true
  
  if ! pipx list | grep -q "package ruff "; then
    info "Installing ruff via pipx"
    pipx install ruff || true
  fi
fi

if have_cmd npm; then
  info "Checking for pyright (global)"
  if ! npm list -g pyright >/dev/null 2>&1; then
    sudo npm install -g pyright || warn "pyright install failed"
  else
    ok "pyright already installed"
  fi
fi

# --- 5. 檔案權限處理 ---
if [ -f "${HOME}/.tmux_status.sh" ]; then
  info "Setting executable permission for .tmux_status.sh"
  chmod +x "${HOME}/.tmux_status.sh"
fi

# --- 6. 最終檢查與清理 ---
echo
info "--- Environment Summary ---"
fc-list : family | grep -i "Nerd" >/dev/null && ok "Nerd Font: Detected ✨" || warn "Nerd Font: Not detected"
have_cmd zsh && zsh --version
have_cmd lsd && echo "lsd: $(lsd --version | head -n 1)"

echo
ok "Core dotfiles environment setup finished!"
info "To apply Zsh changes immediately, run: exec zsh"
info "Remember to set your Terminal Font to 'JetBrainsMono Nerd Font'!"

if [ "$SHELL" != "$(which zsh)" ]; then
    info "Changing default shell to zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
fi
