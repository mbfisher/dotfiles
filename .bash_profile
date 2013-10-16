# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set locale
export LANGUAGE="en_GB:en"
export LC_MESSAGES="en_GB.UTF-8"
export LC_CTYPE="en_GB.UTF-8"
export LC_COLLATE="en_GB.UTF-8"

# golang
export GOROOT=$HOME/go

# add to PATH
_PATH="
/usr/local/heroku/bin
$HOME/.local/bin
$HOME/bin
/pear/bin
$HOME/src/google_appengine
$GOROOT/bin
$HOME/perl5/bin
/opt/vagrant/bin"

for p in $_PATH ; do
  if [[ "$p" != "\n" && "$p" != "" ]] ; then
    if [ "$( echo $PATH | grep $p )" = "" ] ; then
      PATH=$PATH:$p
    else
      echo "PATH: skipping [$p]"
    fi
  fi
done
export PATH

# Add ssh identity
eval $(keychain --eval --agents ssh -Q --quiet ~/.ssh/id_rsa)

# Activate perlbrew
source ~/perl5/perlbrew/etc/bashrc

# Activate virutalenvwrapper
export WORKON_HOME=$HOME/.virtualenv
source /usr/bin/virtualenvwrapper.sh
