#!/bin/bash
# CwdChanged and PostToolUse(EnterWorktree) hook: when a Claude session running inside zellij moves into a linked git
# worktree, open a repo-layout tab in that worktree whose claude pane forks this session, and rename the original pane
# so it reads as forked. EnterWorktree (used by /wt-switch-create) re-roots the session without firing CwdChanged,
# hence the second event. The fork itself happens in claude-pane, which picks up the handoff file written here; that
# keeps repo.kdl the single layout for both `ws` tabs and these.
[[ -n $ZELLIJ ]] || exit 0

input=$(cat)
sid=$(jq -r .session_id <<<"$input")
if [[ $(jq -r .hook_event_name <<<"$input") == PostToolUse ]]; then
  old=
  new=$(jq -r '.tool_response.worktreePath // .tool_input.path // empty' <<<"$input")
else
  old=$(jq -r .old_cwd <<<"$input")
  new=$(jq -r .new_cwd <<<"$input")
fi

new_top=$(git -C "$new" rev-parse --show-toplevel 2>/dev/null) || exit 0
# Linked worktrees have a .git file rather than a directory.
[[ -f $new_top/.git ]] || exit 0
if [[ -n $old ]]; then
  [[ $(git -C "$old" rev-parse --show-toplevel 2>/dev/null) != "$new_top" ]] || exit 0
fi

new_top=$(cd "$new_top" && pwd -P)
dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-handoff"
key=$(printf %s "$new_top" | shasum | cut -c1-16)
mkdir -p "$dir"
# Only open one tab per session and worktree, however often the session's cwd moves back and forth.
[[ -e $dir/done-$sid-$key ]] && exit 0
touch "$dir/done-$sid-$key"
printf %s "$sid" >"$dir/$key"

# Run zellij from $HOME so mise/direnv don't rewrite the env mid-action (see ws in .zshrc and issues/002).
cd "$HOME" || exit 0
zellij action new-tab --layout repo --cwd "$new_top" >/dev/null
[[ -n $ZELLIJ_PANE_ID ]] && zellij action rename-pane --pane-id "$ZELLIJ_PANE_ID" "forked → ${new_top##*/}"
exit 0
