homebrew_prefix=$(brew --prefix)

# Guard against ZELLIJ_SESSION_NAME getting out of sync (see issues/002).
#
# ZELLIJ_SESSION_NAME can become stale for two reasons:
#   1. mise hook-env corruption — `cd` triggers mise's chpwd hook which
#      rewrites the environment and can overwrite ZELLIJ_SESSION_NAME with
#      a zombie/nonexistent session name.
#   2. Session renames — `zellij action rename-session` changes the socket
#      filename on disk but doesn't update ZELLIJ_SESSION_NAME in existing
#      shell processes.
#
# When ZELLIJ_SESSION_NAME points to a stale name, `zellij action` commands
# hang forever because they can't find the IPC socket.
#
# There's no zellij CLI to ask "which session is this pane in", so we derive
# it from the process tree and filesystem:
#   1. Walk up from $$ to find the `zellij --server <socket-path>` ancestor.
#   2. Get that server process's start time (epoch seconds via ps).
#   3. Compare against the birth time of each socket file in the zellij
#      socket directory (epoch seconds via stat -f %B).
#   4. The socket whose birth time matches is our session — its filename
#      is the current session name.
#
# This works because zellij creates the socket at server startup, and
# rename() preserves the file's birth time. So even after a session rename,
# the socket's birth time still matches the server process that created it.
if [[ -n "$ZELLIJ" && -n "$ZELLIJ_SESSION_NAME" ]]; then
  _zellij_resolve_session() {
    # Walk up process tree to find the zellij --server ancestor.
    local pid=$$ ppid cmd server_pid sock_path
    while (( pid > 1 )); do
      ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
      cmd=$(ps -o command= -p "$ppid" 2>/dev/null)
      if [[ "$cmd" == *"zellij --server "* ]]; then
        server_pid="$ppid"
        sock_path="${cmd##*--server }"
        break
      fi
      pid=$ppid
    done
    [[ -z "$server_pid" ]] && return 1

    local sock_dir="${sock_path%/*}"
    # Get server start time as epoch seconds.
    local server_epoch
    server_epoch=$(ps -o lstart= -p "$server_pid" 2>/dev/null)
    server_epoch=$(date -j -f "%a %d %b %H:%M:%S %Y " "$server_epoch " +%s 2>/dev/null)
    [[ -z "$server_epoch" ]] && return 1

    # Find the socket whose birth time matches the server's start time.
    local sock sock_epoch
    for sock in "$sock_dir"/*; do
      sock_epoch=$(stat -f %B "$sock" 2>/dev/null)
      if [[ "$sock_epoch" == "$server_epoch" ]]; then
        echo "${sock##*/}"
        return
      fi
    done
    return 1
  }

  _zellij_session_guard() {
    local real_name
    real_name=$(_zellij_resolve_session) || return
    if [[ "$ZELLIJ_SESSION_NAME" != "$real_name" ]]; then
      echo "[zellij] ZELLIJ_SESSION_NAME was '${ZELLIJ_SESSION_NAME}', restored to '${real_name}'"
      export ZELLIJ_SESSION_NAME="$real_name"
    fi
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _zellij_session_guard
fi

# Set up spaceship prompt
SPACESHIP_CHAR_SYMBOL="➜  "
SPACESHIP_PROMPT_ADD_NEWLINE="false"
SPACESHIP_GIT_STATUS_COLOR="yellow"

# Custom dir section that trims the branch slug from worktree directory names.
# wt names worktree directories as <label>.<branch-slug>; this shows just <label>.
spaceship_dir_short() {
  local dir="${PWD##*/}"

  local toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$toplevel" && -f "$toplevel/.git" ]]; then
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
      local slug="${branch//\//-}"
      dir="${dir%.${slug}}"
    fi
  fi

  spaceship::section \
    --color "cyan" \
    "$dir"
}

# Custom function to shorten Linear branch names and use a worktree icon.
# mikefisher/onc-9436-save-contact-card-banner-will-not-disappear-in-app -> onc-9436-save-contact-card-banner
spaceship_git_branch_short() {
  local branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  [[ -z "$branch" ]] && return

  # Use nf-fa-tree icon in worktrees instead of the default branch icon.
  # Worktrees have a .git file (not directory) pointing to the main repo.
  local icon="$SPACESHIP_GIT_BRANCH_PREFIX"
  local toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -f "$toplevel/.git" ]]; then
    icon=$'\uf1bb '
  fi

  # If branch matches Linear format, shorten it
  if [[ "$branch" =~ ^[^/]+/(onc-[0-9]+-[^-]+-[^-]+-[^-]+) ]]; then
    branch="${match[1]}"
  fi

  spaceship::section \
    --color "magenta" \
    --prefix " ${icon}" \
    --suffix " " \
    "$branch"
}

