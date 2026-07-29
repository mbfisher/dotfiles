#!/bin/bash
#
# Install this repo's config into $HOME as symlinks.
#
# The rule is: link the largest unit we own.
#
#   src/.config/<name>  ->  ~/.config/<name>       whole entry, linked as a unit
#   src/<anything else> ->  ~/<same relative path>  individual files, any depth
#
# Those two modes exist because of directory ownership, not by accident:
#
#   Whole-entry (.config) — we own everything in the directory, so the link is
#   effectively bidirectional: files an app writes into its own config dir land
#   inside the repo and show up in `git status`. That is deliberate and load
#   bearing — it is the only reason nvim's lazy-lock.json and the karabiner.json
#   that Karabiner-Elements rewrites from its GUI are under version control.
#
#   Per-file (everything else) — the target directory belongs to somebody else
#   and we are only injecting a few files into it. Sync is one-way, repo -> home,
#   and nothing flows back. ~/.claude is the motivating case: it holds hundreds
#   of megabytes of credentials, transcripts and daemon state that must never be
#   replaced by a directory symlink.
#
# Usage: ./sync.sh [-n|--dry-run] [-f|--force]
#
#   -n, --dry-run  Report what would change without touching the filesystem.
#   -f, --force    Replace real files/directories that are in the way. Without
#                  this, such conflicts are skipped and listed at the end.
#                  Replacing an existing *symlink* never needs --force, since
#                  removing a link discards nothing.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO/src"

FORCE=0
DRY_RUN=0
CONFLICTS=()

# Directories this run has created fresh, hence known to be empty. Kept as a
# ":"-delimited string rather than an associative array so the script still runs
# under the bash 3.2 that macOS ships as /bin/bash.
PREPARED=":"

usage() { sed -n '3,27p' "${BASH_SOURCE[0]}" | sed 's/^#\{1,2\} \{0,1\}//'; }

is_prepared()  { case "$PREPARED" in *":$1:"*) return 0 ;; *) return 1 ;; esac; }
mark_prepared() { PREPARED="$PREPARED$1:"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    -f|--force)   FORCE=1 ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "sync.sh: unknown option '$1'" >&2; exit 2 ;;
  esac
  shift
done

# Render a path with $HOME collapsed to ~, purely for readable output.
pretty() { echo "~${1#"$HOME"}"; }

act()  { echo "  $*"; }
warn() { echo "  ! $*" >&2; }

# Make sure the parent directory of $1 exists as a real directory.
#
# Walks each component below $HOME. A component that is currently a *symlink*
# gets unlinked first: that is how ~/bin and ~/.zsh.d migrate from the old
# whole-directory links to real directories holding per-file links. Unlinking is
# safe because the content it pointed at lives in this repo.
#
# Returns 1 if a real file sits where a directory needs to be.
ensure_parent() {
  local target="$1" dir rel path part
  local -a parts

  dir="$(dirname "$target")"
  [ "$dir" = "$HOME" ] && return 0

  rel="${dir#"$HOME"/}"
  path="$HOME"
  IFS=/ read -ra parts <<< "$rel"

  for part in "${parts[@]}"; do
    path="$path/$part"

    # Handled while processing an earlier file in the same directory.
    is_prepared "$path" && continue

    if [ -L "$path" ]; then
      act "unlink $(pretty "$path") (was -> $(readlink "$path"))"
      [ $DRY_RUN -eq 0 ] && rm -f "$path"
    elif [ -d "$path" ]; then
      continue                      # a real directory already — leave it alone
    elif [ -e "$path" ]; then
      return 1                      # a real file sits where we need a directory
    fi

    act "mkdir $(pretty "$path")"
    [ $DRY_RUN -eq 0 ] && mkdir -p "$path"
    mark_prepared "$path"
  done

  return 0
}

# Symlink $1 (in the repo) to $2 (in $HOME), reporting what it does.
link() {
  local source="$1" target="$2" shown
  shown="$(pretty "$target")"

  # Already correct — stay quiet so repeat runs produce no output.
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    return 0
  fi

  if ! ensure_parent "$target"; then
    CONFLICTS+=("$shown (a file blocks the parent directory)")
    return 1
  fi

  # If we just created the parent, the target cannot exist, so skip the checks
  # below. Without this the old whole-directory link is still in place during a
  # --dry-run and every file under it looks like a conflict with itself.
  if is_prepared "$(dirname "$target")"; then
    act "link $shown"
    [ $DRY_RUN -eq 0 ] && ln -s "$source" "$target"
    return 0
  fi

  if [ -L "$target" ]; then
    act "relink $shown (was -> $(readlink "$target"))"
    [ $DRY_RUN -eq 0 ] && rm -f "$target"
  elif [ -e "$target" ]; then
    # The only genuinely destructive branch, so it is the only one behind --force.
    if [ $FORCE -eq 0 ]; then
      CONFLICTS+=("$shown ($([ -d "$target" ] && echo "real directory" || echo "real file"))")
      return 1
    fi
    act "replace $shown --force"
    [ $DRY_RUN -eq 0 ] && rm -rf "$target"
  else
    act "link $shown"
  fi

  [ $DRY_RUN -eq 0 ] && ln -s "$source" "$target"
  return 0
}

[ $DRY_RUN -eq 1 ] && echo "dry run — nothing will be modified"

# 1. ~/.config/<name> — whole entries, so app-written files flow back into git.
echo "~/.config (whole entries)"
while IFS= read -r entry; do
  name="${entry#"$SRC"/.config/}"
  [ "$name" = ".DS_Store" ] && continue
  link "$entry" "$HOME/.config/$name"
done < <(find "$SRC/.config" -mindepth 1 -maxdepth 1 | sort)

# 2. Everything else — individual files at any depth.
#
# `find -type f` deliberately does not follow symlinks, so a symlink inside src
# is neither linked nor descended into. src/bin/bin is exactly that: a committed
# self-referential link back to src/bin, which would otherwise recurse forever.
echo "~/ (individual files)"
while IFS= read -r file; do
  rel="${file#"$SRC"/}"
  case "$rel" in
    .config/*|CLAUDE.md) continue ;;
  esac
  link "$file" "$HOME/$rel"
done < <(find "$SRC" -type f ! -name '.DS_Store' | sort)

while IFS= read -r found; do
  rel="${found#"$SRC"/}"
  case "$rel" in .config/*) continue ;; esac
  warn "skipped src/$rel — symlink -> $(readlink "$found")"
done < <(find "$SRC" -type l | sort)

if [ ${#CONFLICTS[@]} -gt 0 ]; then
  echo
  echo "skipped ${#CONFLICTS[@]} conflict(s) — re-run with --force to replace:" >&2
  for c in "${CONFLICTS[@]}"; do echo "  $c" >&2; done
  exit 1
fi
