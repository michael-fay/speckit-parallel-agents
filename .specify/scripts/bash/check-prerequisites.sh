#!/usr/bin/env bash

# Consolidated prerequisite checking script
#
# This script provides unified prerequisite checking for Spec-Driven Development workflow.
# It replaces the functionality previously spread across multiple scripts.
#
# Usage: ./check-prerequisites.sh [OPTIONS]
#
# OPTIONS:
#   --json              Output in JSON format
#   --require-tasks     Require tasks.md to exist (for implementation phase)
#   --include-tasks     Include tasks.md in AVAILABLE_DOCS list
#   --paths-only        Only output path variables (no validation)
#   --feature <name>    Specify feature/meta-spec name directly (skips branch check)
#   --sub-spec <id>     Specify sub-spec ID within a meta-spec (requires --feature)
#   --help, -h          Show help message
#
# OUTPUTS:
#   JSON mode: {"FEATURE_DIR":"...", "AVAILABLE_DOCS":["..."]}
#   Text mode: FEATURE_DIR:... \n AVAILABLE_DOCS: \n ✓/✗ file.md
#   Paths only: REPO_ROOT: ... \n BRANCH: ... \n FEATURE_DIR: ... etc.
#
# META-SPEC SUPPORT:
#   When --feature points to a meta-spec directory (contains manifest.json),
#   paths are resolved for the meta-spec context. Use --sub-spec to specify
#   a specific sub-spec within the meta-spec.

set -e

# Parse command line arguments
JSON_MODE=false
REQUIRE_TASKS=false
INCLUDE_TASKS=false
PATHS_ONLY=false
FEATURE_NAME=""
SUB_SPEC_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            shift
            ;;
        --require-tasks)
            REQUIRE_TASKS=true
            shift
            ;;
        --include-tasks)
            INCLUDE_TASKS=true
            shift
            ;;
        --paths-only)
            PATHS_ONLY=true
            shift
            ;;
        --feature)
            if [[ -z "${2:-}" ]] || [[ "$2" == --* ]]; then
                echo "ERROR: --feature requires a value" >&2
                exit 1
            fi
            FEATURE_NAME="$2"
            shift 2
            ;;
        --sub-spec)
            if [[ -z "${2:-}" ]] || [[ "$2" == --* ]]; then
                echo "ERROR: --sub-spec requires a value" >&2
                exit 1
            fi
            SUB_SPEC_ID="$2"
            shift 2
            ;;
        --help|-h)
            cat << 'EOF'
Usage: check-prerequisites.sh [OPTIONS]

Consolidated prerequisite checking for Spec-Driven Development workflow.

OPTIONS:
  --json              Output in JSON format
  --require-tasks     Require tasks.md to exist (for implementation phase)
  --include-tasks     Include tasks.md in AVAILABLE_DOCS list
  --paths-only        Only output path variables (no prerequisite validation)
  --feature <name>    Specify feature/meta-spec name directly (skips branch check)
  --sub-spec <id>     Specify sub-spec ID within a meta-spec (requires --feature)
  --help, -h          Show this help message

EXAMPLES:
  # Check task prerequisites (plan.md required)
  ./check-prerequisites.sh --json

  # Check implementation prerequisites (plan.md + tasks.md required)
  ./check-prerequisites.sh --json --require-tasks --include-tasks

  # Get feature paths only (no validation)
  ./check-prerequisites.sh --paths-only

  # Work with a meta-spec from main branch
  ./check-prerequisites.sh --feature 001-feature --json

  # Work with a specific sub-spec within a meta-spec
  ./check-prerequisites.sh --feature 001-feature --sub-spec 001-parser --json

EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$1'. Use --help for usage information." >&2
            exit 1
            ;;
    esac
done

# Note: --sub-spec can work without --feature if on a meta-spec branch
# Validation happens after branch/feature detection below

