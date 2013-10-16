###### UTILS ######

alias rm='rm -i'
alias vi="vim"
alias tree='tree --dirsfirst'

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias lh='ls -lh'
alias lt='ls -slart'

###### SHORTCUTS ######
alias selenium='java -jar $HOME/bin/selenium-server-standalone-2.20.0.jar'
alias json="python -mjson.tool"
alias psg="ps aux | grep "
alias review="$HOME/bin/review.py -s codereview.geekology.ltd.uk"

# Perl
alias prove='prove -vlm'

alias yaourt='yaourt --noconfirm'

function skill() {
  pid=$( ps aux | grep "ssh $1" | grep -v grep | tr ' ' "\n" | grep -v '^$' | head -2 | tail -1 )
  if [ "$pid" != "" ] ; then
    kill $pid
    if [ $? -eq 0 ] ; then
      echo "Killed $pid"
    fi
  else
    echo "Nothing to kill"
  fi
}

function kkh {
  sed -i "$1d" ~/.ssh/known_hosts
}

alias urxvt='urxvt -e zsh -c "exec tmux new-session"'
