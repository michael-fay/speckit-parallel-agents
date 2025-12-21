#!/usr/bin/env bash
#
# manifest.sh - Manifest management for meta-spec orchestration
#
# Provides functions for:
# - Lock acquisition/release (atomic via mkdir)
# - Manifest read/write with locking
# - Sub-spec status queries
# - Dependency resolution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ============================================================================
# Lock Management (atomic via mkdir)
# ============================================================================

# Acquire lock on manifest - MUST be called before any manifest modification
# Usage: acquire_manifest_lock <meta_spec_dir>
acquire_manifest_lock() {
    local meta_spec_dir="$1"
    local lockdir="$meta_spec_dir/manifest.lock"
    local max_attempts=100
    local attempt=0

    while ! mkdir "$lockdir" 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            # Check if lock is stale (older than 5 minutes)
            if [ -f "$lockdir/timestamp" ]; then
                local lock_time=$(cat "$lockdir/timestamp")
                local now=$(date +%s)
                local lock_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$lock_time" +%s 2>/dev/null || echo "0")
                local age=$((now - lock_epoch))

                if [ $age -gt 300 ]; then
                    echo "Warning: Stale lock detected (age: ${age}s), forcing removal" >&2
                    rm -rf "$lockdir"
                    continue
                fi
            fi

            echo "Error: Could not acquire manifest lock after $max_attempts attempts" >&2
            echo "Lock held by PID: $(cat "$lockdir/pid" 2>/dev/null || echo 'unknown')" >&2
            echo "Since: $(cat "$lockdir/timestamp" 2>/dev/null || echo 'unknown')" >&2
            exit 1
        fi
        sleep 0.1
    done

    # Store lock metadata for debugging
    echo "$$" > "$lockdir/pid"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$lockdir/timestamp"
    echo "$0" > "$lockdir/command"
}

# Release lock on manifest - MUST be called after manifest modification completes
# Usage: release_manifest_lock <meta_spec_dir>
release_manifest_lock() {
    local meta_spec_dir="$1"
    local lockdir="$meta_spec_dir/manifest.lock"

    if [ -d "$lockdir" ]; then
        # Verify we own the lock
        local lock_pid=$(cat "$lockdir/pid" 2>/dev/null || echo "0")
        if [ "$lock_pid" = "$$" ]; then
            rm -rf "$lockdir"
        else
            echo "Warning: Releasing lock we don't own (our PID: $$, lock PID: $lock_pid)" >&2
            rm -rf "$lockdir"
        fi
    fi
}

# ============================================================================
# Manifest Operations
# ============================================================================

