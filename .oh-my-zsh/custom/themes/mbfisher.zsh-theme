pwd="%{$fg[blue]%}%~%{$reset_color%}"
git="%{$fg[red]%}\$(git_prompt_info)%{$reset_color%}"
local="%{$fg[yellow]%}%M:%n%{$reset_color%}"
prompt="%{$fg[white]%}$>%{$reset_color%} "
PROMPT="${pwd} ${git} ${local}
${prompt}"
