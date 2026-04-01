#!/usr/bin/env bash
set -uo pipefail 

# --- 顏色定義 ---
BLUE="\033[1;34m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"; RED="\033[1;31m"; RESET="\033[0m"
info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err() { echo -e "${RED}[ERROR]${RESET} $1"; }

# --- 1. 系統更新與基礎工具安裝 ---
info "Refreshing Ubuntu repositories..."
sudo apt-get update -y

info "Installing core engine packages..."
# Ubuntu 24.04 的軟體包名稱調整
PACKAGES=(
    git curl zsh tmux unzip htop bat ripgrep nodejs npm pipx xclip build-essential
)

for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        ok "$pkg already exists"
    else
        sudo apt-get install -y "$pkg" && ok "$pkg installed" || warn "Failed to install $pkg"
    fi
done

# 【發燒友細節】解決 Ubuntu batcat 命名問題
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    mkdir -p ~/.local/bin
    ln -s /usr/bin/batcat ~/.local/bin/bat
    ok "Mapped batcat to bat"
fi

# --- 2. 手動安裝 Neofetch (Ubuntu 已將其移出官方預設) ---
if ! command -v neofetch >/dev/null 2>&1; then
    info "Installing Neofetch via GitHub binary..."
    sudo curl -fLo /usr/local/bin/neofetch https://raw.githubusercontent.com/dylanaraps/neofetch/master/neofetch
    sudo chmod +x /usr/local/bin/neofetch
    ok "Neofetch engine ready"
fi

# --- 3. 安裝 Nerd Fonts (JetBrainsMono) ---
FONT_DIR="${HOME}/.local/share/fonts"
if [ ! -f "$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" ]; then
    info "Fetching JetBrainsMono Nerd Font for nvim aesthetics..."
    mkdir -p "$FONT_DIR"
    curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.tar.xz
    tar -xf JetBrainsMono.tar.xz -C "$FONT_DIR"
    rm JetBrainsMono.tar.xz
    fc-cache -fv >/dev/null
    ok "Fonts installed (Note: Only effective if your SSH client supports it)"
fi

# --- 4. 建立軟連結 (Dotfiles) ---
info "Wiring up your persona (Dotfiles)..."
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 確保連結時目標路徑存在
mkdir -p "$HOME/.config"

files=(".zshrc" ".p10k.zsh" ".tmux.conf" ".tmux_status.sh" ".bashrc")
for file in "${files[@]}"; do
    if [ -f "$DOTFILES_DIR/$file" ]; then
        ln -sf "$DOTFILES_DIR/$file" "$HOME/$file"
        ok "Linked $file"
    fi
done

# 連結 neofetch 設定
if [ -d "$DOTFILES_DIR/neofetch" ]; then
    ln -sf "$DOTFILES_DIR/neofetch" "$HOME/.config/neofetch"
    ok "Neofetch config linked"
fi

# --- 5. Oh My Zsh & P10k ---
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh (Silent mode)..."
    KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

P10K_DIR="${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# --- 6. Tmux Plugin Manager (TPM) ---
TPM_DIR="${HOME}/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# 強制重新加載 tmux 並自動安裝插件
info "Automating Tmux plugins installation..."
tmux start-server
tmux new-session -d
tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
bash "$TPM_DIR/bin/install_plugins"
tmux kill-server
ok "Tmux environment tuned"

# --- 7. btop (Ubuntu 24.04 特調) ---
info "Installing btop and applying aesthetic config..."
sudo apt-get install -y btop

mkdir -p ~/.config/btop
cat << EOF > ~/.config/btop/btop.conf
color_theme = "HotPurpleTrafficLight"
graph_symbol = "braille"
update_ms = 1000
EOF
ok "btop configured with HotPurple"

# --- 8. 最終權限與 Shell 切換 ---
if [ "$SHELL" != "$(which zsh)" ]; then
    info "Switching default shell to Zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
fi

# 確保 pipx 工具路徑生效
pipx ensurepath --force >/dev/null

echo -e "\n${GREEN}==========================================${RESET}"
ok "Your London-Box is now fully tuned!"
info "Please run: exec zsh"
echo -e "${GREEN}==========================================${RESET}\n"
