#!/usr/bin/env bash
#
# worktree-create.sh - Create a new git worktree for parallel agent development
#
# Usage: worktree-create.sh <branch-name> [--from <base-branch>]
#
# Creates a worktree in ../<project>-worktrees/<branch-name>/
# If the branch doesn't exist, it will be created from main (or specified base)

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Parse arguments
BRANCH_NAME=""
BASE_BRANCH="main"
ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)
            BASE_BRANCH="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 <branch-name> [--from <base-branch>]"
            echo ""
            echo "Create a new git worktree for parallel agent development."
            echo ""
            echo "Arguments:"
            echo "  <branch-name>      Name of the feature branch (e.g., 001-html-parser)"
            echo ""
            echo "Options:"
            echo "  --from <branch>    Base branch to create from (default: main)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 001-html-parser"
            echo "  $0 002-native-adapter --from 001-html-parser"
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

BRANCH_NAME="${ARGS[0]}"

if [[ -z "$BRANCH_NAME" ]]; then
    echo "Error: Branch name is required" >&2
    echo "Usage: $0 <branch-name> [--from <base-branch>]" >&2
    exit 1
fi

# Get repository root
REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Determine worktree container directory (sibling to main repo)
REPO_NAME=$(basename "$REPO_ROOT")
WORKTREE_CONTAINER="$(dirname "$REPO_ROOT")/${REPO_NAME}-worktrees"

# Create worktree container if it doesn't exist
mkdir -p "$WORKTREE_CONTAINER"

WORKTREE_PATH="$WORKTREE_CONTAINER/$BRANCH_NAME"

# Check if worktree already exists
if [[ -d "$WORKTREE_PATH" ]]; then
    echo "Error: Worktree already exists at $WORKTREE_PATH" >&2
    echo "Use 'worktree-remove.sh $BRANCH_NAME' to remove it first" >&2
    exit 1
fi

# Check if branch exists locally or remotely
BRANCH_EXISTS=false
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
    BRANCH_EXISTS=true
elif git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME" 2>/dev/null; then
    BRANCH_EXISTS=true
fi

echo "Creating worktree for branch: $BRANCH_NAME"
echo "Location: $WORKTREE_PATH"

if [[ "$BRANCH_EXISTS" == "true" ]]; then
    # Branch exists, just create worktree
    echo "Branch exists, creating worktree..."
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
else
    # Branch doesn't exist, create it from base
    echo "Creating new branch from $BASE_BRANCH..."
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "$BASE_BRANCH"
fi

echo ""
echo "Worktree created successfully!"
echo ""
echo "Next steps:"
echo "  1. cd $WORKTREE_PATH"
echo "  2. Start your AI agent session"
echo "  3. Reference specs/$BRANCH_NAME/ for requirements"
echo ""
echo "When done:"
echo "  .specify/scripts/bash/worktree-remove.sh $BRANCH_NAME"
