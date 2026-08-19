#!/usr/bin/env bash
set -e

# ==============================================================================
# CONFIGURATION
# ==============================================================================
DOTFILES_REPO="https://github.com/qlevasseur-genetec/dotfiles-mac.git"
DOTFILES_DIR="$HOME/.dotfiles"
BREWFILE_PATH="$HOME/.config/.Brewfile"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

echo "==> Starting machine bootstrap..."

# ==============================================================================
# DEPENDENCY VALIDATION & PREREQUISITES
# ==============================================================================
echo "==> Validating prerequisites..."

# 1. macOS: Ensure Xcode Command Line Tools are installed (provides git, make, etc.)
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! xcode-select -p &>/dev/null; then
    echo "==> Xcode Command Line Tools not found. Installing..."
    xcode-select --install
    echo "==> Please complete the Command Line Tools installation prompt, then re-run this script."
    exit 1
  fi
fi

# 2. Check for required core CLI tools
REQUIRED_TOOLS=("curl" "git")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    MISSING_TOOLS+=("$tool")
  fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  echo "Error: Missing required tools: ${MISSING_TOOLS[*]}"
  echo "Please install them via your system package manager (e.g., apt, dnf, pacman) and re-run."
  exit 1
fi

# ==============================================================================
# 1. INSTALL HOMEBREW & PACKAGES
# ==============================================================================
if ! command -v brew &>/dev/null; then
  echo "==> Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Configure environment for Apple Silicon / Linuxbrew paths
  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
else
  echo "==> Homebrew is already installed."
fi

# ==============================================================================
# 2. SETUP BARE GIT DOTFILES REPO
# ==============================================================================
echo "==> Setting up dotfiles..."
# Better (uses whatever git resolved in your $PATH)
function dotfiles {
  git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
}

if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "==> Cloning bare dotfiles repository..."
  git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  echo "==> Dotfiles repository already exists at $DOTFILES_DIR."
fi

# Attempt checkout; back up conflicting files if checkout fails
mkdir -p "$HOME/.dotfiles-backup"
if ! dotfiles checkout 2>/dev/null; then
  echo "==> Existing files conflict with dotfiles repo. Moving conflicts to ~/.dotfiles-backup..."
  dotfiles checkout 2>&1 | grep -E "^\s+\." | awk '{print $1}' | while read -r file; do
    mkdir -p "$HOME/.dotfiles-backup/$(dirname "$file")"
    mv "$HOME/$file" "$HOME/.dotfiles-backup/$file"
  done
  dotfiles checkout
fi

dotfiles config --local status.showUntrackedFiles no
echo "==> Dotfiles checked out successfully."

# ==============================================================================
# 3. INSTALL PACKAGES FROM BREWFILE
# ==============================================================================
if [[ -f "$BREWFILE_PATH" ]]; then
  echo "==> Installing packages from $BREWFILE_PATH..."
  brew bundle --file="$BREWFILE_PATH"
else
  echo "==> No Brewfile found at $BREWFILE_PATH. Skipping bundle install."
fi

# ==============================================================================
# 4. INSTALL POWERLEVEL10K THEME
# ==============================================================================
echo "==> Setting up Powerlevel10k..."
P10K_DIR="${ZSH_CUSTOM}/themes/powerlevel10k"

if [[ ! -d "$P10K_DIR" ]]; then
  echo "==> Cloning powerlevel10k into $P10K_DIR..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  echo "==> Powerlevel10k is already installed."
fi

# ==============================================================================
# COMPLETION
# ==============================================================================
echo "==> Bootstrap complete! Restart your shell or run: exec zsh"