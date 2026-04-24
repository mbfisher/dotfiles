#!/bin/bash

# Script to update current branch by rebasing on origin/master
# Usage: git up

# Color codes
GRAY='\033[90m'
RESET='\033[0m'

# Track state for recovery
STASHED=false
STAGED_PATCH=""

# Wrapper function to colorize git output
git() {
    local output
    output=$(command git -c color.ui=never "$@" 2>&1)
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GRAY}${output}${RESET}"
    else
        echo "$output"
    fi
    return $exit_code
}

CURRENT_BRANCH=$(command git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -z "$CURRENT_BRANCH" ]; then
    echo "Error: Not in a git repository"
    exit 1
fi

echo "> Updating branch: $CURRENT_BRANCH"

# Step 1: Check if there are changes to stash
echo "Checking for changes to stash..."

HAS_STAGED=$(command git diff --cached --quiet; echo $?)
HAS_UNSTAGED=$(command git diff --quiet; echo $?)
HAS_UNTRACKED=$(command git ls-files --others --exclude-standard | head -1)

if [ "$HAS_STAGED" -ne 0 ] || [ "$HAS_UNSTAGED" -ne 0 ] || [ -n "$HAS_UNTRACKED" ]; then
    # Save staged changes as a patch (to restore staged/unstaged distinction later)
    if [ "$HAS_STAGED" -ne 0 ]; then
        echo "> Saving staged changes..."
        STAGED_PATCH=$(mktemp)
        command git diff --cached > "$STAGED_PATCH"
    fi

    # Stash everything including untracked files
    echo "> Stashing changes..."
    git stash push --include-untracked -m "Auto-stash before git up on $CURRENT_BRANCH"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to stash changes"
        rm -f "$STAGED_PATCH"
        exit 1
    fi
    STASHED=true
    echo "> Changes stashed successfully"
else
    echo "No changes to stash"
fi

# Step 3: Fetch from origin
echo "> Fetching from origin..."
git fetch origin
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch from origin"
    if [ "$STASHED" = true ]; then
        echo "> Popping stashed changes..."
        git stash pop
    fi
    rm -f "$STAGED_PATCH"
    exit 1
fi

# Step 4: Rebase on origin/master
echo "> Rebasing on origin/master..."
git rebase origin/master
if [ $? -ne 0 ]; then
    echo "Error: Rebase failed"
    echo "You may need to resolve conflicts manually."
    echo "  - Run 'git rebase --continue' after resolving conflicts"
    echo "  - Or run 'git rebase --abort' to cancel the rebase"
    if [ "$STASHED" = true ]; then
        echo "Note: Your changes are still in the stash. Run 'git stash pop' after resolving."
        if [ -n "$STAGED_PATCH" ] && [ -s "$STAGED_PATCH" ]; then
            echo "Note: Staged changes patch saved at: $STAGED_PATCH"
        fi
    fi
    exit 1
fi

# Step 5: Pop stash if something was stashed
if [ "$STASHED" = true ]; then
    echo "> Popping stashed changes..."
    git stash pop
    if [ $? -ne 0 ]; then
        echo "Error: Failed to pop stashed changes"
        echo "Your changes are still in the stash. You can:"
        echo "  - Run 'git stash pop' manually to retry"
        echo "  - Run 'git stash list' to see your stashes"
        echo "  - Run 'git stash show' to see what was stashed"
        rm -f "$STAGED_PATCH"
        exit 1
    fi

    # Restore staged/unstaged distinction
    if [ -n "$STAGED_PATCH" ] && [ -s "$STAGED_PATCH" ]; then
        echo "> Restoring staged/unstaged distinction..."
        command git reset HEAD --quiet
        command git apply --cached "$STAGED_PATCH" 2>/dev/null
        rm -f "$STAGED_PATCH"
    fi
    echo "> Stashed changes restored"
fi

echo "> ✅ Successfully rebased $CURRENT_BRANCH on origin/master"
