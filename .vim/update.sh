#!/bin/bash

BUNDLES="scrooloose/syntastic
Lokaltog/vim-powerline
tpope/vim-repeat
goldfeld/vim-seek
tpope/vim-sensible
tpope/vim-surround
altercation/vim-colors-solarized
mustache/vim-mustache-handlebars
stephpy/vim-php-cs-fixer
tomasr/molokai
airblade/vim-gitgutter
docteurklein/php-getter-setter.vim
kien/ctrlp.vim
mtth/locate.vim
nathanaelkane/vim-indent-guides
chase/vim-ansible-yaml
kchmck/vim-coffee-script
mxw/vim-jsx"

mkdir -p ~/.vim/bundle ~/.vim/autoload

echo `tput setaf 7`Updating pathogen`tput sgr0`
curl -o ~/.vim/autoload/pathogen.vim \
    https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim

for BUNDLE in $BUNDLES ; do
    cd ~/.vim/bundle
    REPO=${BUNDLE##*/}

    if [ -d $REPO ] ; then
        echo `tput setaf 7`Updating $REPO`tput sgr0`
        cd $REPO && git pull
    else
        echo `tput setaf 7`Installing $REPO`tput sgr0`
        git clone https://github.com/$BUNDLE
    fi
done
