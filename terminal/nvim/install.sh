#!/usr/bin/env bash
set -euo pipefail
# set -x # 如果需要調試再開啟

# --- 設定變數 ---
REPO_URL="https://github.com/hcx05/nvim_config.git"
MY_REAL_CONFIG="${HOME}/nvim_config"         # 你的開發真身目錄
NVIM_TARGET_DIR="${HOME}/.config/nvim"       # Neovim 預設讀取路徑
BACKUP_SUFFIX="$(date +%Y%m%d_%H%M%S)"

# --- 顏色設定 ---
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# --- 輔助函數 ---
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

# --- 1. 系統環境準備 ---
info "Updating package list"
sudo apt-get update

info "Installing required packages (Tools & Compilers)"
install_apt_pkg git
install_apt_pkg curl
install_apt_pkg unzip      # [補上] Mason 安裝插件必備
install_apt_pkg ripgrep    # Telescope 搜尋內容必備
install_apt_pkg fd-find    # [補上] Telescope 搜尋檔案加速必備
install_apt_pkg gcc
install_apt_pkg g++
install_apt_pkg clangd
# install_apt_pkg neovim   # [修改] 停用 apt 安裝，改由下方下載官方最新版
install_apt_pkg nodejs
install_apt_pkg npm
install_apt_pkg pipx
install_apt_pkg python3-pip # [補上] 確保 Python 環境完整

# --- [修復 1] 解決 fd 名稱衝突問題 ---
if have_cmd fdfind && ! have_cmd fd; then
    info "Fixing fd-find command name for Telescope..."
    mkdir -p "${HOME}/.local/bin"
    ln -sf "$(which fdfind)" "${HOME}/.local/bin/fd"
    ok "fd symlink created in ~/.local/bin"
fi

# --- [修復 2] 安裝最新穩定版 Neovim ---
# 檢查如果沒安裝 nvim，或者版本低於 0.9.x，就執行官方下載覆蓋
if ! have_cmd nvim || ! nvim --version | head -n 1 | grep -qE "v0\.(9|1[0-9])\."; then
    info "Installing latest stable Neovim from official release..."
    curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz
    sudo rm -rf /opt/nvim
    sudo tar -C /opt -xzf nvim-linux64.tar.gz
    sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
    rm nvim-linux64.tar.gz
    ok "Neovim latest stable installed"
else
    ok "Neovim is already installed and version is sufficient"
fi

# --- 2. 語言伺服器與格式化工具 (LSP & Formatter) ---
if have_cmd npm; then
    info "Installing pyright and tree-sitter-cli"
    sudo npm install -g pyright tree-sitter-cli
    ok "NPM packages ready"
fi

if have_cmd pipx; then
    pipx ensurepath || true
    if ! pipx list | grep -q "package ruff "; then
        info "Installing ruff"
        pipx install ruff
    else
        info "Ruff is already here"
    fi
fi

# --- 3. 配置目錄處理 (核心邏輯：建立軟連結) ---
mkdir -p "${HOME}/.config"

# A. 處理真身目錄 (~/nvim_config)
if [ ! -d "${MY_REAL_CONFIG}" ]; then
    info "Cloning your config to ${MY_REAL_CONFIG}"
    git clone "${REPO_URL}" "${MY_REAL_CONFIG}"
else
    info "Syncing latest changes in ${MY_REAL_CONFIG}"
    git -C "${MY_REAL_CONFIG}" pull --ff-only || warn "Git pull failed, check manually"
fi

# B. 建立軟連結 (讓 .config/nvim 指向 ~/nvim_config)
if [ -L "${NVIM_TARGET_DIR}" ]; then
    info "Symbolic link already exists"
elif [ -d "${NVIM_TARGET_DIR}" ]; then
    BACKUP_DIR="${NVIM_TARGET_DIR}.backup.${BACKUP_SUFFIX}"
    warn "Existing directory found at ${NVIM_TARGET_DIR}, backing up to ${BACKUP_DIR}"
    mv "${NVIM_TARGET_DIR}" "${BACKUP_DIR}"
    ln -s "${MY_REAL_CONFIG}" "${NVIM_TARGET_DIR}"
    ok "Created symbolic link"
else
    info "Creating new symbolic link"
    ln -s "${MY_REAL_CONFIG}" "${NVIM_TARGET_DIR}"
    ok "Link created"
fi

# --- 4. 自動下載與同步插件 ---
info "Installing and Syncing plugins (This may take a while...)"
# 加上 2>/dev/null 隱藏首次安裝時因套件尚未載入產生的 Lua 報錯
nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "Lazy sync finished with some notices"

info "Updating Treesitter parsers"
nvim --headless "+TSUpdate" +qa 2>/dev/null || warn "TSUpdate finished"

echo
ok "✨ Neovim Setup Finished! ✨"
ok "Your Cyberpunk Config is ready to go."
echo "You can now run 'nvim' and press Space+ff to search files!"
