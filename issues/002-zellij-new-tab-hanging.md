# `zellij action new-tab` hangs in `ws` alias

**Date:** 2026-02-28 (ongoing, guard added 2026-03-11)
**Status:** Mitigated with `precmd` session guard + "cd back" workaround
**Affects:** `src/.zshrc` (`ws` function), `src/.config/zellij/layouts/repo.kdl`
**Symptoms:** Running the `ws` alias to open a git worktree in a new zellij tab hangs indefinitely at the
`zellij action new-tab` call. The tab never appears and the command never returns; Ctrl-C is required.

## Background

The `ws` function (defined in `.zshrc`) switches to a git worktree using `wt switch` (worktrunk), then opens it in a
new zellij tab with `zellij action new-tab --layout repo --cwd <worktree-path>`. It worked initially but began hanging
intermittently.

## Root Causes Identified

### 1. `ZELLIJ_SESSION_NAME` pointing to a zombie session (confirmed)

The most definitive cause found. `zellij action` uses the `ZELLIJ_SESSION_NAME` environment variable to find the IPC
socket for the current session. If this variable gets set to a zombie/nonexistent session name, the command hangs
forever waiting for a response from a dead socket.

**How it happens:** `wt switch` runs `cd` into the worktree directory, which triggers mise's `chpwd` hook
(`mise hook-env`). This hook massively modifies the environment (~120 variables unset/reset, PATH rewritten). In some
cases this corrupts or overwrites `ZELLIJ_SESSION_NAME` — e.g. it was observed set to `adamant-cuckoo` (a zombie
session) instead of the expected `core`.

**Diagnosis:**
```zsh
echo $ZELLIJ_SESSION_NAME   # check what session the shell thinks it's in
zellij list-sessions -n      # check if that session actually exists and is healthy
```

**Immediate fix:**
```zsh
export ZELLIJ_SESSION_NAME=<correct-session-name>
zellij kill-session <zombie-session-name>
```

### 2. mise `hook-env` environment pollution (confirmed, mitigated)

When `cd` changes to a worktree directory, `mise hook-env` fires and modifies the environment extensively. Even if
`ZELLIJ_SESSION_NAME` survives, the modified environment can cause `zellij action` to misbehave.

**Mitigation (current):** The `ws` function now captures `$PWD` after `wt switch`, `cd`s back to the original
directory (triggering mise/direnv to restore the original env), then runs `zellij action new-tab --cwd "$wt_path"`.
This is the "cd back" workaround in the current `.zshrc`:

```zsh
ws() {
  local main="$PWD"
  # ... wt switch logic ...
  local wt_path="$PWD"
  cd "$main"                    # restore original env before calling zellij
  zellij action new-tab --layout repo --cwd "$wt_path"
}
```

### 3. Zellij input mode (suspected)

If zellij is in a non-normal mode (locked, tab, pane mode), `zellij action` commands may not be dispatched and the CLI
client hangs waiting for a response. This hasn't been conclusively confirmed as a cause for this specific issue but is
a known failure mode.

**Potential mitigation:**
```zsh
zellij action switch-mode normal && zellij action new-tab ...
```

## Red Herrings

- **Layout file `tab-bar`/`status-bar` plugins** — early hypothesis that embedding session-level plugin panes in
  `repo.kdl` caused the hang when passed to `new-tab`. Disproved: these bars are needed and had been working.
- **`wt --execute` not inheriting environment** — theory that `wt switch --execute` ran the zellij command in a
  subprocess without `ZELLIJ` env vars. Testing showed `--execute` uses `exec` which inherits the environment. The
  function was refactored to not use `--execute` anyway.
- **`zellij action new-tab --cwd /tmp`** — this worked fine, confirming the issue was environment-related rather than
  a fundamental problem with `new-tab`.

## Attempted Fixes (do not re-suggest)

### 1. Remove `tab-bar`/`status-bar` plugin panes from `repo.kdl` layout
**Result:** Did not fix the hang, and broke the UI (tabs and status bar disappeared). The plugins are not the cause.
Do not suggest removing or modifying the layout plugins.

### 2. Use `wt switch --execute "zellij action new-tab ..."` to run zellij from inside worktrunk
**Result:** Did not fix. `--execute` uses `exec` so it inherits the environment, but `wt switch` still triggers
`cd` + `mise hook-env` before executing, so the environment is already polluted. The function was refactored to not
use `--execute`.

### 3. "cd back" workaround — `cd "$main"` before calling `zellij action`
**Result:** This is the **current implementation**. It partially mitigates the mise env pollution (root cause #2) by
restoring the original environment before calling zellij. However, the hang **still occurs intermittently**, likely
when `ZELLIJ_SESSION_NAME` has already been corrupted by the `cd` into the worktree (root cause #1). This workaround
alone is not sufficient.

### 4. Manually `export ZELLIJ_SESSION_NAME=<correct-name>` and kill zombie sessions
**Result:** Works as a **one-time fix** when the hang is actively occurring, but does not prevent recurrence. The
zombie session and env corruption happen again on subsequent `ws` calls.

### 5. Run `zellij action new-tab --cwd /tmp` (no layout, neutral directory)
**Result:** This works fine — it was a diagnostic test, not a fix. It confirmed the issue is environment/session
related, not a fundamental problem with `new-tab` or the layout file.

## Related Issues

- **Zellij bug #4673**: nested stacked panes produce invalid `session-layout.kdl` files that fail to parse on session
  resurrection. Handled by the `za`/`zn` functions in `.zshrc` which detect attach failures and start fresh.
- **`zellij list-sessions` ANSI codes**: output includes colour codes when piped, breaking `grep` matches. Use the
  `-n` flag to suppress formatting.
- **`zellij run` TTY allocation**: `zellij run -- claude` hangs because `zellij run` doesn't allocate a proper TTY for
  interactive commands. Layout-defined panes and `zellij action new-pane` handle TTY correctly.

## Current Mitigations

Two layers of defence are now in place in `src/.zshrc`:

### 1. `precmd` session guard (`_zellij_session_guard` in `.zshrc`)
Checks whether `ZELLIJ_SESSION_NAME` has drifted and restores it on every prompt. The `ws` function also calls it
before `zellij action new-tab`. See the function comments in `src/.zshrc` for how and why it works.

### 2. "cd back" workaround in `ws` (existing)
The `ws` function captures the worktree path, `cd`s back to the original directory to restore the environment, then
calls `zellij action new-tab --cwd`. This prevents root cause #2 (general mise env pollution) from affecting the
zellij action call.

## Unresolved

- The exact mechanism by which mise's `chpwd` hook corrupts `ZELLIJ_SESSION_NAME` has not been fully traced. The
  "cd back" workaround addresses it pragmatically but the hang still occurs intermittently.
- Whether switching to `zellij action switch-mode normal` before `new-tab` would be a more robust fix hasn't been
  tested systematically.

## Potential Next Steps

1. Test whether `zellij action switch-mode normal` before `new-tab` prevents the mode-related hang.
2. Trace exactly which mise hook-env variable change causes the corruption (run `set -x` through the full ws flow and
   diff the environment before/after).
3. Consider filing upstream issues against mise (env var leaking) and/or zellij (action should timeout or error rather
   than hang forever on a dead session socket).
4. The birth-time matching approach in the session guard could theoretically fail if two sessions are created in the
   same second. In practice this is unlikely but could be made more robust by also comparing the original socket name
   from server args against `zellij list-sessions -n`.
