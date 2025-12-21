#!/usr/bin/env bash
#
# worktree-sync.sh - Sync all worktrees with latest changes from main
#
# Usage: worktree-sync.sh [--rebase|--merge]

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

SYNC_METHOD="rebase"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebase)
            SYNC_METHOD="rebase"
            shift
            ;;
        --merge)
            SYNC_METHOD="merge"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--rebase|--merge]"
            echo ""
            echo "Sync all worktrees with latest changes from main branch."
            echo ""
            echo "Options:"
            echo "  --rebase     Rebase worktree branches on main (default)"
            echo "  --merge      Merge main into worktree branches"
            echo "  --help, -h   Show this help message"
            echo ""
            echo "This script will:"
            echo "  1. Fetch latest from origin"
            echo "  2. Update main branch"
            echo "  3. Rebase/merge each worktree branch"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Get repository root
REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

echo "Syncing all worktrees with main..."
echo "Method: $SYNC_METHOD"
echo ""

# Fetch latest from origin
echo "Fetching from origin..."
git fetch origin

# Get main worktree path
MAIN_PATH=$(git worktree list --porcelain | head -1 | sed 's/worktree //')

# Update main branch in main worktree
echo ""
echo "Updating main branch..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ "$CURRENT_BRANCH" == "main" ]]; then
    git pull origin main
else
    # We're not on main, just fetch
    git fetch origin main:main 2>/dev/null || true
fi

# Sync each worktree
echo ""
echo "Syncing worktrees..."
echo ""

SYNC_SUCCESS=0
SYNC_FAILED=0

git worktree list | while IFS= read -r line; do
    path=$(echo "$line" | awk '{print $1}')
    branch=$(echo "$line" | awk '{print $3}' | sed 's/\[//;s/\]//')

    # Skip main worktree
    if [[ "$path" == "$MAIN_PATH" ]]; then
        continue
    fi

    echo "Syncing: $branch"
    echo "  Path: $path"

    cd "$path"

    # Check for uncommitted changes
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "  Warning: Has uncommitted changes, skipping"
        echo ""
        SYNC_FAILED=$((SYNC_FAILED + 1))
        continue
    fi

    # Perform sync
    if [[ "$SYNC_METHOD" == "rebase" ]]; then
        if git rebase main 2>/dev/null; then
            echo "  Status: Rebased successfully"
            SYNC_SUCCESS=$((SYNC_SUCCESS + 1))
        else
            echo "  Warning: Rebase failed, aborting"
            git rebase --abort 2>/dev/null || true
            SYNC_FAILED=$((SYNC_FAILED + 1))
        fi
    else
        if git merge main --no-edit 2>/dev/null; then
            echo "  Status: Merged successfully"
            SYNC_SUCCESS=$((SYNC_SUCCESS + 1))
        else
            echo "  Warning: Merge failed, aborting"
            git merge --abort 2>/dev/null || true
            SYNC_FAILED=$((SYNC_FAILED + 1))
        fi
    fi

    echo ""
    cd "$REPO_ROOT"
done

echo "Sync complete!"
