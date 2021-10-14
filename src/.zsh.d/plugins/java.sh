if ! which jenv > /dev/null; then
    echo "Installing jenv..."
    brew install jenv
    jenv enable-plugin export
    cat <<EOF
Next: start a new shell!

To install java versions:

$> brew tap adoptopenjdk/openjdk
$> brew install adoptopenjdk8 adoptopenjdk11
$> jenv add /Library/Java/JavaVirtualMachines/adoptopenjdk-8.jdk/Contents/Home/    
$> jenv add /Library/Java/JavaVirtualMachines/adoptopenjdk-11.jdk/Contents/Home/    
EOF
fi

# To use this plugin:
# Install jenv
# - brew install jenv


path+=$HOME/.jenv/bin
eval "$(jenv init -)"