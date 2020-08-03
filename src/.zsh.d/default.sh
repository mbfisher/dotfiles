MBF_BUNDLES=(
  zsh-users/zsh-syntax-highlighting
  zsh-users/zsh-completions
)

MBF_THEME=denysdovhan/spaceship-prompt

MBF_PLUGINS=(
  direnv
  node
)

path+=(
  $HOME/bin
)

# We add these separately to be sure they come first, to override macOS binaries
export PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/Cellar/findutils/4.6.0/libexec/gnubin:/usr/local/Cellar/gnu-tar/1.32/libexec/gnubin:$PATH