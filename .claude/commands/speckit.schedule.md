---
description: Analyze dependencies and create the implementation execution schedule. REQUIRED before implementation.
handoffs:
  - label: Start Implementation
    agent: speckit.implement-next
    prompt: Implement the next scheduled sub-spec
---

## User Input

```text
$ARGUMENTS
```

## Purpose

This is a **required human-in-the-loop gate** before implementation can begin. It:
1. Analyzes all sub-spec dependencies
2. Validates that all tasks are complete
3. Creates an optimal execution schedule
4. Identifies parallelization opportunities
5. Unblocks the implement phase in the manifest

**CRITICAL**: Implementation cannot proceed until this command is run.

## Prerequisites

All sub-specs must have:
- `specify: complete`
- `plan: complete`
- `tasks: complete`

```bash
ALL_TASKS=$(.specify/scripts/bash/manifest.sh all-complete "$META_SPEC_DIR" "tasks")
if [ "$ALL_TASKS" != "true" ]; then
    echo "Error: Not all sub-specs have completed tasks phase."
    echo "Run /speckit.tasks-next or /speckit.tasks-all first."
    exit 1
fi
```

## Outline

### 1. Find Meta-Spec Directory

```bash
META_SPEC_DIR=$(.specify/scripts/bash/manifest.sh find-meta-spec)
```

### 2. Validate Prerequisites

Ensure all sub-specs have completed specify, plan, and tasks phases.

### 3. Load All Sub-Spec Information

For each sub-spec, read:
- `tasks.md` - To understand task dependencies
- Manifest entry - To get explicit dependencies

### 4. Build Dependency Graph

Create a visual and data representation of dependencies:

```markdown
## Dependency Analysis

### Sub-Spec Dependencies

| Sub-Spec | Depends On | Blocks |
|----------|------------|--------|
| 001-parser | - | 002, 003 |
| 002-native-adapter | 001 | 004 |
| 003-web-adapter | 001 | 004 |
| 004-core-component | 002, 003 | - |

### Dependency Graph

```
Level 0 (Foundation):
  └── 001-parser

Level 1 (Parallel):
  ├── 002-native-adapter
  └── 003-web-adapter

Level 2 (Integration):
  └── 004-core-component
```
```

### 5. Detect Issues

Check for:
- **Circular dependencies**: Report error if found
- **Missing dependencies**: Sub-spec references non-existent sub-spec
- **Orphan sub-specs**: Sub-specs with no path to foundation

### 6. Generate Execution Schedule

Create optimal execution order considering:
- Dependency constraints (must complete before dependents)
- Parallelization opportunities (same level can run concurrently)
- Critical path (longest dependency chain)

```markdown
## Execution Schedule

### Phase 1: Foundation
| Order | Sub-Spec | Can Parallelize | Est. Effort |
|-------|----------|-----------------|-------------|
| 1 | 001-parser | No (foundation) | Medium |

### Phase 2: Platform Adapters
| Order | Sub-Spec | Can Parallelize | Est. Effort |
|-------|----------|-----------------|-------------|
| 2 | 002-native-adapter | Yes (with 003) | High |
| 2 | 003-web-adapter | Yes (with 002) | Medium |

### Phase 3: Integration
| Order | Sub-Spec | Can Parallelize | Est. Effort |
|-------|----------|-----------------|-------------|
| 3 | 004-core-component | No (final) | Low |

### Critical Path
001-parser → 002-native-adapter → 004-core-component (or via 003)

### Parallelization Summary
- **Sequential phases**: 3
- **Max parallel sub-specs**: 2 (Phase 2)
- **Estimated speedup**: ~25% vs fully sequential
```

### 7. Present Schedule for Approval

```markdown
## Schedule Review

The following execution schedule has been generated:

[Include full schedule from above]

### Considerations

1. **Phase 1** must complete before Phase 2 can begin
2. **Phase 2** sub-specs can be implemented in parallel using separate worktrees
3. **Phase 3** requires both Phase 2 sub-specs to be merged first

### Questions

Before approving, consider:
- Is the dependency analysis correct?
- Should any sub-specs be reordered?
- Are the parallelization opportunities acceptable?

**Approve this schedule?**
- [Yes, proceed] - Save schedule and unblock implementation
- [No, adjust] - Describe changes needed
```