# Source common functions
SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get repository root for path resolution
REPO_ROOT=$(get_repo_root)
HAS_GIT="false"
if has_git; then
    HAS_GIT="true"
fi

# Determine feature context: explicit --feature, SPECIFY_FEATURE env var, or branch-based
if [[ -n "$FEATURE_NAME" ]]; then
    # Explicit --feature flag takes precedence
    CURRENT_BRANCH="$FEATURE_NAME"
    SKIP_BRANCH_CHECK=true
elif [[ -n "${SPECIFY_FEATURE:-}" ]]; then
    # SPECIFY_FEATURE environment variable
    CURRENT_BRANCH="$SPECIFY_FEATURE"
    SKIP_BRANCH_CHECK=true
else
    # Fall back to branch detection
    CURRENT_BRANCH=$(get_current_branch)
    SKIP_BRANCH_CHECK=false
fi

# Build feature paths based on context
SPECS_DIR="$REPO_ROOT/specs"

# Check if this is a meta-spec (has manifest.json)
if [[ -n "$FEATURE_NAME" ]]; then
    # Direct feature specification - find the directory
    FEATURE_DIR=$(find_feature_dir_by_prefix "$REPO_ROOT" "$FEATURE_NAME")
else
    FEATURE_DIR=$(find_feature_dir_by_prefix "$REPO_ROOT" "$CURRENT_BRANCH")
fi

# Determine if this is a meta-spec context
IS_META_SPEC="false"
IS_SUB_SPEC="false"
META_SPEC_DIR=""

if [[ -f "$FEATURE_DIR/manifest.json" ]]; then
    IS_META_SPEC="true"
    META_SPEC_DIR="$FEATURE_DIR"

    # If --sub-spec is specified, resolve to sub-spec paths
    if [[ -n "$SUB_SPEC_ID" ]]; then
        IS_SUB_SPEC="true"
        IS_META_SPEC="false"
        FEATURE_DIR="$META_SPEC_DIR/$SUB_SPEC_ID"

        if [[ ! -d "$FEATURE_DIR" ]]; then
            echo "ERROR: Sub-spec directory not found: $FEATURE_DIR" >&2
            echo "Available sub-specs in $META_SPEC_DIR:" >&2
            ls -1 "$META_SPEC_DIR" | grep -E '^[0-9]{3}-' | head -10 >&2
            exit 1
        fi
    fi
elif is_sub_spec_branch "$CURRENT_BRANCH"; then
    # Branch-based sub-spec detection
    IS_SUB_SPEC="true"
    META_SPEC_DIR=$(find_meta_spec_dir "$REPO_ROOT" "$CURRENT_BRANCH")
    SUB_SPEC_ID=$(get_sub_spec_id_from_branch "$CURRENT_BRANCH")
    FEATURE_DIR="$META_SPEC_DIR/$SUB_SPEC_ID"
elif [[ -n "$SUB_SPEC_ID" ]]; then
    # --sub-spec provided but not on a meta-spec branch or with --feature
    echo "ERROR: --sub-spec requires either --feature flag or being on a meta-spec branch" >&2
    echo "Current branch: $CURRENT_BRANCH" >&2
    exit 1
fi

# Set standard paths
FEATURE_SPEC="$FEATURE_DIR/spec.md"
IMPL_PLAN="$FEATURE_DIR/plan.md"
TASKS="$FEATURE_DIR/tasks.md"
RESEARCH="$FEATURE_DIR/research.md"
DATA_MODEL="$FEATURE_DIR/data-model.md"
QUICKSTART="$FEATURE_DIR/quickstart.md"
CONTRACTS_DIR="$FEATURE_DIR/contracts"

# Meta-spec specific paths
if [[ "$IS_META_SPEC" == "true" ]] || [[ "$IS_SUB_SPEC" == "true" ]]; then
    if [[ "$IS_META_SPEC" == "true" ]]; then
        USER_STORY="$FEATURE_DIR/user-story.md"
        MANIFEST="$FEATURE_DIR/manifest.json"
        BREAKDOWN="$FEATURE_DIR/breakdown.md"
    else
        USER_STORY="$META_SPEC_DIR/user-story.md"
        MANIFEST="$META_SPEC_DIR/manifest.json"
        BREAKDOWN="$META_SPEC_DIR/breakdown.md"
    fi
