# To use this plugin:
# Install jenv
# - brew install jenv
# Install java versions
# - brew tap adoptopenjdk/openjdk
# - brew cask install adoptopenjdk8
# Add java versions to jenv
# - jenv add /Library/Java/JavaVirtualMachines/*/Contents/Home

path+=$HOME/.jenv/bin
eval "$(jenv init -)"