# Initialize a new manifest for a meta-spec
# Usage: init_manifest <meta_spec_dir> <user_story_title>
init_manifest() {
    local meta_spec_dir="$1"
    local title="$2"
    local manifest_file="$meta_spec_dir/manifest.json"
    local meta_spec_id=$(basename "$meta_spec_dir")

    acquire_manifest_lock "$meta_spec_dir"

    cat > "$manifest_file" << EOF
{
  "version": "1.0.0",
  "metaSpec": {
    "id": "$meta_spec_id",
    "title": "$title",
    "userStoryFile": "user-story.md",
    "breakdownFile": "breakdown.md",
    "scheduled": false,
    "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "subSpecs": [],
  "schedule": null
}
EOF

    release_manifest_lock "$meta_spec_dir"
    echo "$manifest_file"
}

# Add a sub-spec to the manifest
# Usage: add_sub_spec <meta_spec_dir> <sub_spec_id> <title> <depends_json_array>
add_sub_spec() {
    local meta_spec_dir="$1"
    local sub_spec_id="$2"
    local title="$3"
    local depends="$4"  # JSON array like '["001-parser"]' or '[]'
    local manifest_file="$meta_spec_dir/manifest.json"
    local meta_spec_id=$(basename "$meta_spec_dir")

    acquire_manifest_lock "$meta_spec_dir"

    # Read current manifest
    local current=$(cat "$manifest_file")

    # Create new sub-spec entry
    local new_sub_spec=$(cat << EOF
{
  "id": "$sub_spec_id",
  "title": "$title",
  "depends": $depends,
  "phases": {
    "specify": "pending",
    "plan": "pending",
    "tasks": "pending",
    "implement": "blocked"
  },
  "branch": "${meta_spec_id}-${sub_spec_id}",
  "worktree": null,
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

    # Use jq to add the sub-spec (fall back to Python if jq not available)
    if command -v jq &> /dev/null; then
        echo "$current" | jq --argjson new "$new_sub_spec" '.subSpecs += [$new]' > "$manifest_file"
    else
        python3 -c "
import json, sys
manifest = json.loads('''$current''')
new_spec = json.loads('''$new_sub_spec''')
manifest['subSpecs'].append(new_spec)
print(json.dumps(manifest, indent=2))
" > "$manifest_file"
    fi

    release_manifest_lock "$meta_spec_dir"
}

# Update a sub-spec phase status
# Usage: update_phase <meta_spec_dir> <sub_spec_id> <phase> <status>
update_phase() {
    local meta_spec_dir="$1"
    local sub_spec_id="$2"
    local phase="$3"
    local status="$4"
    local manifest_file="$meta_spec_dir/manifest.json"

    acquire_manifest_lock "$meta_spec_dir"

    local current=$(cat "$manifest_file")

    if command -v jq &> /dev/null; then
        echo "$current" | jq --arg id "$sub_spec_id" --arg phase "$phase" --arg status "$status" \
            '(.subSpecs[] | select(.id == $id) | .phases[$phase]) = $status' > "$manifest_file"
    else
        python3 -c "
import json
manifest = json.loads('''$current''')
for spec in manifest['subSpecs']:
    if spec['id'] == '$sub_spec_id':
        spec['phases']['$phase'] = '$status'
        break
print(json.dumps(manifest, indent=2))
" > "$manifest_file"
    fi

    release_manifest_lock "$meta_spec_dir"
}

# Update worktree path for a sub-spec
# Usage: update_worktree <meta_spec_dir> <sub_spec_id> <worktree_path>
update_worktree() {
    local meta_spec_dir="$1"
    local sub_spec_id="$2"
    local worktree_path="$3"
    local manifest_file="$meta_spec_dir/manifest.json"

    acquire_manifest_lock "$meta_spec_dir"

    local current=$(cat "$manifest_file")

    if command -v jq &> /dev/null; then
        echo "$current" | jq --arg id "$sub_spec_id" --arg path "$worktree_path" \
            '(.subSpecs[] | select(.id == $id) | .worktree) = $path' > "$manifest_file"
    else
        python3 -c "
import json
manifest = json.loads('''$current''')
for spec in manifest['subSpecs']:
    if spec['id'] == '$sub_spec_id':
        spec['worktree'] = '$worktree_path'
        break
print(json.dumps(manifest, indent=2))
" > "$manifest_file"
    fi

    release_manifest_lock "$meta_spec_dir"
}

# Mark the meta-spec as scheduled
# Usage: mark_scheduled <meta_spec_dir> <schedule_json>
mark_scheduled() {
    local meta_spec_dir="$1"
    local schedule_json="$2"
    local manifest_file="$meta_spec_dir/manifest.json"

    acquire_manifest_lock "$meta_spec_dir"

    local current=$(cat "$manifest_file")

    if command -v jq &> /dev/null; then
        echo "$current" | jq --argjson schedule "$schedule_json" \
            '.metaSpec.scheduled = true | .schedule = $schedule' > "$manifest_file"
    else
        python3 -c "
import json
manifest = json.loads('''$current''')
schedule = json.loads('''$schedule_json''')
manifest['metaSpec']['scheduled'] = True
manifest['schedule'] = schedule
print(json.dumps(manifest, indent=2))
" > "$manifest_file"
    fi

    release_manifest_lock "$meta_spec_dir"
}

# ============================================================================
# Query Operations (read-only, no locking needed)
# ============================================================================

# Get sub-specs ready for a specific phase
# Usage: get_ready_for_phase <meta_spec_dir> <phase>
# Returns: JSON array of sub-spec IDs ready for that phase
get_ready_for_phase() {
    local meta_spec_dir="$1"
    local phase="$2"
    local manifest_file="$meta_spec_dir/manifest.json"

    if [ ! -f "$manifest_file" ]; then
        echo "[]"
        return
    fi

    local manifest=$(cat "$manifest_file")

    case "$phase" in
        specify)
            # Ready if: phase is pending (breakdown created the entry)
            if command -v jq &> /dev/null; then
                echo "$manifest" | jq '[.subSpecs[] | select(.phases.specify == "pending") | .id]'
            else
                python3 -c "
import json
m = json.loads('''$manifest''')
print(json.dumps([s['id'] for s in m['subSpecs'] if s['phases']['specify'] == 'pending']))
"
            fi
            ;;
        plan)
            # Ready if: own specify is complete
            if command -v jq &> /dev/null; then
                echo "$manifest" | jq '[.subSpecs[] | select(.phases.specify == "complete" and .phases.plan == "pending") | .id]'
            else
                python3 -c "
import json
m = json.loads('''$manifest''')
print(json.dumps([s['id'] for s in m['subSpecs'] if s['phases']['specify'] == 'complete' and s['phases']['plan'] == 'pending']))
"
            fi
            ;;
        tasks)
            # Ready if: own plan is complete
            if command -v jq &> /dev/null; then
                echo "$manifest" | jq '[.subSpecs[] | select(.phases.plan == "complete" and .phases.tasks == "pending") | .id]'
            else
                python3 -c "
import json
m = json.loads('''$manifest''')
print(json.dumps([s['id'] for s in m['subSpecs'] if s['phases']['plan'] == 'complete' and s['phases']['tasks'] == 'pending']))
"
            fi
            ;;
        implement)
            # Ready if: scheduled AND tasks complete AND all deps have implement complete
            if command -v jq &> /dev/null; then
                echo "$manifest" | jq '
                    .metaSpec.scheduled as $scheduled |
                    if $scheduled then
                        [.subSpecs[] |
                            select(.phases.tasks == "complete" and .phases.implement == "pending") |
                            . as $spec |
                            if (.depends | length) == 0 then .id
                            else
                                [.depends[] as $dep |
                                    $spec | .id as $id |
                                    [$.subSpecs[] | select(.id == $dep and .phases.implement == "complete")] | length
                                ] |
                                if (. | all(. > 0)) then $id else empty end
                            end
                        ]
                    else []
                    end
                '
            else
                python3 -c "
