#!/bin/bash
input=$(cat)

# Debug: write input to file for inspection
echo "$input" > ~/.claude/statusline-debug.json

# Example input JSON structure:
# {
#   "session_id": "cc5895b5-17b0-465c-805b-59d447b3c5aa",
#   "transcript_path": "/Users/mbfisher/.claude/projects/-Users-mbfisher-dotfiles/cc5895b5-17b0-465c-805b-59d447b3c5aa.jsonl",
#   "cwd": "/Users/mbfisher/dotfiles",
#   "model": {
#     "id": "claude-opus-4-5-20251101",
#     "display_name": "Opus 4.5"                          # <-- used for MODEL
#   },
#   "workspace": {
#     "current_dir": "/Users/mbfisher/dotfiles",
#     "project_dir": "/Users/mbfisher/dotfiles"
#   },
#   "version": "2.1.29",
#   "output_style": {
#     "name": "default"
#   },
#   "cost": {
#     "total_cost_usd": 5.553850249999997,
#     "total_duration_ms": 275125779,
#     "total_api_duration_ms": 898328,
#     "total_lines_added": 119,
#     "total_lines_removed": 54
#   },
#   "context_window": {
#     "total_input_tokens": 6888,
#     "total_output_tokens": 1285,
#     "context_window_size": 200000,                      # <-- used for CONTEXT_WINDOW_SIZE
#     "current_usage": {
#       "input_tokens": 8,
#       "output_tokens": 2,
#       "cache_creation_input_tokens": 327,
#       "cache_read_input_tokens": 43152
#     },
#     "used_percentage": 22,                              # <-- used for CONTEXT_PCT
#     "remaining_percentage": 78
#   },
#   "exceeds_200k_tokens": false
# }

# cd to the session's cwd so git commands resolve against the user's actual
# working dir, not wherever Claude Code spawned the hook.
CWD=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null

# Strip "(NM context)" / "(NK context)" suffix — the window size is now shown
# in the progress segment, so the model name doesn't need to repeat it.
MODEL=$(echo "$input" | jq -r '.model.display_name' | sed -E 's/ *\([0-9]+[KM] context\) *$//')

