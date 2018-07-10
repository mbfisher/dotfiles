if [ ! -d ~/.oh-my-zsh ] ; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
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
