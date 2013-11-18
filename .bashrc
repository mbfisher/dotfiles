# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

userhost='\[\033[31m\][\u@\h]\[\033[0m\]'
cwd='\[\033[34m\]\W\[\033[0m\]'
vcp_branch='\[\033[32m\]$( vcp=`vcprompt --format=%s:%b` ; [ "$vcp" != "" ] && echo " $vcp" )\[\033[0m\]'
vcp_state='\[\033[33m\]$( vcprompt --format=%u%a%m )\[\033[0m\]'
PS1="$cwd$vcp_branch$vcp_state $> "

# Alias definitions.
[ -f ~/.bash_aliases ] && . ~/.bash_aliases

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi
# other bash completions
source /usr/share/git/completion/git-completion.bash

# Perl
source /usr/share/git/completion/git-completion.bash
export PERL_LOCAL_LIB_ROOT="/home/mbfisher/perl5";
export PERL_MB_OPT="--install_base /home/mbfisher/perl5";
export PERL_MM_OPT="INSTALL_BASE=/home/mbfisher/perl5";
export PERL5LIB="/home/mbfisher/perl5/lib/perl5/x86_64-linux-gnu-thread-multi:/home/mbfisher/perl5/lib/perl5";
#export PATH="/home/mbfisher/perl5/bin:$PATH";

# provide a default editor for yaourt
export EDITOR="vim"

# Shortcut function for activating python virtualenvs
# Usage:
#   pyv $VERSION
function pyv {
  v=$1
  activate=/opt/python/env/$1/bin/activate
  if [ -f $activate ] ; then
    source $activate
  else
    echo "Version $v not found!"
    return 1
  fi
}
export -f pyv

# Use vim key bindings
set -o vi

# Activate RVM
#source ~/.rvm/scripts/rvm
