# Set Spaceship ZSH as a prompt
autoload -U promptinit; promptinit
prompt spaceship

SPACESHIP_CHAR_SYMBOL="➜  "
SPACESHIP_PROMPT_ADD_NEWLINE="false"
SPACESHIP_GIT_STATUS_COLOR="yellow"

SPACESHIP_PROMPT_ORDER=(
  dir
  git
  exec_time
  line_sep
  jobs
  exit_code
  char
)

alias l="ls -Glah"
alias g="git"
alias kb="kubectl"

# Set $PATH
path+=/usr/local/heroku/bin
path+=/usr/local/sbin
path+=$HOME/bin
path+=$HOME/.npm/bin
path+=$HOME/.composer/vendor/bin
path+=$HOME/.phpenv/bin
path+=$HOME/anaconda3/bin
path+=$HOME/.nvm

# Strip out $PATH dirs that don't exist
path=($^path(N))

# This needs to be separate. If you're not in a directory with node_modules when zsh
# starts, the `^path` above will remove it.
export PATH=./node_modules/.bin:$PATH

# Remove duplicates from $PATH
typeset -U path

# pyenv
if which pyenv > /dev/null; then eval "$(pyenv init -)"; fi
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