import json
m = json.loads('''$manifest''')
if not m['metaSpec']['scheduled']:
    print('[]')
else:
    completed = {s['id'] for s in m['subSpecs'] if s['phases']['implement'] == 'complete'}
    ready = []
    for s in m['subSpecs']:
        if s['phases']['tasks'] == 'complete' and s['phases']['implement'] == 'pending':
            if all(d in completed for d in s['depends']):
                ready.append(s['id'])
    print(json.dumps(ready))
"
            fi
            ;;
    esac
}

# Get next sub-spec for a phase (first available)
# Usage: get_next_for_phase <meta_spec_dir> <phase>
get_next_for_phase() {
    local meta_spec_dir="$1"
    local phase="$2"
    local ready=$(get_ready_for_phase "$meta_spec_dir" "$phase")

    if command -v jq &> /dev/null; then
        echo "$ready" | jq -r '.[0] // empty'
    else
        python3 -c "
import json
r = json.loads('''$ready''')
print(r[0] if r else '')
"
    fi
}

# Check if all sub-specs have completed a phase
# Usage: all_phase_complete <meta_spec_dir> <phase>
all_phase_complete() {
    local meta_spec_dir="$1"
    local phase="$2"
    local manifest_file="$meta_spec_dir/manifest.json"

    if [ ! -f "$manifest_file" ]; then
        echo "false"
        return
    fi

    local manifest=$(cat "$manifest_file")

    if command -v jq &> /dev/null; then
        echo "$manifest" | jq --arg phase "$phase" \
            'if (.subSpecs | length) == 0 then false else [.subSpecs[].phases[$phase]] | all(. == "complete") end'
    else
        python3 -c "
import json
m = json.loads('''$manifest''')
if not m['subSpecs']:
    print('false')
else:
    print('true' if all(s['phases']['$phase'] == 'complete' for s in m['subSpecs']) else 'false')
"
    fi
}

