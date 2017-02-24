# Prepend to PATH
path=(/usr/local/bin $path)

# Append to PATH
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

function mr {
  mv $1 `dirname $1`/$2
}

alias ll='ls -lah'