fi

# Validate branch only if not using explicit feature specification
if [[ "$SKIP_BRANCH_CHECK" != "true" ]]; then
    check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 1
fi

# Check worktree sync status for sub-spec branches
if [[ "$IS_SUB_SPEC" == "true" ]] && [[ "$HAS_GIT" == "true" ]]; then
    # Get the meta-spec branch name from the current branch
    META_SPEC_BRANCH=$(get_meta_spec_id_from_branch "$CURRENT_BRANCH")

    if [[ -n "$META_SPEC_BRANCH" ]]; then
        SYNC_STATUS=$(get_worktree_sync_status "$META_SPEC_BRANCH")
        SYNC_REASON=$(echo "$SYNC_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('reason',''))" 2>/dev/null || echo "")

        if [[ "$SYNC_REASON" == "behind" ]]; then
            BEHIND_COUNT=$(echo "$SYNC_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('behind_count',0))" 2>/dev/null || echo "0")
            META_COMMIT=$(echo "$SYNC_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('meta_commit',''))" 2>/dev/null || echo "")
            WORKTREE_COMMIT=$(echo "$SYNC_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('worktree_commit',''))" 2>/dev/null || echo "")

            echo "ERROR: Worktree is $BEHIND_COUNT commit(s) behind meta-spec branch '$META_SPEC_BRANCH'" >&2
            echo "" >&2
            echo "  Worktree:  $WORKTREE_COMMIT (current)" >&2
            echo "  Meta-spec: $META_COMMIT ($META_SPEC_BRANCH)" >&2
            echo "" >&2
            echo "The spec/plan/tasks files were updated on the meta-spec branch but not synced to this worktree." >&2
            echo "" >&2
            echo "To sync this worktree, run:" >&2
            echo "  git rebase $META_SPEC_BRANCH" >&2
            echo "" >&2
            echo "Or if you have uncommitted work:" >&2
            echo "  git stash && git rebase $META_SPEC_BRANCH && git stash pop" >&2
            exit 1
        elif [[ "$SYNC_REASON" == "diverged" ]]; then
            AHEAD_COUNT=$(echo "$SYNC_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ahead_count',0))" 2>/dev/null || echo "0")
            echo "Note: Worktree has $AHEAD_COUNT commit(s) ahead of meta-spec (implementation in progress)" >&2
        fi
    fi
fi

# If paths-only mode, output paths and exit (support JSON + paths-only combined)
if $PATHS_ONLY; then
    if $JSON_MODE; then
        # Minimal JSON paths payload (no validation performed)
        # Include meta-spec fields if available
        if [[ "${IS_SUB_SPEC:-false}" == "true" ]]; then
            printf '{"REPO_ROOT":"%s","BRANCH":"%s","FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s","IS_SUB_SPEC":true,"META_SPEC_DIR":"%s","SUB_SPEC_ID":"%s"}\n' \
                "$REPO_ROOT" "$CURRENT_BRANCH" "$FEATURE_DIR" "$FEATURE_SPEC" "$IMPL_PLAN" "$TASKS" "${META_SPEC_DIR:-}" "${SUB_SPEC_ID:-}"
        elif [[ "${IS_META_SPEC:-false}" == "true" ]]; then
            printf '{"REPO_ROOT":"%s","BRANCH":"%s","FEATURE_DIR":"%s","USER_STORY":"%s","MANIFEST":"%s","IS_META_SPEC":true}\n' \
                "$REPO_ROOT" "$CURRENT_BRANCH" "$FEATURE_DIR" "${USER_STORY:-}" "${MANIFEST:-}"
        else
            printf '{"REPO_ROOT":"%s","BRANCH":"%s","FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s"}\n' \
                "$REPO_ROOT" "$CURRENT_BRANCH" "$FEATURE_DIR" "$FEATURE_SPEC" "$IMPL_PLAN" "$TASKS"
        fi
    else
        echo "REPO_ROOT: $REPO_ROOT"
        echo "BRANCH: $CURRENT_BRANCH"
        echo "FEATURE_DIR: $FEATURE_DIR"
        if [[ "${IS_SUB_SPEC:-false}" == "true" ]]; then
            echo "IS_SUB_SPEC: true"
            echo "META_SPEC_DIR: ${META_SPEC_DIR:-}"
            echo "SUB_SPEC_ID: ${SUB_SPEC_ID:-}"
        elif [[ "${IS_META_SPEC:-false}" == "true" ]]; then
            echo "IS_META_SPEC: true"
            echo "USER_STORY: ${USER_STORY:-}"
            echo "MANIFEST: ${MANIFEST:-}"
        fi
        echo "FEATURE_SPEC: $FEATURE_SPEC"
        echo "IMPL_PLAN: $IMPL_PLAN"
        echo "TASKS: $TASKS"
    fi
    exit 0
