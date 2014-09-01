if [ ! -d ~/.oh-my-zsh ] ; then
    git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh
else
    GIT_DIR=~/.oh-my-zsh/.git git pull origin master
fi

if uname -a | grep Darwin >/dev/null; then
    FIND="find . -type f"
else
    FIND="find -type f"
fi

FILES=`$FIND | grep -v ".git/\|README\|install.sh" | sed 's/^\.\///' | grep "$1"`

for FILE in $FILES ; do
    echo Installing $FILE
    rm -f ~/$FILE
    mkdir -p ~/`dirname $FILE`
    echo "$PWD/$FILE ~/$FILE"
    ln -sf $PWD/$FILE ~/$FILE
done

mkdir ~/.vim/.swp
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
    curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

cd ~/.vim && ./update.sh; cd -

cd ~/.vim/bundle/Command-T/ruby/command-t/ && /usr/bin/ruby extconf.rb && make; cd -