# Get manifest summary (for display)
# Usage: get_manifest_summary <meta_spec_dir>
get_manifest_summary() {
    local meta_spec_dir="$1"
    local manifest_file="$meta_spec_dir/manifest.json"

    if [ ! -f "$manifest_file" ]; then
        echo "No manifest found"
        return
    fi

    local manifest=$(cat "$manifest_file")

    if command -v jq &> /dev/null; then
        echo "$manifest" | jq -r '
            "Meta-Spec: \(.metaSpec.title) (\(.metaSpec.id))",
            "Scheduled: \(.metaSpec.scheduled)",
            "",
            "Sub-Specs:",
            (.subSpecs[] | "  \(.id): specify=\(.phases.specify) plan=\(.phases.plan) tasks=\(.phases.tasks) implement=\(.phases.implement)")
        '
    else
        python3 -c "
import json
m = json.loads('''$manifest''')
print(f'Meta-Spec: {m[\"metaSpec\"][\"title\"]} ({m[\"metaSpec\"][\"id\"]})')
print(f'Scheduled: {m[\"metaSpec\"][\"scheduled\"]}')
print()
print('Sub-Specs:')
for s in m['subSpecs']:
    p = s['phases']
    print(f'  {s[\"id\"]}: specify={p[\"specify\"]} plan={p[\"plan\"]} tasks={p[\"tasks\"]} implement={p[\"implement\"]}')
"
    fi
}

# Find the meta-spec directory for current context
# Usage: find_meta_spec_dir
find_meta_spec_dir() {
    local repo_root=$(get_repo_root)
    local current_branch=$(get_current_branch)

    # If we're in a worktree, extract meta-spec from branch name
    # Format: <meta-spec-id>-<sub-spec-id>
    if [[ "$current_branch" =~ ^([0-9]{3}-[^-]+)- ]]; then
        local meta_spec_id="${BASH_REMATCH[1]}"
        local meta_spec_dir="$repo_root/specs/$meta_spec_id"
        if [ -d "$meta_spec_dir" ]; then
            echo "$meta_spec_dir"
            return
        fi
    fi

    # Fall back to looking for manifest.json in specs subdirectories
    for dir in "$repo_root/specs"/*/; do
        if [ -f "$dir/manifest.json" ]; then
            echo "${dir%/}"
            return
        fi
    done

    echo ""
}

# ============================================================================
# CLI Interface
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        init)
            init_manifest "$2" "$3"
            ;;
        add-sub-spec)
            add_sub_spec "$2" "$3" "$4" "$5"
            ;;
        update-phase)
            update_phase "$2" "$3" "$4" "$5"
            ;;
        update-worktree)
            update_worktree "$2" "$3" "$4"
            ;;
        mark-scheduled)
            mark_scheduled "$2" "$3"
            ;;
        get-ready)
            get_ready_for_phase "$2" "$3"
            ;;
        get-next)
            get_next_for_phase "$2" "$3"
            ;;
        all-complete)
            all_phase_complete "$2" "$3"
            ;;
        summary)
            get_manifest_summary "$2"
            ;;
        find-meta-spec)
            find_meta_spec_dir
            ;;
        *)
            echo "Usage: $0 <command> [args]"
            echo ""
            echo "Commands:"
            echo "  init <meta_spec_dir> <title>              Initialize manifest"
            echo "  add-sub-spec <dir> <id> <title> <deps>    Add sub-spec"
            echo "  update-phase <dir> <id> <phase> <status>  Update phase status"
            echo "  update-worktree <dir> <id> <path>         Update worktree path"
            echo "  mark-scheduled <dir> <schedule_json>      Mark as scheduled"
            echo "  get-ready <dir> <phase>                   Get IDs ready for phase"
            echo "  get-next <dir> <phase>                    Get next ID for phase"
            echo "  all-complete <dir> <phase>                Check if all complete"
            echo "  summary <dir>                             Show manifest summary"
            echo "  find-meta-spec                            Find meta-spec directory"
            exit 1
            ;;
    esac
fi
