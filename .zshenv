# Set $PATH
path+=/usr/local/heroku/bin
path+=$HOME/bin
path+=$HOME/.local/bin
path+=$HOME/src/google_appengine
path+=$HOME/perl5/bin
path+=/opt/vagrant/bin
path+=$HOME/.npm/bin
path+=$HOME/.composer/vendor/bin

# Strip out $PATH dirs that don't exist
path=($^path(N))

# Remove duplicates from $PATH
typeset -U path

function mr {
  mv $1 `dirname $1`/$2
}

function vm {
    cd ~/git-projects/chef-solo && vagrant $@ && cd -
}
