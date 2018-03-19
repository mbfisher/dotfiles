if [ ! -d ~/.oh-my-zsh ] ; then
    git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh
else
    git -C ~/.oh-my-zsh pull origin master
fi

for FILE in $(find . -type f | grep -v ".git\/\|install.sh\|README" | sed 's/^\.\///'); do
    echo "Installing $FILE ~/$FILE"
    rm -f ~/$FILE
    mkdir -p ~/`dirname $FILE`
    ln -sf $PWD/$FILE ~/$FILE
done

#mkdir ~/.vim/.swp
#mkdir -p ~/.vim/autoload ~/.vim/bundle && \
#    curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

#cd ~/.vim && ./update.sh; cd -
