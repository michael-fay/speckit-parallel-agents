#!/usr/bin/env bash
#
# manifest-update.sh - Atomic manifest updates with worktree→remote→meta-spec protocol
#
# This script ensures manifest updates are atomic and synchronized across
# parallel agents working on different sub-specs via git worktrees.
#
# Protocol:
#   1. Update manifest in current worktree
#   2. Commit the change
#   3. Push to the worktree's remote branch
#   4. Merge the worktree branch into the meta-spec branch (on remote)
#   5. (Optional) Pull meta-spec changes back to local meta-spec branch
#
# This ensures:
#   - Worktree changes are always pushed first
#   - Meta-spec branch stays in sync with all worktree changes
#   - No race conditions between parallel worktrees
#
# Usage: manifest-update.sh <meta_spec_dir> <command> [args...]
#
# Commands:
#   update-phase <sub_spec_id> <phase> <status>
#   mark-scheduled <schedule_json_file>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/manifest.sh"

# Static commit message for manifest updates
COMMIT_MSG="chore: update manifest state

🤖 Generated with [Claude Code](https://claude.com/claude-code)"

# Retry settings
MAX_RETRIES=5
RETRY_DELAY=2

usage() {
    cat << 'EOF'
Usage: manifest-update.sh <meta_spec_dir> <command> [args...]

Atomic manifest updates with fetch→read→write→push protocol.

Commands:
  update-phase <sub_spec_id> <phase> <status>
      Update a sub-spec's phase status
      Phases: specify, plan, tasks, implement
      Statuses: pending, in-progress, complete, blocked

  mark-scheduled <schedule_json_file>
      Mark the meta-spec as scheduled with the given schedule

Examples:
  manifest-update.sh specs/001-feature update-phase 001-parser implement complete
  manifest-update.sh specs/001-feature mark-scheduled specs/001-feature/schedule.json

EOF
    exit 1
}

# Get the current branch name
get_current_branch() {
    git rev-parse --abbrev-ref HEAD
}

# Get the meta-spec branch name from a sub-spec branch
# e.g., "001-feature-002-adapter" -> "001-feature"
get_meta_spec_branch() {
    local branch="$1"
    # Pattern: ###-name-###-subname -> ###-name
    if [[ "$branch" =~ ^([0-9]{3}-[a-z0-9-]+)-[0-9]{3}-[a-z0-9-]+$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Commit, push to worktree branch, and merge to meta-spec branch
# This is the new protocol:
#   1. Commit manifest change in worktree
#   2. Push worktree branch to remote
#   3. Merge worktree branch into meta-spec branch on remote
commit_push_and_merge() {
    local meta_spec_dir="$1"
    local manifest_file="$meta_spec_dir/manifest.json"

    local current_branch=$(get_current_branch)
    local meta_spec_branch=$(get_meta_spec_branch "$current_branch")

    # If we can't determine the meta-spec branch, we might be on the meta-spec branch itself
    if [[ -z "$meta_spec_branch" ]]; then
        meta_spec_branch="$current_branch"
    fi

    echo "Current branch: $current_branch" >&2
    echo "Meta-spec branch: $meta_spec_branch" >&2

    # Stage manifest
    git add "$manifest_file"

    # Check if there are changes to commit
    if git diff --cached --quiet "$manifest_file"; then
        echo "No changes to commit" >&2
        return 0
    fi

    # Commit
    git commit -m "$COMMIT_MSG" --no-verify 2>/dev/null || {
        echo "ERROR: Failed to commit manifest changes" >&2
        return 1
    }

    echo "Committed manifest changes" >&2

    # Step 1: Push worktree branch to remote
    local attempt=0
    while [[ $attempt -lt $MAX_RETRIES ]]; do
        if git push origin "$current_branch" 2>/dev/null; then
            echo "Pushed to remote branch: $current_branch" >&2
            break
        fi

        attempt=$((attempt + 1))
        echo "Push failed, retrying ($attempt/$MAX_RETRIES)..." >&2

        # Fetch and rebase before retry
        git fetch origin "$current_branch" 2>/dev/null || true
        git rebase "origin/$current_branch" 2>/dev/null || {
            git rebase --abort 2>/dev/null || true
        }

        sleep $RETRY_DELAY
    done

    if [[ $attempt -ge $MAX_RETRIES ]]; then
        echo "ERROR: Failed to push worktree branch after $MAX_RETRIES attempts" >&2
        return 1
    fi

    # Step 2: Merge worktree branch into meta-spec branch (if different)
    if [[ "$current_branch" != "$meta_spec_branch" ]]; then
        echo "Merging $current_branch into $meta_spec_branch..." >&2

        # Get the repo root to find the main worktree
        local repo_root=$(get_repo_root)
        local main_worktree=$(git worktree list --porcelain | grep "^worktree " | head -1 | sed 's/worktree //')

        # Perform merge in the main worktree (where meta-spec branch lives)
        (
            cd "$main_worktree"
            git fetch origin "$current_branch" "$meta_spec_branch" 2>/dev/null || true

            # Make sure we're on the meta-spec branch
            local main_branch=$(git rev-parse --abbrev-ref HEAD)
            if [[ "$main_branch" != "$meta_spec_branch" ]]; then
                echo "ERROR: Main worktree is not on meta-spec branch ($main_branch != $meta_spec_branch)" >&2
                echo "Please switch the main worktree to the meta-spec branch first." >&2
                return 1
            fi

            # Merge the worktree branch (fast-forward if possible)
            git merge "origin/$current_branch" --no-edit || {
                echo "ERROR: Merge failed. Manual intervention required." >&2
                return 1
            }

            # Push meta-spec branch
            git push origin "$meta_spec_branch" || {
                echo "ERROR: Failed to push meta-spec branch" >&2
                return 1
            }

            echo "Successfully merged and pushed meta-spec branch" >&2
        )
    fi

    echo "Manifest update complete" >&2
    return 0
}

# Main function
main() {
    if [[ $# -lt 2 ]]; then
        usage
    fi

    local meta_spec_dir="$1"
    local command="$2"
    shift 2

    # Validate meta-spec directory
    if [[ ! -f "$meta_spec_dir/manifest.json" ]]; then
        echo "ERROR: manifest.json not found in $meta_spec_dir" >&2
        exit 1
    fi

    # Get repo root and ensure we're in it
    local repo_root=$(get_repo_root)
    cd "$repo_root"

    # Convert to relative path if absolute
    if [[ "$meta_spec_dir" == /* ]]; then
        meta_spec_dir="${meta_spec_dir#$repo_root/}"
    fi

    case "$command" in
        update-phase)
            if [[ $# -ne 3 ]]; then
                echo "ERROR: update-phase requires <sub_spec_id> <phase> <status>" >&2
                usage
            fi

            local sub_spec_id="$1"
            local phase="$2"
            local status="$3"

            # Validate phase
            case "$phase" in
                specify|plan|tasks|implement) ;;
                *)
                    echo "ERROR: Invalid phase '$phase'. Must be: specify, plan, tasks, implement" >&2
                    exit 1
                    ;;
            esac

            # Validate status
            case "$status" in
                pending|in-progress|complete|blocked) ;;
                *)
                    echo "ERROR: Invalid status '$status'. Must be: pending, in-progress, complete, blocked" >&2
                    exit 1
                    ;;
            esac

            # Update phase (this acquires/releases lock internally)
            update_phase "$meta_spec_dir" "$sub_spec_id" "$phase" "$status"

            # Commit, push worktree branch, and merge to meta-spec branch
            commit_push_and_merge "$meta_spec_dir" || exit 1

            echo "{\"success\": true, \"sub_spec\": \"$sub_spec_id\", \"phase\": \"$phase\", \"status\": \"$status\"}"
            ;;

        mark-scheduled)
            if [[ $# -ne 1 ]]; then
                echo "ERROR: mark-scheduled requires <schedule_json_file>" >&2
                usage
            fi

            local schedule_file="$1"

            if [[ ! -f "$schedule_file" ]]; then
                echo "ERROR: Schedule file not found: $schedule_file" >&2
                exit 1
            fi

            local schedule_json=$(cat "$schedule_file")

            # Mark scheduled (this acquires/releases lock internally)
            mark_scheduled "$meta_spec_dir" "$schedule_json"

            # Commit, push worktree branch, and merge to meta-spec branch
            commit_push_and_merge "$meta_spec_dir" || exit 1

            echo "{\"success\": true, \"scheduled\": true}"
            ;;

        *)
            echo "ERROR: Unknown command '$command'" >&2
            usage
            ;;
    esac
}

main "$@"
