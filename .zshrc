# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="robbyrussell"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable bi-weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment to change how often before auto-updates occur? (in days)
# export UPDATE_ZSH_DAYS=13

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want to disable command autocorrection
DISABLE_CORRECTION="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Uncomment following line if you want to disable marking untracked files under
# VCS as dirty. This makes repository status check for large repositories much,
# much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

if which pyenv > /dev/null; then eval "$(pyenv init -)"; fi
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

which rbenv > /dev/null && eval "$(rbenv init -)"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git composer systemd mercurial)

source $ZSH/oh-my-zsh.sh

# Customize to your needs...
#

setopt no_share_history

# Set $PATH
path+=/usr/local/heroku/bin
path+=$HOME/bin
path+=$HOME/.npm/bin
path+=$HOME/.composer/vendor/bin
path+=$HOME/.phpenv/bin
path+=$HOME/anaconda3/bin
path+=/usr/local/sbin

# Strip out $PATH dirs that don't exist
path=($^path(N))

# This needs to be separate. If you're not in a directory with node_modules when zsh
# starts, the `^path` above will remove it.
export PATH=./node_modules/.bin:$PATH

# Remove duplicates from $PATH
typeset -U path

export EDITOR="vim"
export BROWSER="chromium"

bindkey "^[[7~" beginning-of-line
bindkey "^[[8~" end-of-line

docker-machine ls | grep default && [ "$(docker-machine status default)" = "Running" ] && eval $(docker-machine env default)
