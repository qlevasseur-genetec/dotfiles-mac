brew() {
  # Call the real Homebrew binary using command to avoid recursion
  command brew "$@"
  local exit_code=$?

  # Check if the command succeeded and matches a state-modifying action
  if [ $exit_code -eq 0 ]; then
    case "$1" in
      install|reinstall|uninstall|upgrade|tap|untap)
        echo "--> Updating Brewfile..."
        # Update the Brewfile in your home directory (change path if needed)
        command brew bundle dump --force --file="$HOME/.config/Brewfile"
        ;;
    esac
  fi

  return $exit_code
}