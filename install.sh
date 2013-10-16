FILES=`find -type f | grep -v ".git/\|README\|install.sh" | sed 's/^\.\///' | grep "$1"`

for FILE in $FILES ; do
    echo Installing $FILE
    rm -f ~/$FILE
    mkdir -p ~/`dirname $FILE`
    ln -sf $PWD/$FILE ~/$FILE
done