fi

# Validate required directories and files
if [[ ! -d "$FEATURE_DIR" ]]; then
    echo "ERROR: Feature directory not found: $FEATURE_DIR" >&2
    if [[ "$IS_META_SPEC" == "true" ]]; then
        echo "Run /speckit.specify first to create the meta-spec structure." >&2
    else
        echo "Run /speckit.specify first to create the feature structure." >&2
    fi
    exit 1
fi

# For meta-spec, validate user-story.md and manifest.json instead of plan.md
if [[ "$IS_META_SPEC" == "true" ]]; then
    if [[ ! -f "$USER_STORY" ]]; then
        echo "ERROR: user-story.md not found in $FEATURE_DIR" >&2
        echo "Run /speckit.specify first to create the user story." >&2
        exit 1
    fi
    if [[ ! -f "$MANIFEST" ]]; then
        echo "ERROR: manifest.json not found in $FEATURE_DIR" >&2
        echo "Run /speckit.breakdown first to create the manifest." >&2
        exit 1
    fi

    # For meta-spec with --require-tasks, check that all sub-specs have tasks complete
    if $REQUIRE_TASKS; then
        all_complete=$("$SCRIPT_DIR/manifest.sh" all-complete "$FEATURE_DIR" tasks)
        if [[ "$all_complete" != "true" ]]; then
            echo "ERROR: Not all sub-specs have completed tasks.md" >&2
            echo "Run /speckit.tasks-all to complete task generation for all sub-specs." >&2
            "$SCRIPT_DIR/manifest.sh" summary "$FEATURE_DIR" >&2
            exit 1
        fi
    fi
else
    # Standard feature or sub-spec: require plan.md
    if [[ ! -f "$IMPL_PLAN" ]]; then
        echo "ERROR: plan.md not found in $FEATURE_DIR" >&2
        echo "Run /speckit.plan first to create the implementation plan." >&2
        exit 1
    fi

    # Check for tasks.md if required
    if $REQUIRE_TASKS && [[ ! -f "$TASKS" ]]; then
        echo "ERROR: tasks.md not found in $FEATURE_DIR" >&2
        echo "Run /speckit.tasks first to create the task list." >&2
        exit 1
    fi
fi

# Build list of available documents
docs=()

if [[ "$IS_META_SPEC" == "true" ]]; then
    # Meta-spec docs
    [[ -f "$USER_STORY" ]] && docs+=("user-story.md")
    [[ -f "$BREAKDOWN" ]] && docs+=("breakdown.md")
    [[ -f "$MANIFEST" ]] && docs+=("manifest.json")

    # Check for schedule.md
    [[ -f "$FEATURE_DIR/schedule.md" ]] && docs+=("schedule.md")
