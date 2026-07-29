This is a "dotfiles" repository of user-specific configuration for MacOS. I'm a professional software engineer.

## Workflow

Make changes directly on the `master` branch. Do NOT create feature branches, worktrees, or pull
requests unless I explicitly ask for one. This repo is my live config (symlinked into `$HOME`), so
working straight on `master` is what I want.

Commit and push after every change — I'm bad at remembering to, so treat it as part of the task, not
an optional extra. Small, frequent commits are fine and preferred over batching.

## Configuration

The src/ directory contains files that are symlinked in to my HOME directory by `sync.sh`. The rule is: **link the
largest unit we own.** That gives two modes.

`src/.config/<name>` is linked as a whole entry:

~/.config/nvim -> src/.config/nvim

Everything else under `src/` is linked file by file, at any depth, with parent directories created as needed:

~/.zshrc -> src/.zshrc
~/bin/git-up.sh -> src/bin/git-up.sh
~/.claude/statusline.sh -> src/.claude/statusline.sh

The split is about who owns the target directory, and it matters:

- **Whole-entry** — we own everything in the directory, so the link is effectively bidirectional: files an app writes
  into its own config dir land inside the repo and show up in `git status`. This is load bearing, not incidental — it's
  the only reason nvim's `lazy-lock.json` and the `karabiner.json` that Karabiner-Elements rewrites from its GUI are
  under version control. Things we don't want are excluded via `.gitignore` (e.g. karabiner's `automatic_backups/`).
- **Per-file** — the directory belongs to somebody else and we're only injecting a few files. Sync is one-way, repo to
  home, and nothing flows back. `~/.claude` is the motivating case: it holds hundreds of megabytes of credentials,
  transcripts and daemon state, so it must never be replaced by a directory symlink.

`sync.sh` is idempotent and prints nothing for links that are already correct. It replaces existing *symlinks* freely,
since unlinking discards nothing, but replacing a real file or directory requires `--force` — without it, conflicts are
skipped, listed, and the script exits 1. Use `--dry-run` to preview. It targets `/bin/bash` (macOS bash 3.2), so no
associative arrays.

## Issues

The `issues/` directory at the repo root documents non-trivial debugging investigations. Issues can span multiple
tools (e.g. zsh aliases + zellij + mise) so they live at the top level rather than inside any single config directory.

Each issue file follows the format: symptoms, root cause, red herrings, fix/workaround, recurrence notes. When
resolving a tricky problem, save it as `issues/NNN-short-description.md`. Check existing issues before debugging a
problem that may already be documented.

## Colours

Two colour schemes are in use — Ghostty's built-in default for every terminal (including terminal buffers inside
nvim, and Claude Code), and onedark with a lighter foreground for code. `docs/colours.md` documents both, every
file that sets colours, and the reasoning. Read it before changing any colour: the values are cross-referenced
between the Ghostty and nvim configs, and Ghostty setting no colours at all is deliberate.

## Peripherals

I use a Keychron K3 Max keyboard and Keychron M6 mouse. They need some custom configuration for my setup. See src/.config/karabiner/README.md
