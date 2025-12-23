#!/usr/bin/env bash
# Common functions and variables for all scripts
#
# Supports both simple features and meta-spec/sub-spec structures:
#   Simple:   specs/001-feature/spec.md
#   Meta:     specs/001-meta-spec/user-story.md
#   Sub-spec: specs/001-meta-spec/001-sub-spec/spec.md
#
# Branch naming conventions:
#   Simple:   001-feature-name
#   Meta:     001-meta-spec-name
#   Sub-spec: 001-meta-spec-name-001-sub-spec-name

# Get repository root, with fallback for non-git repositories
get_repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        # Fall back to script location for non-git repos
        local script_dir="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        (cd "$script_dir/../../.." && pwd)
    fi
}

# Get current branch, with fallback for non-git repositories
get_current_branch() {
    # First check if SPECIFY_FEATURE environment variable is set
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "$SPECIFY_FEATURE"
        return
    fi

    # Then check git if available
    if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
        git rev-parse --abbrev-ref HEAD
        return
    fi

    # For non-git repos, try to find the latest feature directory
    local repo_root=$(get_repo_root)
    local specs_dir="$repo_root/specs"

    if [[ -d "$specs_dir" ]]; then
        local latest_feature=""
        local highest=0

        for dir in "$specs_dir"/*; do
            if [[ -d "$dir" ]]; then
                local dirname=$(basename "$dir")
                if [[ "$dirname" =~ ^([0-9]{3})- ]]; then
                    local number=${BASH_REMATCH[1]}
                    number=$((10#$number))
                    if [[ "$number" -gt "$highest" ]]; then
                        highest=$number
                        latest_feature=$dirname
                    fi
                fi
            fi
        done

        if [[ -n "$latest_feature" ]]; then
            echo "$latest_feature"
            return
        fi
    fi

    echo "main"  # Final fallback
}

# Check if we have git available
has_git() {
    git rev-parse --show-toplevel >/dev/null 2>&1
}

check_feature_branch() {
    local branch="$1"
    local has_git_repo="$2"

    # For non-git repos, we can't enforce branch naming but still provide output
    if [[ "$has_git_repo" != "true" ]]; then
        echo "[specify] Warning: Git repository not detected; skipped branch validation" >&2
        return 0
    fi

    if [[ ! "$branch" =~ ^[0-9]{3}- ]]; then
        echo "ERROR: Not on a feature branch. Current branch: $branch" >&2
        echo "Feature branches should be named like: 001-feature-name" >&2
        return 1
    fi

    return 0
}

get_feature_dir() { echo "$1/specs/$2"; }

# Find feature directory by numeric prefix instead of exact branch match
# This allows multiple branches to work on the same spec (e.g., 004-fix-bug, 004-add-feature)
find_feature_dir_by_prefix() {
    local repo_root="$1"
    local branch_name="$2"
    local specs_dir="$repo_root/specs"

    # Extract numeric prefix from branch (e.g., "004" from "004-whatever")
    if [[ ! "$branch_name" =~ ^([0-9]{3})- ]]; then
        # If branch doesn't have numeric prefix, fall back to exact match
        echo "$specs_dir/$branch_name"
        return
    fi

    local prefix="${BASH_REMATCH[1]}"

    # Search for directories in specs/ that start with this prefix
    local matches=()
    if [[ -d "$specs_dir" ]]; then
        for dir in "$specs_dir"/"$prefix"-*; do
            if [[ -d "$dir" ]]; then
                matches+=("$(basename "$dir")")
            fi
        done
    fi

    # Handle results
    if [[ ${#matches[@]} -eq 0 ]]; then
        # No match found - return the branch name path (will fail later with clear error)
        echo "$specs_dir/$branch_name"
    elif [[ ${#matches[@]} -eq 1 ]]; then
        # Exactly one match - perfect!
        echo "$specs_dir/${matches[0]}"
    else
        # Multiple matches - this shouldn't happen with proper naming convention
        echo "ERROR: Multiple spec directories found with prefix '$prefix': ${matches[*]}" >&2
        echo "Please ensure only one spec directory exists per numeric prefix." >&2
        echo "$specs_dir/$branch_name"  # Return something to avoid breaking the script
    fi
}

get_feature_paths() {
    local repo_root=$(get_repo_root)
    local current_branch=$(get_current_branch)
    local has_git_repo="false"

    if has_git; then
        has_git_repo="true"
    fi

    # Use prefix-based lookup to support multiple branches per spec
    local feature_dir=$(find_feature_dir_by_prefix "$repo_root" "$current_branch")

    cat <<EOF
REPO_ROOT='$repo_root'
CURRENT_BRANCH='$current_branch'
HAS_GIT='$has_git_repo'
FEATURE_DIR='$feature_dir'
FEATURE_SPEC='$feature_dir/spec.md'
IMPL_PLAN='$feature_dir/plan.md'
TASKS='$feature_dir/tasks.md'
RESEARCH='$feature_dir/research.md'
DATA_MODEL='$feature_dir/data-model.md'
QUICKSTART='$feature_dir/quickstart.md'
CONTRACTS_DIR='$feature_dir/contracts'
EOF
}

check_file() { [[ -f "$1" ]] && echo "  ✓ $2" || echo "  ✗ $2"; }
check_dir() { [[ -d "$1" && -n $(ls -A "$1" 2>/dev/null) ]] && echo "  ✓ $2" || echo "  ✗ $2"; }

# ============================================================================
# Meta-Spec / Sub-Spec Detection and Path Resolution
# ============================================================================

# Check if a branch name matches the sub-spec pattern
# Sub-spec pattern: ###-meta-name-###-sub-name (e.g., 001-feature-001-parser)
is_sub_spec_branch() {
    local branch="$1"
    # Pattern: ###-word(s)-###-word(s)
    # Must have two ###- patterns
    if [[ "$branch" =~ ^([0-9]{3}-[a-z0-9-]+)-([0-9]{3}-[a-z0-9-]+)$ ]]; then
        return 0
    fi
    return 1
}

# Extract meta-spec ID from a sub-spec branch name
# Input: 001-feature-001-parser
# Output: 001-feature
get_meta_spec_id_from_branch() {
    local branch="$1"
    if [[ "$branch" =~ ^([0-9]{3}-[a-z0-9-]+)-[0-9]{3}-[a-z0-9-]+$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Extract sub-spec ID from a sub-spec branch name
# Input: 001-feature-001-parser
# Output: 001-parser
get_sub_spec_id_from_branch() {
    local branch="$1"
    if [[ "$branch" =~ ^[0-9]{3}-[a-z0-9-]+-([0-9]{3}-[a-z0-9-]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Check if a directory is a meta-spec (has manifest.json)
is_meta_spec_dir() {
    local dir="$1"
    [[ -f "$dir/manifest.json" ]]
}

# Find meta-spec directory for a given branch
# Works for both meta-spec branches and sub-spec branches
find_meta_spec_dir() {
    local repo_root="$1"
    local branch="$2"
    local specs_dir="$repo_root/specs"

    # If it's a sub-spec branch, extract the meta-spec ID
    if is_sub_spec_branch "$branch"; then
        local meta_id=$(get_meta_spec_id_from_branch "$branch")
        if [[ -n "$meta_id" ]]; then
            # Find the meta-spec directory by prefix
            local prefix=$(echo "$meta_id" | grep -o '^[0-9]\{3\}')
            for dir in "$specs_dir"/"$prefix"-*; do
                if [[ -d "$dir" ]] && is_meta_spec_dir "$dir"; then
                    echo "$dir"
                    return 0
                fi
            done
        fi
    fi

    # Check if current branch's spec dir is a meta-spec
    local feature_dir=$(find_feature_dir_by_prefix "$repo_root" "$branch")
    if is_meta_spec_dir "$feature_dir"; then
        echo "$feature_dir"
        return 0
    fi

    # Not a meta-spec context
    echo ""
    return 1
}

# Get feature paths with meta-spec/sub-spec awareness
# This is an enhanced version of get_feature_paths
get_feature_paths_v2() {
    local repo_root=$(get_repo_root)
    local current_branch=$(get_current_branch)
    local has_git_repo="false"
    local is_sub_spec="false"
    local meta_spec_dir=""
    local sub_spec_id=""

    if has_git; then
        has_git_repo="true"
    fi

    # Check if this is a sub-spec branch
    if is_sub_spec_branch "$current_branch"; then
        is_sub_spec="true"
        local meta_id=$(get_meta_spec_id_from_branch "$current_branch")
        sub_spec_id=$(get_sub_spec_id_from_branch "$current_branch")

        # Find the meta-spec directory
        meta_spec_dir=$(find_meta_spec_dir "$repo_root" "$current_branch")

        if [[ -n "$meta_spec_dir" ]] && [[ -n "$sub_spec_id" ]]; then
            # Sub-spec paths are nested under meta-spec
            local feature_dir="$meta_spec_dir/$sub_spec_id"

            cat <<EOF
REPO_ROOT='$repo_root'
CURRENT_BRANCH='$current_branch'
HAS_GIT='$has_git_repo'
IS_SUB_SPEC='true'
META_SPEC_DIR='$meta_spec_dir'
SUB_SPEC_ID='$sub_spec_id'
FEATURE_DIR='$feature_dir'
FEATURE_SPEC='$feature_dir/spec.md'
IMPL_PLAN='$feature_dir/plan.md'
TASKS='$feature_dir/tasks.md'
RESEARCH='$feature_dir/research.md'
DATA_MODEL='$feature_dir/data-model.md'
QUICKSTART='$feature_dir/quickstart.md'
CONTRACTS_DIR='$feature_dir/contracts'
USER_STORY='$meta_spec_dir/user-story.md'
MANIFEST='$meta_spec_dir/manifest.json'
BREAKDOWN='$meta_spec_dir/breakdown.md'
EOF
            return
        fi
    fi

    # Standard feature paths (non-sub-spec)
    local feature_dir=$(find_feature_dir_by_prefix "$repo_root" "$current_branch")

    # Check if this is a meta-spec
    local is_meta="false"
    if is_meta_spec_dir "$feature_dir"; then
        is_meta="true"
    fi

    cat <<EOF
REPO_ROOT='$repo_root'
CURRENT_BRANCH='$current_branch'
HAS_GIT='$has_git_repo'
IS_SUB_SPEC='false'
IS_META_SPEC='$is_meta'
FEATURE_DIR='$feature_dir'
FEATURE_SPEC='$feature_dir/spec.md'
IMPL_PLAN='$feature_dir/plan.md'
TASKS='$feature_dir/tasks.md'
RESEARCH='$feature_dir/research.md'
DATA_MODEL='$feature_dir/data-model.md'
QUICKSTART='$feature_dir/quickstart.md'
CONTRACTS_DIR='$feature_dir/contracts'
EOF

    # Add meta-spec specific paths if applicable
    if [[ "$is_meta" == "true" ]]; then
        cat <<EOF
USER_STORY='$feature_dir/user-story.md'
MANIFEST='$feature_dir/manifest.json'
BREAKDOWN='$feature_dir/breakdown.md'
EOF
    fi
}

# ============================================================================
# Worktree Sync Checking
# ============================================================================

# Check if a worktree is behind the meta-spec branch
# Usage: check_worktree_sync <meta_spec_branch>
# Returns: 0 if in sync, 1 if behind (with error message)
check_worktree_sync() {
    local meta_spec_branch="$1"

    if ! has_git; then
        return 0  # Can't check without git
    fi

    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Only check if we're on a sub-spec branch
    if ! is_sub_spec_branch "$current_branch"; then
        return 0
    fi

    # Get commits
    local worktree_commit=$(git rev-parse HEAD)
    local meta_commit=$(git rev-parse "$meta_spec_branch" 2>/dev/null)

    if [[ -z "$meta_commit" ]]; then
        echo "Warning: Could not find meta-spec branch '$meta_spec_branch'" >&2
        return 0
    fi

    # Check if worktree commit is ancestor of meta-spec (i.e., worktree is behind)
    if git merge-base --is-ancestor "$worktree_commit" "$meta_commit" && \
       [[ "$worktree_commit" != "$meta_commit" ]]; then
        # Worktree is behind - count commits
        local behind_count=$(git rev-list --count "$worktree_commit".."$meta_commit")
        return 1
    fi

    return 0
}

# Get sync status details
# Usage: get_worktree_sync_status <meta_spec_branch>
# Returns: JSON with sync details
get_worktree_sync_status() {
    local meta_spec_branch="$1"

    if ! has_git; then
        echo '{"synced": true, "reason": "no_git"}'
        return
    fi

    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local worktree_commit=$(git rev-parse --short HEAD)
    local meta_commit=$(git rev-parse --short "$meta_spec_branch" 2>/dev/null || echo "unknown")

    if ! is_sub_spec_branch "$current_branch"; then
        echo '{"synced": true, "reason": "not_sub_spec"}'
        return
    fi

    local full_worktree=$(git rev-parse HEAD)
    local full_meta=$(git rev-parse "$meta_spec_branch" 2>/dev/null)

    if [[ -z "$full_meta" ]]; then
        echo "{\"synced\": false, \"reason\": \"meta_branch_not_found\", \"meta_branch\": \"$meta_spec_branch\"}"
        return
    fi

    if [[ "$full_worktree" == "$full_meta" ]]; then
        echo '{"synced": true, "reason": "same_commit"}'
        return
    fi

    if git merge-base --is-ancestor "$full_worktree" "$full_meta"; then
        local behind_count=$(git rev-list --count "$full_worktree".."$full_meta")
        echo "{\"synced\": false, \"reason\": \"behind\", \"behind_count\": $behind_count, \"worktree_commit\": \"$worktree_commit\", \"meta_commit\": \"$meta_commit\", \"meta_branch\": \"$meta_spec_branch\"}"
    else
        # Worktree has diverged (has commits not in meta-spec)
        local ahead_count=$(git rev-list --count "$full_meta".."$full_worktree")
        echo "{\"synced\": false, \"reason\": \"diverged\", \"ahead_count\": $ahead_count, \"worktree_commit\": \"$worktree_commit\", \"meta_commit\": \"$meta_commit\", \"meta_branch\": \"$meta_spec_branch\"}"
    fi
}

