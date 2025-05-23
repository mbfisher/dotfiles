# MBF_DEBUG=1
debug () {
  [ "$MBF_DEBUG" != "" ] && echo "> $@"
}

MBF_PROMPT_TOOLS=()
MBF_HOOKS=()

# Set defaults
ZSHD=$HOME/.zsh.d
source $ZSHD/default.sh

# Load a profile
if [ -f ~/.zsh.profile ]; then
  MBF_PROFILE=$(cat ~/.zsh.profile)
  debug "Using profile ${MBF_PROFILE}"
  source $ZSHD/profiles/${MBF_PROFILE}.sh
else
  debug "No ~/.zsh.profile, skipping"
fi

typeset -U $MBF_PLUGINS

# Apply each plugin in the profile
for plugin in $MBF_PLUGINS; do
  debug "Applying plugin ${plugin}"
  source $ZSHD/plugins/${plugin}.sh
done

# Set up antigen
source ~/.antigen.zsh

# Set antigen bundles
debug "antigen bundles $MBF_BUNDLES"
printf '%s\n' "${MBF_BUNDLES[@]}" | antigen bundles

# Set theme
# Check we haven't already sourced the theme before sourcing it again
if ! antigen list | grep $MBF_THEME > /dev/null; then
  debug "antigen theme $MBF_THEME"
  antigen theme $MBF_THEME
fi

# Apply antigen
debug "antigen apply"
antigen apply

# Set up spaceship prompt
SPACESHIP_CHAR_SYMBOL="➜  "
SPACESHIP_PROMPT_ADD_NEWLINE="false"
SPACESHIP_GIT_STATUS_COLOR="yellow"

debug "Setting spaceship prompt: $MBF_PROMPT_TOOLS"
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
  debug "Running hook ${hook}"
  $hook
done

# change to a directory without typing cd
setopt auto_cd
# add all git org directories to cdpath e.g. git-projects/github.com/mbfisher/foo, can do cd foo
cdpath=("${(@f)$(find $HOME/git-projects -type d -mindepth 2 -maxdepth 2)}")

# Created by `pipx` on 2024-01-22 14:42:52
export PATH="$PATH:/Users/mfisher/.local/bin"

# Added by Windsurf
export PATH="/Users/mfisher/.codeium/windsurf/bin:$PATH"
