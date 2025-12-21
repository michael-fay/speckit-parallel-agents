---
description: Generate tasks for all sub-specs that have completed planning in parallel.
handoffs:
  - label: Schedule Implementation
    agent: speckit.schedule
    prompt: Schedule the implementation order
---

## User Input

```text
$ARGUMENTS
```

## Purpose

This command identifies all sub-specs that have completed planning and spawns parallel agents to generate their task lists concurrently.

## Outline

### 1. Find Meta-Spec Directory

```bash
META_SPEC_DIR=$(.specify/scripts/bash/manifest.sh find-meta-spec)
```

### 2. Query Manifest for All Ready Sub-Specs

```bash
READY_IDS=$(.specify/scripts/bash/manifest.sh get-ready "$META_SPEC_DIR" "tasks")
```

### 3. Confirm with User

Display ready sub-specs and confirm parallel execution.

### 4. Spawn Parallel Agents

Use Task tool with multiple calls to generate tasks for each sub-spec concurrently.

### 5. Collect Results and Check Schedule Readiness

After all complete:

```bash
ALL_TASKS_COMPLETE=$(.specify/scripts/bash/manifest.sh all-complete "$META_SPEC_DIR" "tasks")
```

### 6. Report Results

```markdown
## Parallel Task Generation Complete

**Sub-Specs with Tasks**: X of Y

| ID | Tasks Count | Status |
|----|-------------|--------|
| 001-parser | 15 | Complete |
| 002-native-adapter | 20 | Complete |

### Schedule Requirement

All sub-specs now have tasks. Before implementation can begin, you MUST run:

```
/speckit.schedule
```

This human-in-the-loop step:
1. Analyzes cross-sub-spec dependencies
2. Determines optimal execution order
3. Identifies parallelization opportunities
4. Unblocks the implement phase
```

## Guidelines

Same as `/speckit.tasks-next`, but for parallel execution.
