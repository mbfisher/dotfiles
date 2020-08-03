MBF_PROMPT_TOOLS+=kubecontext

autoload -U add-zsh-hook
use-kubectl() {
  if find-up .kubectl > /dev/null; then
    export SPACESHIP_KUBECTL_SHOW=true
    export SPACESHIP_KUBECONTEXT_SHOW=true
  else 
    export SPACESHIP_KUBECTL_SHOW=false
    export SPACESHIP_KUBECONTEXT_SHOW=false
  fi
}
add-zsh-hook -Uz chpwd use-kubectl