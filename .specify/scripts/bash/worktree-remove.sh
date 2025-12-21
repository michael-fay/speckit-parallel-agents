#!/usr/bin/env bash
#
# worktree-remove.sh - Remove a git worktree (branch is preserved)
#
# Usage: worktree-remove.sh <branch-name> [--force]

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BRANCH_NAME=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 <branch-name> [--force]"
            echo ""
            echo "Remove a git worktree. The branch is preserved."
            echo ""
            echo "Arguments:"
            echo "  <branch-name>    Name of the feature branch"
            echo ""
            echo "Options:"
            echo "  --force, -f      Force removal even if worktree has uncommitted changes"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            BRANCH_NAME="$1"
            shift
            ;;
    esac
done

if [[ -z "$BRANCH_NAME" ]]; then
    echo "Error: Branch name is required" >&2
    echo "Usage: $0 <branch-name> [--force]" >&2
    exit 1
fi

# Get repository root
REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Determine worktree path
REPO_NAME=$(basename "$REPO_ROOT")
WORKTREE_CONTAINER="$(dirname "$REPO_ROOT")/${REPO_NAME}-worktrees"
WORKTREE_PATH="$WORKTREE_CONTAINER/$BRANCH_NAME"

# Check if worktree exists
if [[ ! -d "$WORKTREE_PATH" ]]; then
    echo "Error: Worktree does not exist at $WORKTREE_PATH" >&2
    echo ""
    echo "Available worktrees:"
    git worktree list
    exit 1
fi

# Check for uncommitted changes
cd "$WORKTREE_PATH"
if [[ -n "$(git status --porcelain)" ]]; then
    if [[ "$FORCE" != "true" ]]; then
        echo "Error: Worktree has uncommitted changes" >&2
        echo ""
        echo "Options:"
        echo "  1. Commit your changes first"
        echo "  2. Use --force to discard changes"
        echo ""
        git status --short
        exit 1
    else
        echo "Warning: Discarding uncommitted changes..."
    fi
fi

cd "$REPO_ROOT"

echo "Removing worktree: $BRANCH_NAME"
echo "Path: $WORKTREE_PATH"

if [[ "$FORCE" == "true" ]]; then
    git worktree remove --force "$WORKTREE_PATH"
else
    git worktree remove "$WORKTREE_PATH"
fi

echo ""
echo "Worktree removed successfully!"
echo "Note: Branch '$BRANCH_NAME' is preserved."
echo ""
echo "To delete the branch:"
echo "  git branch -d $BRANCH_NAME"
