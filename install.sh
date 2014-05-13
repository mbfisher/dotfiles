if [ -z ~/.oh-my-zsh ] ; then
    git clone https://github.com/robbyrussell/oh-my-zsh ~/.oh-my-zsh
else
    GIT_DIR=~/.oh-my-zsh/.git git pull origin master
fi

FILES=`find -type f | grep -v ".git/\|README\|install.sh" | sed 's/^\.\///' | grep "$1"`

for FILE in $FILES ; do
    echo Installing $FILE
    rm -f ~/$FILE
    mkdir -p ~/`dirname $FILE`
    ln -sf $PWD/$FILE ~/$FILE
done

cd ~/.vim && ./update.sh && cd -