# --- Git location: worktree-aware identifier + subpath prefix -----------------
# `--git-common-dir` points to the SHARED .git for the repo; `--git-dir` points
# to the per-worktree gitdir. They differ iff we're in a linked worktree.
# Comparing common-dirs across the Claude instance's project_dir and the cwd
# tells us whether we're "in the same repo" (any worktree counts).
LOCATION=""
BRANCH=""
IN_WORKTREE=0
IN_PROJECT_REPO=0
REPO_NAME=""
IDENTIFIER=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
  TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
  GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
  case "$GIT_COMMON_DIR" in /*) ;; *) GIT_COMMON_DIR="$(cd "$GIT_COMMON_DIR" && pwd)" ;; esac
  case "$GIT_DIR"        in /*) ;; *) GIT_DIR="$(cd "$GIT_DIR" && pwd)" ;; esac

  [ "$GIT_DIR" != "$GIT_COMMON_DIR" ] && IN_WORKTREE=1

  # Subpath relative to current worktree root (empty when at root).
  SUBPATH=""
  [ "$PWD" != "$TOPLEVEL" ] && SUBPATH="${PWD#$TOPLEVEL/}"
  LOCATION="$SUBPATH"

  # Identifier shown in the rightmost element is always the branch name.
  # The repo separator distinguishes worktree (`~`) from regular checkout (`@`).
  IDENTIFIER="$BRANCH"

  # repo_name = "<parent>/<repo>" derived from the MAIN checkout (parent of the
  # shared .git). Same for every worktree in the repo, which is what we want.
  MAIN_REPO_ROOT="$(dirname "$GIT_COMMON_DIR")"
  REPO_NAME="$(basename "$(dirname "$MAIN_REPO_ROOT")")/$(basename "$MAIN_REPO_ROOT")"

  # Is the Claude instance's project_dir part of THIS repo? Compare common-dirs
  # — same shared .git means same repo, even across different worktrees.
  PROJECT_DIR=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // empty')
  if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
    PD_COMMON=$(git -C "$PROJECT_DIR" rev-parse --git-common-dir 2>/dev/null)
    if [ -n "$PD_COMMON" ]; then
      case "$PD_COMMON" in /*) ;; *) PD_COMMON="$(cd "$PROJECT_DIR" && cd "$PD_COMMON" 2>/dev/null && pwd)" ;; esac
      [ "$PD_COMMON" = "$GIT_COMMON_DIR" ] && IN_PROJECT_REPO=1
    fi
  fi
else
  BRANCH="n/a"
  IDENTIFIER="n/a"
fi

# --- Context usage ------------------------------------------------------------
CONTEXT_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0 | floor')
CONTEXT_WINDOW_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
CURRENT_TOKENS=$(echo "$CONTEXT_PCT * $CONTEXT_WINDOW_SIZE / 100" | bc)

format_number() {
  local num=$1 val
  if [ "$num" -ge 1000000 ]; then
    val=$(echo "scale=1; $num / 1000000" | bc)
    echo "${val%.0}M"
  elif [ "$num" -ge 1000 ]; then
    val=$(echo "scale=1; $num / 1000" | bc)
    echo "${val%.0}K"
  else
    echo "$num"
  fi
}

CURRENT_TOKENS_FORMATTED=$(format_number $CURRENT_TOKENS)
CONTEXT_WINDOW_SIZE_FORMATTED=$(format_number $CONTEXT_WINDOW_SIZE)

# Context health colours. The two numbers answer different questions, so each is
# coloured on its own scale rather than sharing one verdict:
#
#   percentage    — how close auto-compact is (a mechanical limit).
#   absolute      — how degraded the model's attention already is.
#
# The absolute scale is the one that matters on big windows. "Context rot" is a
# function of absolute input length, not of how full the window happens to be:
# models measurably lose accuracy from ~50K tokens onward, and a 1M window
# doesn't reason reliably over 1M tokens just because it accepts them. On a 1M
# window 24% is 240K tokens — already degraded, while the percentage is honestly
# still green. Colouring separately shows both facts at once.
PCT_WARN=50
PCT_BAD=75
ABS_WARN=100000    # ~100K: measurable attention degradation begins
ABS_BAD=250000     # ~250K: well past the reliable long-context reasoning band

C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'

if   [ "$CONTEXT_PCT" -ge "$PCT_BAD" ];  then PCT_COLOR="$C_RED"
elif [ "$CONTEXT_PCT" -ge "$PCT_WARN" ]; then PCT_COLOR="$C_YELLOW"
else                                          PCT_COLOR="$C_GREEN"
fi

if   [ "$CURRENT_TOKENS" -ge "$ABS_BAD" ];  then ABS_COLOR="$C_RED"
elif [ "$CURRENT_TOKENS" -ge "$ABS_WARN" ]; then ABS_COLOR="$C_YELLOW"
else                                             ABS_COLOR="$C_GREEN"
fi

# ANSI palette.
C_MODEL=$'\033[36m'    # cyan model name
C_DIM=$'\033[2m'       # dim middots / token count / repo prefix
C_BRANCH=$'\033[32m'   # green branch identifier
C_WT=$'\033[35m'       # magenta worktree identifier (stands out)
C_PATH=$'\033[90m'     # bright-black subpath
R=$'\033[0m'

# Subpath segment (relative to worktree root, dim grey).
LOC_STR=""
[ -n "$LOCATION" ] && LOC_STR="${C_PATH}${LOCATION}${R} "

# Rightmost segment: parent/repo<sep>branch — '@' regular, '~' worktree.
# Nerd Font glyphs (e.g. ) don't render reliably in Claude Code's TUI, so
# the separator itself signals the mode; magenta vs green is a secondary cue.
RIGHT_STR=""
if [ -n "$IDENTIFIER" ]; then
  if [ $IN_WORKTREE -eq 1 ]; then C_ID="$C_WT"; SEP="~"; else C_ID="$C_BRANCH"; SEP="@"; fi
  if [ -n "$REPO_NAME" ]; then
    # Repo prefix in default fg (dim washes out in light themes).
    RIGHT_STR="${REPO_NAME}${SEP}${C_ID}${IDENTIFIER}${R}"
  else
    RIGHT_STR="${C_ID}${IDENTIFIER}${R}"
  fi
fi

# Context segment: "24% 240K/1M" — percentage on the pct scale, tokens on the
# absolute scale. The "/window" denominator stays dim; it's a constant, not a
# signal.
CONTEXT_STR="${PCT_COLOR}${CONTEXT_PCT}%${R} ${ABS_COLOR}${CURRENT_TOKENS_FORMATTED}${R}${C_DIM}/${CONTEXT_WINDOW_SIZE_FORMATTED}${R}"

# --- Cost: this session + today across all sessions ---------------------------
# Session cost comes straight from the status-line JSON. Today's total means
# scanning every transcript (via ccusage) — too slow to run inline — so we read
# a cache file and kick off a detached background refresh when it goes stale.
# The "today" figure can therefore lag by up to CACHE_MAX_AGE seconds.
COST_CACHE="$HOME/.claude/daily-cost-cache"
COST_LOCK="$HOME/.claude/daily-cost-cache.lock"
CACHE_MAX_AGE=60

DAILY_COST=""
[ -f "$COST_CACHE" ] && DAILY_COST=$(cat "$COST_CACHE" 2>/dev/null)

stale=1
if [ -f "$COST_CACHE" ]; then
  mtime=$(stat -f %m "$COST_CACHE" 2>/dev/null || echo 0)
  [ $(( $(date +%s) - mtime )) -lt $CACHE_MAX_AGE ] && stale=0
fi
# Refresh in the background only when stale and no refresh is already running.
if [ $stale -eq 1 ] && [ ! -d "$COST_LOCK" ]; then
  nohup "$HOME/.claude/refresh-daily-cost.sh" >/dev/null 2>&1 &
  disown 2>/dev/null
fi

SESSION_COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
SESSION_COST_FMT=$(printf '%.2f' "$SESSION_COST" 2>/dev/null || echo "0.00")
if [ -n "$DAILY_COST" ]; then
  DAILY_COST_FMT=$(printf '%.2f' "$DAILY_COST" 2>/dev/null || echo "$DAILY_COST")
  DAILY_LABEL="\$$DAILY_COST_FMT today"
else
  DAILY_LABEL="… today"   # cache still warming up
fi
COST_STR="\$$SESSION_COST_FMT ${C_DIM}($DAILY_LABEL)${R}"

# Separator: plain bullet in the terminal's default fg.
SEP_STR="•"
printf "%s%s%s  %s  %s  %s  %s  %s  %s%s\n" \
  "$C_MODEL" "$MODEL" "$R" \
  "$SEP_STR" \
  "$CONTEXT_STR" \
  "$SEP_STR" \
  "$COST_STR" \
  "$SEP_STR" \
  "$LOC_STR" "$RIGHT_STR"
