alias dotfiles="/usr/bin/git --git-dir=\$HOME/.dotfiles/ --work-tree=\$HOME"
alias df="dotfiles"
alias dfa="df add"
alias dfc="df commit -m"
alias dfp="df push"

alias tf="terraform"
alias ls="eza --color=always --icons=always"

alias gg="gen-gitops"
alias ggu="gg self-update"
alias ggi="gg config import"
alias ggc="gg get-credentials"