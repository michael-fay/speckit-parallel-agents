#!/usr/bin/env bash
#
# worktree-sync.sh - Sync all worktrees with latest changes from a target branch
#
# Usage: worktree-sync.sh [--rebase|--merge] [--branch <branch>] [--meta-spec <dir>]

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

SYNC_METHOD="rebase"
TARGET_BRANCH=""
META_SPEC_DIR=""

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
        --branch)
            TARGET_BRANCH="$2"
            shift 2
            ;;
        --meta-spec)
            META_SPEC_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--rebase|--merge] [--branch <branch>] [--meta-spec <dir>]"
            echo ""
            echo "Sync all worktrees with latest changes from a target branch."
            echo ""
            echo "Options:"
            echo "  --rebase           Rebase worktree branches (default)"
            echo "  --merge            Merge into worktree branches"
            echo "  --branch <branch>  Target branch to sync with (default: main, or meta-spec branch)"
            echo "  --meta-spec <dir>  Meta-spec directory (auto-detects target branch from manifest)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "This script will:"
            echo "  1. Fetch latest from origin"
            echo "  2. Update target branch"
            echo "  3. Rebase/merge each worktree branch"
            echo ""
            echo "Examples:"
            echo "  $0 --branch 001-feature           # Sync with meta-spec branch"
            echo "  $0 --meta-spec specs/001-feature  # Auto-detect from manifest"
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

# Determine target branch
if [[ -n "$META_SPEC_DIR" ]]; then
    # Extract meta-spec ID from directory path
    META_SPEC_ID=$(basename "$META_SPEC_DIR")
    TARGET_BRANCH="$META_SPEC_ID"
    echo "Auto-detected meta-spec branch: $TARGET_BRANCH"
elif [[ -z "$TARGET_BRANCH" ]]; then
    # Default to main if no branch specified
    TARGET_BRANCH="main"
fi

echo "Syncing all worktrees with '$TARGET_BRANCH'..."
echo "Method: $SYNC_METHOD"
echo ""

# Fetch latest from origin
echo "Fetching from origin..."
git fetch origin 2>/dev/null || true

# Get main worktree path
MAIN_PATH=$(git worktree list --porcelain | head -1 | sed 's/worktree //')

# Update target branch if we're on it
echo ""
echo "Checking target branch '$TARGET_BRANCH'..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ "$CURRENT_BRANCH" == "$TARGET_BRANCH" ]]; then
    echo "Currently on target branch, pulling latest..."
    git pull origin "$TARGET_BRANCH" 2>/dev/null || true
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

    # When syncing a meta-spec, only sync worktrees that are sub-specs of it
    if [[ -n "$META_SPEC_DIR" ]]; then
        # Check if this branch starts with the meta-spec ID
        if [[ ! "$branch" =~ ^${TARGET_BRANCH}- ]]; then
            continue
        fi
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
        if git rebase "$TARGET_BRANCH" 2>/dev/null; then
            echo "  Status: Rebased successfully"
            SYNC_SUCCESS=$((SYNC_SUCCESS + 1))
        else
            echo "  Warning: Rebase failed, aborting"
            git rebase --abort 2>/dev/null || true
            SYNC_FAILED=$((SYNC_FAILED + 1))
        fi
    else
        if git merge "$TARGET_BRANCH" --no-edit 2>/dev/null; then
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
