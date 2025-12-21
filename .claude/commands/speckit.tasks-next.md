---
description: Generate tasks for the next sub-spec that has completed planning.
handoffs:
  - label: Schedule Implementation
    agent: speckit.schedule
    prompt: Schedule the implementation order for all sub-specs
---

## User Input

```text
$ARGUMENTS
```

## Purpose

This command finds the next sub-spec that has completed planning and generates its task list.

## Outline

### 1. Find Meta-Spec Directory

```bash
META_SPEC_DIR=$(.specify/scripts/bash/manifest.sh find-meta-spec)
```

### 2. Query Manifest for Next Sub-Spec Ready for Tasks

```bash
NEXT_ID=$(.specify/scripts/bash/manifest.sh get-next "$META_SPEC_DIR" "tasks")
```

If empty, check status and report accordingly.

### 3. Update Manifest to In-Progress

```bash
.specify/scripts/bash/manifest.sh update-phase "$META_SPEC_DIR" "$NEXT_ID" "tasks" "in-progress"
```

### 4. Read Task Generation Context

Read:
- `$META_SPEC_DIR/$NEXT_ID/spec.md` - Requirements
- `$META_SPEC_DIR/$NEXT_ID/plan.md` - Design decisions
- `$META_SPEC_DIR/$NEXT_ID/research.md` - Research findings (if exists)
- `$META_SPEC_DIR/$NEXT_ID/data-model.md` - Data structures (if exists)
- `.specify/templates/tasks-template.md` - Task structure

### 5. Generate Task List

Create `$META_SPEC_DIR/$NEXT_ID/tasks.md` following the template:

1. **Phase 1: Setup** - Project initialization for this sub-spec
2. **Phase 2: Foundational** - Core infrastructure
3. **Phase 3+: User Stories** - Implementation by user story
4. **Final Phase: Polish** - Testing, documentation

**Sub-Spec Specific Considerations**:
- Mark tasks that depend on other sub-specs with `[BLOCKED: sub-spec-id]`
- These blocks will be resolved during `/speckit.schedule`
- Tasks within the sub-spec can still use `[P]` for parallelism

### 6. Update Manifest to Complete

```bash
.specify/scripts/bash/manifest.sh update-phase "$META_SPEC_DIR" "$NEXT_ID" "tasks" "complete"
```

### 7. Report Results and Check for Schedule Readiness

```bash
ALL_TASKS_COMPLETE=$(.specify/scripts/bash/manifest.sh all-complete "$META_SPEC_DIR" "tasks")
```

```markdown
## Tasks Generated

**Sub-Spec**: [ID] - [Title]
**Tasks File**: specs/[meta-spec-id]/[sub-spec-id]/tasks.md
**Task Count**: X tasks

### Progress
- Tasks complete: X of Y sub-specs

### Next Steps
```

If all tasks are complete:
```markdown
**All sub-specs have tasks generated!**

You MUST now run `/speckit.schedule` to:
1. Analyze cross-sub-spec dependencies
2. Generate the implementation execution order
3. Unblock the implement phase

This is a required human-in-the-loop step before implementation can begin.
```

Otherwise:
```markdown
- Run `/speckit.tasks-next` to generate tasks for another sub-spec
- Run `/speckit.tasks-all` to generate remaining tasks in parallel
```

## Guidelines

### Task Granularity

For sub-specs that are part of a larger meta-spec:
- Keep tasks focused on this sub-spec's scope
- Reference interfaces from other sub-specs, don't implement them
- Mark integration points clearly

### Dependency Markers

Use these markers in tasks:
- `[P]` - Can run in parallel with other `[P]` tasks in same phase
- `[BLOCKED: 001-parser]` - Requires sub-spec 001-parser to be complete
- `[INTEGRATION]` - Task that integrates with other sub-specs

These markers inform `/speckit.schedule` about execution order.
