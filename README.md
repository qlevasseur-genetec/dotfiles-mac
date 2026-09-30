# Dotfiles

A minimalist, symlink-free dotfiles configuration managed via a bare Git repository, paired with an automated bootstrap.sh script to set up a new machine from scratch.

## Features

- No Symlinks Required: Uses a bare Git repo targeting $HOME directly.
- Automated Bootstrapping: Installs Homebrew, packages from ~/.Brewfile, and the Powerlevel10k theme.
- Safe Checkouts: Automatically backs up pre-existing configuration files to ~/.dotfiles-backup/ instead of overwriting them.
- Clean Status: Ignores untracked files in $HOME by default.

## Quick Start (New Machine Setup)

### Prerequisites

macOS: Xcode Command Line Tools (xcode-select --install)
Linux: git and curl installed via your system package manager

### Run the Bootstrap Script

Run the automated installation script directly from your terminal:

```Bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/qlevasseur-genetec/dotfiles-mac/refs/heads/main/bootstrap.sh)"
```

Alternatively, clone and run it locally:

```Bash
git clone --bare https://github.com/qlevasseur-genetec/dotfiles-mac.git $HOME/.dotfiles
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
dotfiles checkout
chmod +x ~/bootstrap.sh
~/bootstrap.sh
```

To bootstrap from an extracted zip of this repository without cloning from GitHub,
run the script from the extracted folder with the local-source flag:

```bash
bash ./bootstrap.sh --local
```

## Day-to-Day Usage

Manage your configurations using the dotfiles alias exactly like standard git:

### Tracking New Files

```bash
dotfiles add ~/.zshrc
dotfiles add ~/.config/nvim/
dotfiles commit -m "Configure zsh and neovim"
dotfiles push
```

### Checking Status and Diff

```bash
dotfiles status
dotfiles diff
```

### Pulling Updates

```Bash
dotfiles pull
```

### Updating Homebrew Packages

When you install new tools, sync your Brewfile:

```Bash
brew bundle dump --force --describe --file=~/.Brewfile
dotfiles add ~/.Brewfile
dotfiles commit -m "Update Brewfile packages"
dotfiles push
```
