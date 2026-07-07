# Zellij `NextSwapLayout` / `PreviousSwapLayout` swaps focused pane out of position

**Date:** 2026-05-28
**Status:** Worked around in `src/.config/zellij/config.kdl`
**Affects:** `src/.config/zellij/config.kdl`, `src/.config/zellij/layouts/repo.kdl`
**Upstream:** [zellij-org/zellij#3684](https://github.com/zellij-org/zellij/issues/3684) (open as of zellij 0.43.1)

## Symptoms

In the `repo` layout (claude on the left in a 33% stack, nvim + shell stacked on the right),
focusing the claude pane and pressing `Alt ]` (or `Alt [`) cycles to the next swap variant
*and* relocates claude into the shell's slot on the right. Subsequent presses don't move it
again. Pressing `Alt ]` from nvim or shell exhibits the same class of bug — the focused pane
gets shifted within the right-side stack.

## Root cause

Upstream zellij bug. On the *first* `NextSwapLayout` / `PreviousSwapLayout` from a given
layout, zellij moves the currently focused pane to the end of the layout traversal order
before resolving pane → slot assignments in the new swap variant. After the focused pane is
"at the end," further swaps don't re-trigger the move (it's already last). Naming panes does
not fix it (confirmed by the issue reporter and corroborating commenter `@bittrance`).

Depth-first traversal of our base layout is `claude → nvim → shell`, so claude (focused, at
position 1) is the most-displaced victim — it gets moved all the way to position 3 (the shell
slot in the right stack).

## Red herrings

- **Suspecting our swap-variant shapes:** the `66%` / `50%` variants have the same pane
  count and nesting as the base, so the matching shouldn't ambiguously reshuffle. Adding more
  explicit `size=` values (done in an earlier iteration) doesn't help; the bug is upstream of
  layout matching.
- **Suspecting `stacked=true` interactions:** the bug reproduces with plain vertical splits
  too (see `@bittrance`'s repro in the upstream thread).
- **Suspecting `focus=true` placement:** the bug isn't about which pane *receives* focus
  after the swap; it's about which pane gets *relocated*. Tagging panes with `focus=true` in
  swap variants doesn't change the assignment order.

## Workaround

In `src/.config/zellij/config.kdl`, chain `MoveFocus "right"` before the swap action:

```kdl
bind "Alt [" { MoveFocus "right"; PreviousSwapLayout; MoveFocus "left"; }
bind "Alt ]" { MoveFocus "right"; NextSwapLayout; MoveFocus "left"; }
```

Because the upstream bug moves the *focused* pane to the end of traversal, shifting focus
to the right stack before the swap means the displaced pane is one that already lives there
(shell is the actual last leaf, so the bug becomes a no-op; nvim getting displaced reorders
within its own stack, which is benign). The trailing `MoveFocus "left"` restores focus to
claude, which is the common starting position.

**Trade-off:** if you triggered the swap from nvim or shell, focus lands on claude rather
than back where you started (zellij has no `save_focus` / `restore_focus` or focus-by-name
action, so a fully position-preserving chain isn't possible). Press `Alt l` to return.

## Follow-up (2026-06-30): dropped swap-layouts entirely for an anchored Resize

The swap-layout workaround above was later abandoned in favour of resizing the vertical split
directly (no swap variants at all). That migration introduced its own subtle breakage where
`Alt [` / `Alt ]` appeared to "stop working", traced to two zellij 0.43.1 behaviours measured
empirically (hosting a session inside `tmux` with a real PTY and reading live pane widths via
`stty size` piped through `zellij action dump-screen`):

1. **Directional `Resize "Decrease Right"` / `"Increase Left"` etc. is a silent no-op inside
   `stacked=true` panes.** The `repo` layout is all stacked, so any directional resize did
   nothing — the binding fired but had no visible effect. Only the direction-less
   `Resize "Increase"` / `Resize "Decrease"` actually moves a stacked split.
2. **Direction-less resize is coarse (~30% per step) and asymmetric by pane.** From the
   left/claude pane it's clean and reversible (≈33%↔62% in one step); from the right-hand
   stack (nvim/shell) the first step is erratic/no-op. So resizing "whatever is focused" gives
   inconsistent results depending on where the cursor is.

**Fix:** anchor the resize on the left/claude pane regardless of focus:

```kdl
bind "Alt [" { MoveFocus "left"; Resize "Decrease"; MoveFocus "right"; }
bind "Alt ]" { MoveFocus "left"; Resize "Increase"; MoveFocus "right"; }
```

One step ≈ the old 33↔66 swap — do **not** chain six steps (that drives the split to
fullscreen). Same focus trade-off as the swap workaround: triggering these from claude itself
leaves focus on nvim. A "six steps ≈ 30%" assumption (calibrated against *non-stacked* resize
granularity) was the red herring that produced the broken intermediate bindings.

## Recurrence notes

- If/when upstream fixes #3684, revert the chained bindings back to plain
  `PreviousSwapLayout` / `NextSwapLayout`.
- If the `repo` layout gains additional panes or a different traversal order, re-check that
  `MoveFocus "right"` still lands on the right-side stack (and that the "end" of traversal is
  still inside that stack).
- Other layouts that don't have a meaningful "right" pane will treat `MoveFocus "right"` as
  a no-op, so the chained binding is safe globally.
