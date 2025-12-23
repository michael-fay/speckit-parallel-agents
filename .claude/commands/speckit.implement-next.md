---
description: Implement the next sub-spec according to the approved schedule.
handoffs:
  - label: Implement Another
    agent: speckit.implement-next
    prompt: Implement the next scheduled sub-spec
---

## User Input

```text
$ARGUMENTS
```

## Purpose

This command implements the next sub-spec that is ready according to the approved schedule. It respects dependency order and blocks if dependencies are not yet complete.

## Prerequisites

1. Schedule must be approved (`/speckit.schedule` completed)
2. All dependency sub-specs must have `implement: complete`

## Outline

### 1. Find Meta-Spec Directory

```bash
META_SPEC_DIR=$(.specify/scripts/bash/manifest.sh find-meta-spec)
```

### 2. Verify Schedule Exists

```bash
# Check if scheduled
SCHEDULED=$(cat "$META_SPEC_DIR/manifest.json" | jq -r '.metaSpec.scheduled')
if [ "$SCHEDULED" != "true" ]; then
    echo "Error: Implementation not scheduled."
    echo "Run /speckit.schedule first."
    exit 1
fi
```

### 3. Query Manifest for Next Ready Sub-Spec

```bash
NEXT_ID=$(.specify/scripts/bash/manifest.sh get-next "$META_SPEC_DIR" "implement")
```

The `get-next implement` query checks:
- Schedule is approved
- Tasks phase is complete
- All dependencies have `implement: complete`

### 4. Handle Empty/Blocked State

**Check all possible states when NEXT_ID is empty:**

```bash
# Get counts of sub-specs in each state
READY_COUNT=$(.specify/scripts/bash/manifest.sh get-ready "$META_SPEC_DIR" "implement" | jq 'length')
IN_PROGRESS=$(cat "$META_SPEC_DIR/manifest.json" | jq '[.subSpecs[] | select(.phases.implement == "in-progress")] | length')
COMPLETE=$(cat "$META_SPEC_DIR/manifest.json" | jq '[.subSpecs[] | select(.phases.implement == "complete")] | length')
TOTAL=$(cat "$META_SPEC_DIR/manifest.json" | jq '.subSpecs | length')
```

**Case A: All implementations complete**
```markdown
## All Implementations Complete! 🎉

All $TOTAL sub-specs have been implemented.

Run the final merge and integration steps as described in the schedule.
```

**Case B: No parallel tasks available (in-progress blocking)**
```markdown
## No Parallel Tasks Available

**Status**: $COMPLETE of $TOTAL sub-specs complete, $IN_PROGRESS in progress.

The next sub-spec(s) are blocked waiting for dependencies to complete:

| Sub-Spec | Waiting For | Blocker Status |
|----------|-------------|----------------|
| 002-native-adapter | 001-parser | in-progress |
| 003-web-adapter | 001-parser | in-progress |

### What This Means

All available parallel work is currently being executed. You cannot start another implementation until the in-progress work completes.

### Options

1. **Resume existing work**: Navigate to an in-progress worktree and run `/speckit.implement`:
   ```bash
   cd ../<project>-worktrees/<meta-spec-id>-<sub-spec-id>
   # Then run /speckit.implement to resume
   ```

2. **Wait**: Let the in-progress implementation complete naturally

3. **Check status**:
   ```bash
   .specify/scripts/bash/manifest.sh summary $META_SPEC_DIR
   ```

### Currently In Progress
```
*List each in-progress sub-spec with its worktree path*

**IMPORTANT**: `/speckit.implement-next` always starts a NEW sub-spec. To resume an existing in-progress implementation, navigate to its worktree and run `/speckit.implement` instead.

### 5. Update Manifest to In-Progress (Atomic)

Use the atomic manifest update script to safely update the phase:

```bash
.specify/scripts/bash/manifest-update.sh "$META_SPEC_DIR" update-phase "$NEXT_ID" "implement" "in-progress"
```

This script follows the **worktree→remote→meta-spec protocol**:
1. Acquires file lock
2. Updates the manifest in the worktree
3. Commits with standardized message
4. Pushes to the **worktree's remote branch**
5. Merges the worktree branch into the **meta-spec branch** (in main worktree)
6. Pushes the meta-spec branch to remote
7. Releases lock

This ensures manifest changes are always synced from worktree → remote → meta-spec branch.

### 6. Navigate to Worktree

