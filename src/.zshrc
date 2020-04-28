export ANDROID_HOME=~/Library/Android/sdk

# Set $PATH
path+=/usr/local/heroku/bin
path+=/usr/local/sbin
path+=$HOME/bin
path+=$HOME/.npm/bin
path+=$HOME/.composer/vendor/bin
path+=$HOME/.phpenv/bin
path+=$HOME/anaconda3/bin
path+=$HOME/.nvm
path+=$ANDROID_HOME/tools/bin
path+=$ANDROID_HOME/platform-tools
path+=$HOME/Library/Python/3.7/bin

# Strip out $PATH dirs that don't exist
path=($^path(N))

# This needs to be separate. If you're not in a directory with node_modules when zsh
# starts, the `^path` above will remove it.
export PATH=./node_modules/.bin:$PATH

# We add these separately to be sure they come first, to override macOS binaries
export PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/Cellar/findutils/4.6.0/libexec/gnubin:/usr/local/Cellar/gnu-tar/1.32/libexec/gnubin:$PATH

# Remove duplicates from $PATH
typeset -U path

# pyenv
if which pyenv > /dev/null; then eval "$(pyenv init -)"; fi
if which pyenv virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

# nvm
export NVM_AUTO_USE=true NVM_LAZY_LOAD=true

# plugins
source ~/.antigen.zsh

antigen use oh-my-zsh

antigen bundles <<EOBUNDLES
  kubectl
  zsh-users/zsh-syntax-highlighting
  zsh-users/zsh-completions
  lukechilds/zsh-nvm
  gpg-agent
EOBUNDLES

antigen theme denysdovhan/spaceship-prompt
antigen apply

SPACESHIP_CHAR_SYMBOL="➜  "
SPACESHIP_PROMPT_ADD_NEWLINE="false"
SPACESHIP_GIT_STATUS_COLOR="yellow"

SPACESHIP_PROMPT_ORDER=(
  dir
  git
  pyenv
  node
  exec_time
  line_sep
  jobs
  exit_code
  char
)

setopt no_share_history

alias ls="ls --color"
alias l="ls -Glah"
alias g="git"
alias kb="kubectl"
alias dc="docker-compose"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# direnv
eval "$(direnv hook zsh)"

# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[[ -f /Users/mike.fisher/git-projects/pick-n-done-apis/node_modules/tabtab/.completions/serverless.zsh ]] && . /Users/mike.fisher/git-projects/pick-n-done-apis/node_modules/tabtab/.completions/serverless.zsh
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[[ -f /Users/mike.fisher/git-projects/pick-n-done-apis/node_modules/tabtab/.completions/sls.zsh ]] && . /Users/mike.fisher/git-projects/pick-n-done-apis/node_modules/tabtab/.completions/sls.zsh
# tabtab source for slss package
# uninstall by removing these lines or running `tabtab uninstall slss`
[[ -f /Users/mike.fisher/git-projects/pick-n-done-apis/node_modules/tabtab/.completions/slss.zsh ]] && . /Users/mike.fisher/git-projects/pick-n-done-apis/node_modules/tabtab/.completions/slss.zsh

#OktaAWSCLI
if [[ -f "$HOME/.okta/bash_functions" ]]; then
    . "$HOME/.okta/bash_functions"
fi
if [[ -d "$HOME/.okta/bin" && ":$PATH:" != *":$HOME/.okta/bin:"* ]]; then
    PATH="$HOME/.okta/bin:$PATH"
fi

# aws-ask
export AWS_SDK_LOAD_CONFIG=true AWS_CONFIG_FILE=~/.aws/config

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"
