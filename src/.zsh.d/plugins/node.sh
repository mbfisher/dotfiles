# nvm
MBF_BUNDLES+=(
  lukechilds/zsh-nvm
)

MBF_PROMPT_TOOLS+=(
  node
)

export NVM_AUTO_USE=true

# This needs to be separate. If you're not in a directory with node_modules when zsh
# starts, the `^path` above will remove it.
export PATH=./node_modules/.bin:$PATH

# See https://github.com/nvm-sh/nvm#calling-nvm-use-automatically-in-a-directory-with-a-nvmrc-file

# load-nvmrc() {
#   local node_version="$(nvm version)"
#   local nvmrc_path="$(nvm_find_nvmrc)"

#   if [ -n "$nvmrc_path" ]; then
#     local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

#     if [ "$nvmrc_node_version" = "N/A" ]; then
#       nvm install
#     elif [ "$nvmrc_node_version" != "$node_version" ]; then
#       nvm use
#     fi
#   elif [ "$node_version" != "$(nvm version default)" ]; then
#     echo "Reverting to nvm default version"
#     nvm use default
#   fi
# }

# add-load-nvmrc-hook() {
#   autoload -U add-zsh-hook
#   add-zsh-hook chpwd load-nvmrc
#   load-nvmrc
# }

# MBF_HOOKS+=(
#   "add-load-nvmrc-hook"
# )
# load-nvmrc
