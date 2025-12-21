---
description: Run plan on the next available sub-spec that has completed specification.
handoffs:
  - label: Generate Tasks
    agent: speckit.tasks-next
    prompt: Generate tasks for the next planned sub-spec
---

## User Input

```text
$ARGUMENTS
```

## Purpose

This command finds the next sub-spec that has completed specification and is ready for planning, then runs the plan workflow on it.

## Outline

### 1. Find Meta-Spec Directory

```bash
META_SPEC_DIR=$(.specify/scripts/bash/manifest.sh find-meta-spec)
```

### 2. Query Manifest for Next Sub-Spec Ready for Plan

```bash
NEXT_ID=$(.specify/scripts/bash/manifest.sh get-next "$META_SPEC_DIR" "plan")
```

If NEXT_ID is empty, determine why:

```bash
ALL_SPECIFY_COMPLETE=$(.specify/scripts/bash/manifest.sh all-complete "$META_SPEC_DIR" "specify")
ALL_PLAN_COMPLETE=$(.specify/scripts/bash/manifest.sh all-complete "$META_SPEC_DIR" "plan")

if [ "$ALL_PLAN_COMPLETE" = "true" ]; then
    echo "All sub-specs have been planned."
    echo "Next step: Run /speckit.tasks-next"
elif [ "$ALL_SPECIFY_COMPLETE" = "false" ]; then
    echo "Some sub-specs still need specification."
    echo "Run /speckit.specify-next first."
fi
```

### 3. Update Manifest to In-Progress

```bash
.specify/scripts/bash/manifest.sh update-phase "$META_SPEC_DIR" "$NEXT_ID" "plan" "in-progress"
```

### 4. Navigate to Worktree

The worktree path is stored in the manifest. Navigate there for planning work.

### 5. Read Planning Context

Read the following files:
- `$META_SPEC_DIR/$NEXT_ID/spec.md` - The sub-spec's specification
- `$META_SPEC_DIR/breakdown.md` - Overall decomposition and dependencies
- `$META_SPEC_DIR/user-story.md` - High-level context
- `.specify/docs/CONSTITUTION-REFERENCE.md` - Project principles
- `.specify/templates/plan-template.md` - Plan structure

### 6. Generate Implementation Plan

Create `$META_SPEC_DIR/$NEXT_ID/plan.md` following the plan template:

1. **Technical Context**: Based on constitution and project constraints
2. **Project Structure**: Where this sub-spec's code will live
3. **Constitution Check**: Verify alignment with principles
4. **Research Phase**: Explore codebase for relevant patterns (if needed)
5. **Design Decisions**: Document key choices

**IMPORTANT for Sub-Specs**:
- Reference shared types/interfaces from foundation sub-specs
- Note integration points with dependent sub-specs
- Document contracts between sub-specs

### 7. Create Supporting Artifacts

If needed, create:
- `$META_SPEC_DIR/$NEXT_ID/research.md` - Research findings
- `$META_SPEC_DIR/$NEXT_ID/data-model.md` - Data structures
- `$META_SPEC_DIR/$NEXT_ID/contracts/` - API contracts

### 8. Update Manifest to Complete

```bash
.specify/scripts/bash/manifest.sh update-phase "$META_SPEC_DIR" "$NEXT_ID" "plan" "complete"
```

### 9. Report Results

```markdown
## Sub-Spec Planned

**Sub-Spec**: [ID] - [Title]
**Plan File**: specs/[meta-spec-id]/[sub-spec-id]/plan.md

### Artifacts Created
- plan.md
- research.md (if created)
- data-model.md (if created)
- contracts/ (if created)

### Progress
- Planned: X of Y sub-specs
- Ready for tasks: [list IDs]

### Next Steps
- Run `/speckit.plan-next` to plan another sub-spec
- Run `/speckit.tasks-next` to generate tasks for planned sub-specs
```

## Guidelines

### Planning for Parallel Development

When planning a sub-spec that will be developed in parallel with others:
- Define clear interface boundaries
- Document shared dependencies
- Specify integration contracts
- Note merge order considerations

### Cross-Sub-Spec Considerations

- **Foundation sub-specs**: Define types and interfaces that others will use
- **Dependent sub-specs**: Reference foundation types, don't redefine
- **Parallel sub-specs**: Define how they'll integrate at merge time

### Research Scope

Research should focus on:
- Existing patterns in the codebase
- Dependencies and how to use them
- Similar implementations for reference
- NOT research for dependent sub-specs (they'll do their own)
