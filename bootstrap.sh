#!/usr/bin/env bash
set -e

# ==============================================================================
# CONFIGURATION
# ==============================================================================
DOTFILES_REPO="https://github.com/qlevasseur-genetec/dotfiles-mac.git"
DOTFILES_DIR="$HOME/.dotfiles"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
USE_LOCAL_SOURCE=false
BREWFILE_PATH="$HOME/.config/.Brewfile"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ZSHENV_PATH="$HOME/.zshenv"
ZSHENV_SOURCE="$HOME/.config/zsh/.zshenv"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)
      USE_LOCAL_SOURCE=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--local]"
      echo "  --local  Use the folder containing this script instead of cloning from Git."
      exit 0
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      echo "Usage: $0 [--local]" >&2
      exit 1
      ;;
  esac
done

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
  if [[ "$USE_LOCAL_SOURCE" == true ]]; then
    echo "==> Creating bare dotfiles repository from $SCRIPT_DIR..."
    git init --bare "$DOTFILES_DIR" >/dev/null
    git -c user.name="Local Bootstrap" -c user.email="local-bootstrap@localhost" \
      --git-dir="$DOTFILES_DIR" --work-tree="$SCRIPT_DIR" add -A
    git -c user.name="Local Bootstrap" -c user.email="local-bootstrap@localhost" \
      --git-dir="$DOTFILES_DIR" --work-tree="$SCRIPT_DIR" commit --allow-empty -m "Import local dotfiles snapshot" >/dev/null
  else
    echo "==> Cloning bare dotfiles repository..."
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi
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

# Ensure zsh loads the tracked environment file from its XDG config location.
if [[ ! -L "$ZSHENV_PATH" ]]; then
  if [[ -e "$ZSHENV_PATH" ]]; then
    echo "==> Backing up existing $ZSHENV_PATH before creating symlink..."
    mv "$ZSHENV_PATH" "$HOME/.dotfiles-backup/.zshenv"
  fi
  ln -s "$ZSHENV_SOURCE" "$ZSHENV_PATH"
elif [[ "$(readlink "$ZSHENV_PATH")" != "$ZSHENV_SOURCE" ]]; then
  rm "$ZSHENV_PATH"
  ln -s "$ZSHENV_SOURCE" "$ZSHENV_PATH"
fi

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
# 5. AZURE CLI AUTH, EXTENSIONS & INTERNAL TOOL INSTALL
# ==============================================================================
echo "==> Configuring Azure DevOps environment..."

# Ensure Azure CLI is available (must be in your Brewfile: brew "azure-cli")
if ! command -v az &>/dev/null; then
  echo "Error: 'az' CLI not found. Ensure 'azure-cli' is installed via Homebrew."
  exit 1
fi

# 1. Check Azure login state; prompt login if not authenticated
echo "==> Checking Azure CLI authentication..."
if ! az account show &>/dev/null; then
  echo "==> Not logged into Azure. Launching browser login..."
  az login --output none
else
  echo "==> Azure CLI already authenticated."
fi

# 2. Install/update the Azure DevOps extension
echo "==> Installing/updating Azure DevOps extension..."
if az extension list --query "[?name=='azure-devops']" -o tsv | grep -q azure-devops; then
  az extension update --name azure-devops --output none
else
  az extension add --name azure-devops --output none
fi

# Set default organization/project if desired (optional)
# az devops configure --defaults organization="https://dev.azure.com/YOUR_ORG"

# 3. Run command to install your internal tool
echo "==> Installing internal tooling..."

bash <(curl -s -H "Authorization: Bearer $(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)" "https://dev.azure.com/GenetecCentral/a2aab280-e5dd-41a2-ba9c-adb9a9c0716a/_apis/git/repositories/9df43119-f938-4222-8855-0972efcbe442/items?download=true&path=/src/scripts/install.sh&api-version=7.0&versionDescriptor.version=main&versionDescriptor.versionType=branch")

echo "==> Internal tools installed successfully."

# ==============================================================================
# COMPLETION
# ==============================================================================
echo "==> Bootstrap complete! Restart your shell or run: exec zsh"
