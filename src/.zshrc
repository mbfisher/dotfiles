log() {
  [ "$MBF_DEBUG" != "" ] && echo "> $@"
  eval $@ 
}

# Set up antigen
source ~/.antigen.zsh
log antigen use oh-my-zsh

log antigen bundle zsh-users/zsh-syntax-highlighting
log antigen bundle zsh-users/zsh-completions
log antigen bundle kiurchv/asdf.plugin.zsh
log antigen bundle ptavares/zsh-direnv@main

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

MBF_THEME=denysdovhan/spaceship-prompt

# antigen apply hangs if we source the theme twice
if ! antigen list | grep $MBF_THEME > /dev/null; then
  log antigen theme $MBF_THEME
fi

# Apply antigen
log antigen apply

setopt no_share_history
setopt extended_glob

alias ls="ls --color"
alias l="ls -Glah"
alias g="git"
alias kb="kubectl"
alias dc="docker-compose"

# change to a directory without typing cd
setopt auto_cd
# add all git org directories to cdpath e.g. git-projects/github.com/mbfisher/foo, can do cd foo
cdpath=("${(@f)$(find $HOME/git-projects -type d -mindepth 2 -maxdepth 2)}")
