homebrew_prefix=$(brew --prefix)

# Set up spaceship prompt
SPACESHIP_CHAR_SYMBOL="➜  "
SPACESHIP_PROMPT_ADD_NEWLINE="false"
SPACESHIP_GIT_STATUS_COLOR="yellow"

SPACESHIP_PROMPT_ORDER=(
  dir
  git

  golang
  node

  exec_time
  line_sep
  jobs
  exit_code
  char
)

setopt no_share_history
setopt extended_glob

alias ls="ls --color"
alias l="ls -Glah"
alias g="git"
alias kb="kubectl"
alias dc="docker-compose"
alias goland="nohup /opt/homebrew/bin/goland . &> /dev/null &"

# Enable tab completion
autoload -Uz compinit && compinit

# Install scripts
. $HOME/.zsh.d/z.sh

# Enable spaceship
source ${homebrew_prefix}/opt/spaceship/spaceship.zsh
# Enable mise
eval "$(mise activate zsh)"

# Navigate between "words" with option+(left|right)
# Requires alt+left and alt+right to be unbound in Ghostty config
# Define what a "word" means
# See https://zsh.sourceforge.io/Doc/Release/User-Contributions.html#index-match_002dwords_002dby_002dstyle
autoload -U select-word-style
select-word-style shell
# Bind built-in word movement to Option+arrow keys
# Option+Left Arrow
bindkey '^[[1;3D' backward-word
# Option+Right Arrow
bindkey '^[[1;3C' forward-word


if [ -d "${homebrew_prefix}/share/google-cloud-sdk" ]; then
  source "${homebrew_prefix}/share/google-cloud-sdk/path.zsh.inc"
  source "${homebrew_prefix}/share/google-cloud-sdk/completion.zsh.inc"
fi

export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
export PATH="$HOME/bin":$PATH
