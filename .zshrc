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

export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python
export WORKON_HOME=~/.virtualenvs
alias yaourt="yaourt --noconfirm"


# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git composer systemd)

source $ZSH/oh-my-zsh.sh

# Customize to your needs...
#

setopt no_share_history

# Set $PATH
path+=/usr/local/heroku/bin
path+=$HOME/bin
path+=$HOME/.local/bin
path+=$HOME/src/google_appengine
path+=$HOME/perl5/bin
path+=/opt/vagrant/bin
path+=$HOME/.npm/bin
path+=$HOME/.composer/vendor/bin
path+=$HOME/.phpenv/bin

# Strip out $PATH dirs that don't exist
path=($^path(N))

# Remove duplicates from $PATH
typeset -U path

export EDITOR="vim"
export BROWSER="chromium"

#bindkey -v
bindkey "^[[7~" beginning-of-line
bindkey "^[[8~" end-of-line

#export DISABLE_AUTO_TITLE=true

eval "$(phpenv init -)"
source ~/.rvm/scripts/rvm
source /usr/bin/activate.sh

# added by travis gem
[ -f /Users/mif08/.travis/travis.sh ] && source /Users/mif08/.travis/travis.sh
