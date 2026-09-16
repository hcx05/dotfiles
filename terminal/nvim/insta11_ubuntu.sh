#!/usr/bin/env bash

# insta11_ubuntu.sh - Ubuntu Installation Script for Neovim Config
# This script installs Neovim and its dependencies, then links the config.

set -e

# --- Colors for output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting installation for Ubuntu...${NC}"

# --- 1. System Updates ---
echo -e "${BLUE}Updating package lists...${NC}"
sudo apt update -y

# --- 2. Install Dependencies ---
echo -e "${BLUE}Installing core dependencies...${NC}"
sudo apt install -y git curl unzip build-essential ripgrep fd-find nodejs npm python3-pip pipx

# Fix fd-find name for Telescope/LazyVim compatibility
if command -v fdfind >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
    export PATH="$HOME/.local/bin:$PATH"
fi

# --- 3. Install Neovim (Latest Stable) ---
# We use the official GitHub release to ensure we have a modern version (>= 0.9.0)
if ! command -v nvim >/dev/null 2>&1 || [[ "$(nvim --version | head -n1)" < "NVIM v0.9.0" ]]; then
    echo -e "${BLUE}Installing latest stable Neovim...${NC}"
    curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz
    sudo rm -rf /opt/nvim-linux64
    sudo tar -C /opt -xzf nvim-linux64.tar.gz
    sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
    rm nvim-linux64.tar.gz
fi

# --- 4. Language Servers & Tools ---
echo -e "${BLUE}Installing LSP servers and formatters...${NC}"
sudo npm install -g pyright tree-sitter-cli
pipx install ruff --force || true
pipx ensurepath

# --- 5. Configure Neovim ---
NVIM_CONFIG_DIR="$HOME/.config/nvim"
CURRENT_DIR="$(pwd)"

echo -e "${BLUE}Setting up configuration directory...${NC}"
mkdir -p "$HOME/.config"

if [ -d "$NVIM_CONFIG_DIR" ]; then
    if [ -L "$NVIM_CONFIG_DIR" ]; then
        echo -e "${YELLOW}Existing symlink found at $NVIM_CONFIG_DIR. Replacing it...${NC}"
        rm "$NVIM_CONFIG_DIR"
    else
        BACKUP_DIR="${NVIM_CONFIG_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}Existing config found at $NVIM_CONFIG_DIR. Backing up to $BACKUP_DIR...${NC}"
        mv "$NVIM_CONFIG_DIR" "$BACKUP_DIR"
    fi
fi

# Link the current directory to ~/.config/nvim
# This ensures lua/plugins/ and init.lua are in the correct place for Neovim to find them.
echo -e "${BLUE}Linking $CURRENT_DIR to $NVIM_CONFIG_DIR...${NC}"
ln -s "$CURRENT_DIR" "$NVIM_CONFIG_DIR"

echo -e "${GREEN}Installation complete!${NC}"
echo -e "${BLUE}You can now start Neovim by typing: ${NC}nvim"
echo -e "${YELLOW}Note: The first run will automatically install plugins via lazy.nvim.${NC}"
