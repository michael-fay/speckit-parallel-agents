---
description: Run specify on the next available sub-spec in the meta-spec workflow.
handoffs:
  - label: Plan Next Sub-Spec
    agent: speckit.plan-next
    prompt: Plan the next available sub-spec
---

## User Input

```text
$ARGUMENTS
```

## Purpose

This command finds the next sub-spec that is ready for specification and runs the specify workflow on it. It updates the manifest to track progress.

## Outline

### 1. Find Meta-Spec Directory

```bash
META_SPEC_DIR=$(.specify/scripts/bash/manifest.sh find-meta-spec)
```

If no meta-spec found, inform the user to run `/speckit.specify` or `/speckit.breakdown` first.

### 2. Query Manifest for Next Sub-Spec

```bash
NEXT_ID=$(.specify/scripts/bash/manifest.sh get-next "$META_SPEC_DIR" "specify")
```

If NEXT_ID is empty, check why:
- If all sub-specs have `specify: complete`, report "All sub-specs specified. Run `/speckit.plan-next`"
- If no sub-specs exist, report "No sub-specs found. Run `/speckit.breakdown` first"

### 3. Update Manifest to In-Progress

```bash
.specify/scripts/bash/manifest.sh update-phase "$META_SPEC_DIR" "$NEXT_ID" "specify" "in-progress"
```

### 4. Navigate to Worktree

Read the manifest to get the worktree path for this sub-spec:

```bash
# The worktree was created during breakdown
cd "../iris-ornament-worktrees/[meta-spec-id]-[sub-spec-id]"
```

### 5. Read Sub-Spec Context

From the meta-spec directory, read:
- `breakdown.md` - for this sub-spec's scope, deliverables, and success criteria
- `user-story.md` - for overall context
- `.specify/docs/CONSTITUTION-REFERENCE.md` - for project principles

### 6. Generate Sub-Spec Specification

Create `$META_SPEC_DIR/$NEXT_ID/spec.md` using the standard spec template, populated with:
- Scope from breakdown.md
- Deliverables as functional requirements
- Success criteria from breakdown.md
- User scenarios derived from the sub-spec's purpose

**IMPORTANT**: The spec should be detailed enough for independent implementation but reference the meta-spec for overall context.

### 7. Run Specification Quality Validation

Follow the same validation flow as standard `/speckit.specify`:
- Create quality checklist
- Validate against criteria
- Handle any [NEEDS CLARIFICATION] markers
- Iterate until passing

### 8. Update Manifest to Complete

```bash
.specify/scripts/bash/manifest.sh update-phase "$META_SPEC_DIR" "$NEXT_ID" "specify" "complete"
```

### 9. Report Results

```markdown
## Sub-Spec Specified

**Sub-Spec**: [ID] - [Title]
**Spec File**: specs/[meta-spec-id]/[sub-spec-id]/spec.md
**Status**: Complete

### Progress
- Specified: X of Y sub-specs
- Ready for plan: [list IDs]
- Blocked: [list IDs with reasons]

### Next Steps
- Run `/speckit.specify-next` to specify another sub-spec
- Run `/speckit.plan-next` to start planning specified sub-specs
```

### 10. Check for Parallel Opportunities

If other sub-specs are also ready for specify, mention:

```markdown
### Parallel Opportunity

The following sub-specs can also be specified in parallel:
- [list other ready sub-spec IDs]

Consider running `/speckit.specify-all` to specify them concurrently.
```

## Error Handling

### No Sub-Specs Ready

If `get-next` returns empty:

```bash
# Check if all are complete
ALL_COMPLETE=$(.specify/scripts/bash/manifest.sh all-complete "$META_SPEC_DIR" "specify")
if [ "$ALL_COMPLETE" = "true" ]; then
    echo "All sub-specs have been specified."
    echo "Next step: Run /speckit.plan-next"
else
    echo "No sub-specs ready for specify. Check manifest for blockers."
    .specify/scripts/bash/manifest.sh summary "$META_SPEC_DIR"
fi
```

### Lock Contention

If another process is modifying the manifest, the lock will block. The manifest.sh script handles timeout and stale lock detection automatically.

## Guidelines

- Work within the worktree, not the main repository
- Reference the meta-spec's user-story.md for context
- Keep the sub-spec focused on its specific deliverables
- Document any cross-sub-spec dependencies discovered during specification
