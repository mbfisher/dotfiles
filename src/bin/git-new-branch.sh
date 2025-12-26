#!/bin/bash

# Script to create a new git branch with proper setup
# Usage: ./new-branch.sh <branch-name>

# Color codes
GRAY='\033[90m'
RESET='\033[0m'

# Wrapper function to colorize git output
git() {
    echo -e "${GRAY}"
    command git -c color.ui=never "$@"
    local exit_code=$?
    echo -e "${RESET}"
    return $exit_code
}

# Check if branch name is provided
if [ $# -eq 0 ]; then
    echo "Error: Branch name is required"
    echo "Usage: $0 <branch-name>"
    exit 1
fi

BRANCH_NAME="$1"

# Validate branch name (basic check)
if [[ ! "$BRANCH_NAME" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
    echo "Error: Invalid branch name. Use only letters, numbers, hyphens, underscores, and forward slashes."
    exit 1
fi

echo "> Creating new branch: $BRANCH_NAME"

# Step 1: Stage all files
echo "> Staging all files..."
git add .
if [ $? -ne 0 ]; then
    echo "Error: Failed to stage files"
    exit 1
fi

# Step 2: Check if there are changes to stash, then stash
echo "Checking for changes to stash..."
STASHED=false

if ! git diff-index --quiet HEAD --; then
    echo "> Stashing changes..."
    git stash push -m "Auto-stash before creating branch $BRANCH_NAME"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to stash changes"
        exit 1
    fi
    STASHED=true
    echo "> Changes stashed successfully"
else
    echo "No changes to stash"
fi

# Step 3: Checkout master and pull
echo "> Switching to master and pulling latest changes..."
git checkout master
if [ $? -ne 0 ]; then
    echo "Error: Failed to checkout master branch"
    exit 1
fi
git pull origin master
if [ $? -ne 0 ]; then
    echo "Error: Failed to pull from origin/master"
    exit 1
fi

# Step 4: Check out new branch
echo "> Creating and switching to new branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create and checkout new branch"
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
        exit 1
    fi
    echo "> Stashed changes restored"
fi

echo "> ✅ Successfully created and switched to branch: $BRANCH_NAME"
echo "> You can now continue working on your changes."