log () {
  [ "$MBF_DEBUG" != "" ] && echo "> $@"
}

# Set defaults
ZSHD=$HOME/.zsh.d
source $ZSHD/default.sh

# Load a profile
MBF_PROFILE=$(cat ~/.zsh.profile)
log "Using profile ${MBF_PROFILE}"
source $ZSHD/profiles/${MBF_PROFILE}.sh

MBF_PROMPT_TOOLS=()
MBF_HOOKS=()

# Apply each plugin in the profile
for plugin in $MBF_PLUGINS; do
  log "Applying plugin ${plugin}"
  source $ZSHD/plugins/${plugin}.sh
done

# Set up antigen
source ~/.antigen.zsh
log "antigen use oh-my-zsh"
antigen use oh-my-zsh

# Set antigen bundles
log "antigen bundles $MBF_BUNDLES"
printf '%s\n' "${MBF_BUNDLES[@]}" | antigen bundles

# Set theme
# Check we haven't already sourced the theme before sourcing it again
if ! antigen list | grep $MBF_THEME > /dev/null; then
  log "antigen theme $MBF_THEME"
  antigen theme $MBF_THEME
fi

# Apply antigen
log "antigen apply"
antigen apply

# Set up spaceship prompt
SPACESHIP_CHAR_SYMBOL="➜  "
SPACESHIP_PROMPT_ADD_NEWLINE="false"
SPACESHIP_GIT_STATUS_COLOR="yellow"

log "Setting spaceship prompt: $MBF_PROMPT_TOOLS"
SPACESHIP_PROMPT_ORDER=(
  dir
  git
  $MBF_PROMPT_TOOLS
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

# Show the PWD in iTerm tab title
# https://gist.github.com/phette23/5270658

export DISABLE_AUTO_TITLE="true"
function precmd () {
  window_title="\033]0;${PWD##*/}\007"
  echo -ne "$window_title"
}

for hook in $MBF_HOOKS; do
  echo "Running hook ${hook}"
  $hook
done