```bash
# Get worktree path from manifest
WORKTREE_PATH=$(cat "$META_SPEC_DIR/manifest.json" | jq -r ".subSpecs[] | select(.id == \"$NEXT_ID\") | .worktree")
cd "$WORKTREE_PATH"
```

### 7. Load Implementation Context

Read all artifacts:
- `$META_SPEC_DIR/$NEXT_ID/spec.md` - Requirements
- `$META_SPEC_DIR/$NEXT_ID/plan.md` - Design
- `$META_SPEC_DIR/$NEXT_ID/tasks.md` - Task list
- `$META_SPEC_DIR/$NEXT_ID/research.md` - Research (if exists)
- `.specify/docs/CONSTITUTION-REFERENCE.md` - Principles

### 8. Execute Implementation

Follow the task list in order, using TDD:

1. **For each task**:
   - Read the task description
   - Write failing test (RED)
   - Implement minimal code to pass (GREEN)
   - Refactor if needed
   - Commit

2. **Track progress**:
   - Check off tasks in tasks.md as they complete
   - Commit after each logical unit

3. **Handle blockers**:
   - If a task is marked `[BLOCKED: other-sub-spec]`, skip it
   - These will be resolved when dependencies complete
   - Document any discovered cross-sub-spec issues

### 9. Run Quality Checks

After all tasks complete:

```bash
# Run linting
npm run lint

# Run type checking
npm run typecheck

# Run tests
npm test

# Check for ignore comments
grep -r "eslint-disable\|@ts-ignore\|@ts-expect-error" src/
```

### 10. Update Manifest to Complete (Atomic)

Use the atomic manifest update script:

```bash
.specify/scripts/bash/manifest-update.sh "$META_SPEC_DIR" update-phase "$NEXT_ID" "implement" "complete"
```

### 11. Commit and Push

```bash
git add -A
git commit -m "feat($NEXT_ID): Complete implementation

- [List key changes]
- Tests passing
- Quality checks passing"

git push origin HEAD
```

### 12. Report Completion and Next Steps

```markdown
## Implementation Complete

**Sub-Spec**: [ID] - [Title]
**Branch**: [meta-spec-id]-[sub-spec-id]
**Status**: Complete

### Summary
- Tasks completed: X of X
- Tests: All passing
- Quality checks: Passing

### Progress
- Implemented: X of Y sub-specs
- Remaining: [list]

### Next Steps
```

**If more sub-specs ready**:
```markdown
The following sub-specs are now unblocked:
- 002-native-adapter (was waiting for 001-parser)
- 003-web-adapter (was waiting for 001-parser)

Run `/speckit.implement-next` to continue.

Or for parallel implementation:
1. Open a new terminal for 002-native-adapter
2. Open another for 003-web-adapter
3. Navigate to their worktrees and run `/speckit.implement-next` in each
```

**If all complete**:
```markdown
## All Sub-Specs Implemented!

All sub-specs have been implemented. Final steps:

1. **Merge branches** (in order):
   ```bash
   cd /path/to/<project>
   git checkout main
   git merge <meta-spec-id>-001-parser
   git merge <meta-spec-id>-002-adapter-a
   git merge <meta-spec-id>-003-adapter-b
   git merge <meta-spec-id>-004-integration
   ```

2. **Run integration tests**

3. **Clean up worktrees**:
   ```bash
   .specify/scripts/bash/worktree-remove.sh <meta-spec-id>-001-parser
   # ... repeat for each
   ```

4. **Create PR for the complete feature**
```

## Error Handling

### Quality Check Failures

If quality checks fail:
1. Do NOT mark as complete
2. Fix the issues
3. Re-run quality checks
4. Only then update manifest

### Test Failures

If tests fail:
1. Debug and fix
2. Ensure all tests pass
3. Do NOT skip tests or add ignore comments

### Merge Conflicts (when syncing with main)

If conflicts arise:
1. Resolve carefully
2. Re-run tests after resolution
3. Document any significant changes

## Guidelines

### TDD Workflow (from Constitution)

```
1. Write one test for one behavior
2. Run test → observe failure (RED)
3. Write minimal implementation to pass
4. Run test → observe success (GREEN)
5. Refactor if needed
6. Repeat
```

### Commit Practices

- Commit after each logical change
- Use conventional commit format: `feat`, `fix`, `test`, `refactor`
- Reference sub-spec ID in commits
- Push regularly to backup work

### Cross-Sub-Spec Considerations

When implementing a sub-spec that depends on others:
- Import types/interfaces from the dependency
- Don't modify files in other sub-specs
- Document integration points
- Add integration tests for cross-sub-spec behavior
