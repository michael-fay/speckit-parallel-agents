#!/usr/bin/env bash
#
# create-sub-spec.sh - Create a sub-spec within a meta-spec
#
# Usage: create-sub-spec.sh [--json] --meta-spec <meta-spec-dir> --id <sub-spec-id> --title <title> [--depends <dep1,dep2>]
#
# Creates:
#   - Sub-spec directory within meta-spec
#   - Git branch for the sub-spec
#   - Git worktree for parallel development
#   - Updates manifest.json with the new sub-spec

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Parse arguments
JSON_MODE=false
META_SPEC_DIR=""
SUB_SPEC_ID=""
TITLE=""
DEPENDS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            shift
            ;;
        --meta-spec)
            META_SPEC_DIR="$2"
            shift 2
            ;;
        --id)
            SUB_SPEC_ID="$2"
            shift 2
            ;;
        --title)
            TITLE="$2"
            shift 2
            ;;
        --depends)
            DEPENDS="$2"
            shift 2
            ;;
        --help|-h)
            cat << 'EOF'
Usage: create-sub-spec.sh [OPTIONS]

Create a sub-spec within a meta-spec for parallel development.

OPTIONS:
  --json                Output in JSON format
  --meta-spec <dir>     Path to meta-spec directory (required)
  --id <id>             Sub-spec ID, e.g., "001-parser" (required)
  --title <title>       Sub-spec title (required)
  --depends <deps>      Comma-separated list of dependency sub-spec IDs
  --help, -h            Show this help message

EXAMPLES:
  # Create a foundation sub-spec with no dependencies
  ./create-sub-spec.sh --meta-spec specs/001-html-renderer --id 001-parser --title "Parser & Sanitizer"

  # Create a sub-spec that depends on another
  ./create-sub-spec.sh --meta-spec specs/001-html-renderer --id 002-native --title "Native Adapter" --depends 001-parser

  # Create a sub-spec with multiple dependencies
  ./create-sub-spec.sh --meta-spec specs/001-html-renderer --id 004-core --title "Core Component" --depends "002-native,003-web"
EOF
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$META_SPEC_DIR" ]]; then
    echo "Error: --meta-spec is required" >&2
    exit 1
fi

if [[ -z "$SUB_SPEC_ID" ]]; then
    echo "Error: --id is required" >&2
    exit 1
fi

if [[ -z "$TITLE" ]]; then
    echo "Error: --title is required" >&2
    exit 1
fi

# Validate meta-spec directory
if [[ ! -d "$META_SPEC_DIR" ]]; then
    echo "Error: Meta-spec directory not found: $META_SPEC_DIR" >&2
    exit 1
fi

if [[ ! -f "$META_SPEC_DIR/manifest.json" ]]; then
    echo "Error: Not a valid meta-spec (no manifest.json): $META_SPEC_DIR" >&2
    exit 1
fi

# Get repository root
REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Extract meta-spec ID from directory name
META_SPEC_ID=$(basename "$META_SPEC_DIR")

# Construct branch name: meta-spec-id-sub-spec-id
BRANCH_NAME="${META_SPEC_ID}-${SUB_SPEC_ID}"

# Create sub-spec directory
SUB_SPEC_DIR="$META_SPEC_DIR/$SUB_SPEC_ID"
mkdir -p "$SUB_SPEC_DIR"

# Copy spec template
TEMPLATE="$REPO_ROOT/.specify/templates/spec-template.md"
SPEC_FILE="$SUB_SPEC_DIR/spec.md"
if [[ -f "$TEMPLATE" ]]; then
    cp "$TEMPLATE" "$SPEC_FILE"
else
    touch "$SPEC_FILE"
fi

# Convert depends to JSON array
if [[ -z "$DEPENDS" ]]; then
    DEPENDS_JSON="[]"
else
    # Convert comma-separated to JSON array
    DEPENDS_JSON=$(echo "$DEPENDS" | tr ',' '\n' | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//' | sed 's/^/[/;s/$/]/')
fi

# Update manifest with new sub-spec
"$SCRIPT_DIR/manifest.sh" add-sub-spec "$META_SPEC_DIR" "$SUB_SPEC_ID" "$TITLE" "$DEPENDS_JSON"

# Create git branch (if git available)
HAS_GIT=false
if git rev-parse --show-toplevel >/dev/null 2>&1; then
    HAS_GIT=true

    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
        echo "Warning: Branch $BRANCH_NAME already exists" >&2
    else
        git branch "$BRANCH_NAME" main 2>/dev/null || git branch "$BRANCH_NAME" HEAD
    fi

    # Create worktree
    REPO_NAME=$(basename "$REPO_ROOT")
    WORKTREE_CONTAINER="$(dirname "$REPO_ROOT")/${REPO_NAME}-worktrees"
    WORKTREE_PATH="$WORKTREE_CONTAINER/$BRANCH_NAME"

    if [[ ! -d "$WORKTREE_PATH" ]]; then
        mkdir -p "$WORKTREE_CONTAINER"
        git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" 2>/dev/null || true
    fi

    # Update manifest with worktree path
    "$SCRIPT_DIR/manifest.sh" update-worktree "$META_SPEC_DIR" "$SUB_SPEC_ID" "$WORKTREE_PATH"
fi

# Output results
if $JSON_MODE; then
    if [[ "$HAS_GIT" == "true" ]]; then
        printf '{"SUB_SPEC_ID":"%s","BRANCH_NAME":"%s","SUB_SPEC_DIR":"%s","SPEC_FILE":"%s","WORKTREE":"%s","DEPENDS":%s}\n' \
            "$SUB_SPEC_ID" "$BRANCH_NAME" "$SUB_SPEC_DIR" "$SPEC_FILE" "$WORKTREE_PATH" "$DEPENDS_JSON"
    else
        printf '{"SUB_SPEC_ID":"%s","BRANCH_NAME":"%s","SUB_SPEC_DIR":"%s","SPEC_FILE":"%s","WORKTREE":null,"DEPENDS":%s}\n' \
            "$SUB_SPEC_ID" "$BRANCH_NAME" "$SUB_SPEC_DIR" "$SPEC_FILE" "$DEPENDS_JSON"
    fi
else
    echo "SUB_SPEC_ID: $SUB_SPEC_ID"
    echo "BRANCH_NAME: $BRANCH_NAME"
    echo "SUB_SPEC_DIR: $SUB_SPEC_DIR"
    echo "SPEC_FILE: $SPEC_FILE"
    if [[ "$HAS_GIT" == "true" ]]; then
        echo "WORKTREE: $WORKTREE_PATH"
    fi
    echo "DEPENDS: $DEPENDS_JSON"
    echo ""
    echo "Sub-spec created successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Navigate to worktree: cd $WORKTREE_PATH"
    echo "  2. Run /speckit.specify-next to specify this sub-spec"
fi
