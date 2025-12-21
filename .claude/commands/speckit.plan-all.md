---
description: Run plan on all sub-specs that are ready for planning in parallel.
handoffs:
  - label: Generate All Tasks
    agent: speckit.tasks-all
    prompt: Generate tasks for all planned sub-specs
---

## User Input

```text
$ARGUMENTS
```

## Purpose

This command identifies all sub-specs that have completed specification and spawns parallel agents to plan them concurrently.

## Outline

### 1. Find Meta-Spec Directory

```bash
META_SPEC_DIR=$(.specify/scripts/bash/manifest.sh find-meta-spec)
```

### 2. Query Manifest for All Ready Sub-Specs

```bash
READY_IDS=$(.specify/scripts/bash/manifest.sh get-ready "$META_SPEC_DIR" "plan")
```

### 3. Confirm with User

```markdown
## Ready for Parallel Planning

The following sub-specs are ready to be planned:

| ID | Title | Spec Complete |
|----|-------|---------------|
| 001-parser | Parser & Sanitizer | Yes |
| 002-native-adapter | Native Renderer | Yes |

**Parallel agents to spawn**: 2

Proceed with parallel planning?
```

### 4. Mark All as In-Progress

```bash
for ID in $READY_IDS; do
    .specify/scripts/bash/manifest.sh update-phase "$META_SPEC_DIR" "$ID" "plan" "in-progress"
done
```

### 5. Spawn Parallel Agents

Use the Task tool with multiple calls in a single message:

```
For sub-spec 001-parser:
"You are planning sub-spec 001-parser in the iris-ornament project.

1. Navigate to worktree: ../iris-ornament-worktrees/001-html-renderer-001-parser
2. Read spec: specs/001-html-renderer/001-parser/spec.md
3. Read constitution: .specify/docs/CONSTITUTION-REFERENCE.md
4. Read plan template: .specify/templates/plan-template.md
5. Generate plan.md at: specs/001-html-renderer/001-parser/plan.md
6. Create research.md if research needed
7. Update manifest: .specify/scripts/bash/manifest.sh update-phase specs/001-html-renderer 001-parser plan complete

Report when complete."
```

### 6. Collect Results and Report

```markdown
## Parallel Planning Complete

**Sub-Specs Planned**: X of Y

| ID | Status | Plan File |
|----|--------|-----------|
| 001-parser | Complete | specs/.../001-parser/plan.md |
| 002-native-adapter | Complete | specs/.../002-native-adapter/plan.md |

### Next Steps
- Run `/speckit.tasks-all` to generate tasks for all planned sub-specs
- Run `/speckit.tasks-next` to generate tasks one at a time
```

## Guidelines

Same as `/speckit.plan-next`, but for parallel execution.

Note: Planning can safely run in parallel because each sub-spec plans within its own worktree and directory.
