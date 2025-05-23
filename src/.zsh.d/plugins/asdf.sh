# See "ZSH & Git" https://asdf-vm.com/guide/getting-started.html#_3-install-asdf

. "$HOME/.asdf/asdf.sh"

# append completions to fpath
fpath=(${ASDF_DIR}/completions $fpath)
# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit