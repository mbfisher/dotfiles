if [ -z $HOME/.oh-my-zsh ] ; then
    git clone https://github.com/oh-my-zsh $HOME/.oh-my-zsh
else
    GIT_DIR=$HOME/.oh-my-zsh/.git git pull origin master
fi

FILES=`find -type f | grep -v ".git/\|README\|install.sh" | sed 's/^\.\///' | grep "$1"`

for FILE in $FILES ; do
    echo Installing $FILE
    rm -f ~/$FILE
    mkdir -p ~/`dirname $FILE`
    ln -sf $PWD/$FILE ~/$FILE
done

cd ~/.vim && ./update.sh && cd -