# Hide the default git branch, we'll use our custom one
SPACESHIP_GIT_BRANCH_SHOW=false

SPACESHIP_PROMPT_ORDER=(
  dir_short
  git_branch_short
  git

  golang
  node

  exec_time
  line_sep
  jobs
  exit_code
  char
)

setopt no_share_history
setopt extended_glob

alias ls="ls --color"
alias l="ls -Glah"
alias g="git"
alias kb="kubectl"
alias dc="docker-compose"
alias goland="nohup /opt/homebrew/bin/goland . &> /dev/null &"
alias tf="terraform"

# Attach to or create a zellij session named after the current directory.
# If attach fails (e.g. resurrection parse error zellij#4673),
# kills the broken session and starts fresh with --layout repo.
za() {
  local session_name="${PWD##*/}"
  if zellij list-sessions -n 2>/dev/null | grep -q "^${session_name} "; then
    echo "Found existing '${session_name}' session, trying to attach..."
    zellij attach "$session_name"
    if [[ $? -ne 0 ]]; then
      echo "Attach failed, killing broken session '$session_name' and starting fresh..."
      zellij kill-session "$session_name"
      zellij delete-session "$session_name" 2>/dev/null
      # -n not -l: --layout + --session adds tabs to an existing session
      # instead of creating one (zellij 0.43+).
      zellij --session "$session_name" --new-session-with-layout repo
    fi
  else
    echo "No existing '${session_name} found, creating..."
    zellij --session "$session_name" --new-session-with-layout repo
  fi
}

# Kill any existing session named after the current directory and start fresh.
# Useful when you don't want to resurrect a stale or broken session.
zn() {
  local session_name="${PWD##*/}"
  if zellij list-sessions -n 2>/dev/null | grep -q "^${session_name} "; then
    echo "Destroying existing '${session_name}' session..."
    zellij kill-session "$session_name"
    zellij delete-session "$session_name" 2>/dev/null
  else
    echo "No existing '${session_name}' session found"
  fi
  echo "Creating session..."
  zellij --session "$session_name" --new-session-with-layout repo
}

# Switch to a worktree in a new zellij tab, creating the branch if needed.
# wt switch cds to the worktree via directives; cd back before running
# zellij action so mise/direnv restore the original env (otherwise hangs)
ws() {
  local main="$PWD"
  # Try switching to existing worktree; if it doesn't exist, create one.
  # If the branch exists on the remote, fetch it and use it as the base
  # so the local branch tracks the remote (e.g. for existing PRs).
  if ! wt switch $1 2>/dev/null; then
    if git ls-remote --heads origin "$1" | grep -q "$1"; then
      git fetch origin "$1"
      wt switch --create $1 --base "origin/$1"
    else
      # Fetch latest master so new branches start from upstream HEAD.
      git fetch origin master
      wt switch --create $1 --base origin/master
    fi
  fi
  local wt_path="$PWD"
  cd "$main"
  # Restore ZELLIJ_SESSION_NAME if mise hook-env corrupted it during wt switch (see issues/002).
  _zellij_session_guard
  zellij action new-tab --layout repo --cwd "$wt_path"
}

# Enable tab completion
autoload -Uz compinit && compinit

# Install scripts
. $HOME/.zsh.d/z.sh

# Enable spaceship
source ${homebrew_prefix}/opt/spaceship/spaceship.zsh
# Enable mise
eval "$(mise activate zsh)"

# Navigate between "words" with option+(left|right)
# Requires alt+left and alt+right to be unbound in Ghostty config
# vi-style widgets stop at punctuation and whitespace
bindkey '^[[1;3D' vi-backward-word
bindkey '^[[1;3C' vi-forward-word


if [ -d "${homebrew_prefix}/share/google-cloud-sdk" ]; then
  source "${homebrew_prefix}/share/google-cloud-sdk/path.zsh.inc"
  source "${homebrew_prefix}/share/google-cloud-sdk/completion.zsh.inc"
fi

export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
export PATH="$HOME/bin:$HOME/.local/bin:/opt/homebrew/bin:$PATH"

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
