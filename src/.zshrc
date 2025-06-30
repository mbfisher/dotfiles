log() {
  [ "$MBF_DEBUG" != "" ] && echo "> $@"
  eval $@ 
}

# Set up spaceship prompt
SPACESHIP_CHAR_SYMBOL="➜  "
SPACESHIP_PROMPT_ADD_NEWLINE="false"
SPACESHIP_GIT_STATUS_COLOR="yellow"

SPACESHIP_PROMPT_ORDER=(
  dir
  git
  node
  ruby
  golang
  python
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

eval "$(~/.local/bin/mise activate zsh)"
source $(brew --prefix)/opt/spaceship/spaceship.zsh
