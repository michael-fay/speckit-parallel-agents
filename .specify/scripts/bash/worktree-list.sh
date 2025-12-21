#!/usr/bin/env bash
#
# worktree-list.sh - List all active git worktrees
#
# Usage: worktree-list.sh [--json]

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
if [[ "$1" == "--json" ]]; then
    JSON_MODE=true
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [--json]"
    echo ""
    echo "List all active git worktrees."
    echo ""
    echo "Options:"
    echo "  --json    Output in JSON format"
    echo "  --help    Show this help message"
    exit 0
fi

# Get repository root
REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

if $JSON_MODE; then
    # Output JSON array
    echo "["
    first=true
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Parse worktree line: /path/to/worktree HEAD [branch]
            path=$(echo "$line" | awk '{print $1}')
            commit=$(echo "$line" | awk '{print $2}')
            branch=$(echo "$line" | awk '{print $3}' | sed 's/\[//;s/\]//')

            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            printf '  {"path": "%s", "commit": "%s", "branch": "%s"}' "$path" "$commit" "$branch"
        fi
    done < <(git worktree list)
    echo ""
    echo "]"
else
    echo "Active Worktrees:"
    echo "================="
    echo ""

    # Get main worktree info
    main_path=$(git worktree list --porcelain | head -1 | sed 's/worktree //')
    echo "Main: $main_path"
    echo ""

    # List all worktrees with details
    git worktree list | while IFS= read -r line; do
        path=$(echo "$line" | awk '{print $1}')
        branch=$(echo "$line" | awk '{print $3}' | sed 's/\[//;s/\]//')

        if [[ "$path" != "$main_path" ]]; then
            # Check if there's an associated spec
            spec_path="$REPO_ROOT/specs/$branch/spec.md"
            has_spec="no spec"
            if [[ -f "$spec_path" ]]; then
                has_spec="has spec"
            fi

            echo "  $branch"
            echo "    Path: $path"
            echo "    Spec: $has_spec"
            echo ""
        fi
    done

    # Summary
    total=$(git worktree list | wc -l | tr -d ' ')
    echo "Total worktrees: $total (including main)"
fi
