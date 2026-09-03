[[ -f ~/.config/zsh/oh-my-zsh.zsh ]] && source ~/.config/zsh/oh-my-zsh.zsh
[[ -f ~/.config/zsh/aliases.zsh ]] && source ~/.config/zsh/aliases.zsh
[[ -f ~/.config/zsh/functions.zsh ]] && source ~/.config/zsh/functions.zsh

eval "$(zoxide init --cmd cd zsh)"