else
    # Standard feature/sub-spec docs
    [[ -f "$FEATURE_SPEC" ]] && docs+=("spec.md")
    [[ -f "$IMPL_PLAN" ]] && docs+=("plan.md")
    [[ -f "$RESEARCH" ]] && docs+=("research.md")
    [[ -f "$DATA_MODEL" ]] && docs+=("data-model.md")

    # Check contracts directory (only if it exists and has files)
    if [[ -d "$CONTRACTS_DIR" ]] && [[ -n "$(ls -A "$CONTRACTS_DIR" 2>/dev/null)" ]]; then
        docs+=("contracts/")
    fi

    [[ -f "$QUICKSTART" ]] && docs+=("quickstart.md")

    # Include tasks.md if requested and it exists
    if $INCLUDE_TASKS && [[ -f "$TASKS" ]]; then
        docs+=("tasks.md")
    fi
fi

# Output results
if $JSON_MODE; then
    # Build JSON array of documents
    if [[ ${#docs[@]} -eq 0 ]]; then
        json_docs="[]"
    else
        json_docs=$(printf '"%s",' "${docs[@]}")
        json_docs="[${json_docs%,}]"
    fi

    # Build JSON output based on context
    if [[ "$IS_META_SPEC" == "true" ]]; then
        printf '{"FEATURE_DIR":"%s","AVAILABLE_DOCS":%s,"IS_META_SPEC":true,"USER_STORY":"%s","MANIFEST":"%s","BREAKDOWN":"%s"}\n' \
            "$FEATURE_DIR" "$json_docs" "${USER_STORY:-}" "${MANIFEST:-}" "${BREAKDOWN:-}"
    elif [[ "$IS_SUB_SPEC" == "true" ]]; then
        printf '{"FEATURE_DIR":"%s","AVAILABLE_DOCS":%s,"IS_SUB_SPEC":true,"META_SPEC_DIR":"%s","SUB_SPEC_ID":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s"}\n' \
            "$FEATURE_DIR" "$json_docs" "${META_SPEC_DIR:-}" "${SUB_SPEC_ID:-}" "$FEATURE_SPEC" "$IMPL_PLAN" "$TASKS"
    else
        printf '{"FEATURE_DIR":"%s","AVAILABLE_DOCS":%s,"FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s"}\n' \
            "$FEATURE_DIR" "$json_docs" "$FEATURE_SPEC" "$IMPL_PLAN" "$TASKS"
    fi
else
    # Text output
    echo "FEATURE_DIR:$FEATURE_DIR"

    if [[ "$IS_META_SPEC" == "true" ]]; then
        echo "IS_META_SPEC: true"
        echo "USER_STORY: ${USER_STORY:-}"
        echo "MANIFEST: ${MANIFEST:-}"
    elif [[ "$IS_SUB_SPEC" == "true" ]]; then
        echo "IS_SUB_SPEC: true"
        echo "META_SPEC_DIR: ${META_SPEC_DIR:-}"
        echo "SUB_SPEC_ID: ${SUB_SPEC_ID:-}"
    fi

    echo "AVAILABLE_DOCS:"

    if [[ "$IS_META_SPEC" == "true" ]]; then
        check_file "$USER_STORY" "user-story.md"
        check_file "$BREAKDOWN" "breakdown.md"
        check_file "$MANIFEST" "manifest.json"
        check_file "$FEATURE_DIR/schedule.md" "schedule.md"
    else
        check_file "$FEATURE_SPEC" "spec.md"
        check_file "$IMPL_PLAN" "plan.md"
        check_file "$RESEARCH" "research.md"
        check_file "$DATA_MODEL" "data-model.md"
        check_dir "$CONTRACTS_DIR" "contracts/"
        check_file "$QUICKSTART" "quickstart.md"

        if $INCLUDE_TASKS; then
            check_file "$TASKS" "tasks.md"
        fi
    fi
fi