### 8. Save Schedule to Manifest

Upon approval, create `$META_SPEC_DIR/schedule.md` and update manifest:

```bash
# Create schedule JSON
SCHEDULE_JSON=$(cat << 'EOF'
{
  "phases": [
    {
      "phase": 1,
      "name": "Foundation",
      "subSpecs": ["001-parser"],
      "parallel": false
    },
    {
      "phase": 2,
      "name": "Platform Adapters",
      "subSpecs": ["002-native-adapter", "003-web-adapter"],
      "parallel": true
    },
    {
      "phase": 3,
      "name": "Integration",
      "subSpecs": ["004-core-component"],
      "parallel": false
    }
  ],
  "criticalPath": ["001-parser", "002-native-adapter", "004-core-component"],
  "approvedAt": "2025-01-15T10:30:00Z",
  "approvedBy": "human"
}
EOF
)

.specify/scripts/bash/manifest.sh mark-scheduled "$META_SPEC_DIR" "$SCHEDULE_JSON"
```

### 9. Sync All Worktrees

**IMPORTANT**: Before implementation begins, sync all worktrees with the meta-spec branch to ensure they have the latest spec/plan/tasks files:

```bash
.specify/scripts/bash/worktree-sync.sh --meta-spec "$META_SPEC_DIR"
```

This rebases all sub-spec worktree branches onto the meta-spec branch, giving them:
- The latest spec.md, plan.md, tasks.md files
- Updated scripts in .specify/
- Any other changes made during the planning phases

If any worktree has uncommitted changes, the sync will skip it with a warning. Ensure all worktrees are clean before syncing.

### 10. Unblock Implementation

Update all sub-specs from `implement: blocked` to `implement: pending`:

This is done atomically by the `mark-scheduled` command, which:
1. Sets `metaSpec.scheduled = true`
2. Stores the schedule JSON
3. Updates sub-spec implement phases based on dependencies

### 11. Report Completion

```markdown
## Schedule Approved

**Meta-Spec**: [ID]
**Schedule File**: specs/[meta-spec-id]/schedule.md
**Status**: Implementation unblocked

### Execution Order

1. **Phase 1**: 001-parser (sequential)
2. **Phase 2**: 002-native-adapter, 003-web-adapter (parallel)
3. **Phase 3**: 004-core-component (sequential)

### Next Steps

Implementation is now unblocked. You can:

1. **Sequential approach**:
   ```
   /speckit.implement-next
   ```
   Implements one sub-spec at a time in schedule order.

2. **Parallel approach** (for Phase 2):
   - Open separate terminal/session for each parallel sub-spec
   - Navigate to each worktree
   - Run implementation independently
   - Merge when all parallel sub-specs complete

### Worktree Locations

| Sub-Spec | Worktree Path |
|----------|---------------|
| 001-parser | ../<project>-worktrees/<meta-spec-id>-001-parser |
| 002-adapter-a | ../<project>-worktrees/<meta-spec-id>-002-adapter-a |
| 003-adapter-b | ../<project>-worktrees/<meta-spec-id>-003-adapter-b |
| 004-integration | ../<project>-worktrees/<meta-spec-id>-004-integration |
```

## Error Handling

### Circular Dependency Detected

```markdown
## Error: Circular Dependency

A circular dependency was detected:

001-parser → 002-native-adapter → 003-web-adapter → 001-parser

This must be resolved before scheduling can proceed.

### Resolution Options
1. Remove the dependency from one sub-spec
2. Merge the cyclically-dependent sub-specs
3. Extract shared code into a new foundation sub-spec
```

### Prerequisites Not Met

```markdown
## Error: Prerequisites Not Met

The following sub-specs have not completed all phases:

| Sub-Spec | Specify | Plan | Tasks |
|----------|---------|------|-------|
| 002-native-adapter | complete | complete | pending |

Run `/speckit.tasks-next` to complete task generation.
```

## Guidelines

### Schedule Considerations

- Foundation sub-specs should always be first
- Maximize parallelization where safe
- Consider team capacity when suggesting parallel work
- Integration/glue sub-specs should be last

### Human Review Importance

This gate exists because:
1. Dependency analysis may miss subtle requirements
2. Team capacity affects parallelization decisions
3. Business priorities may override technical order
4. Risk assessment requires human judgment
