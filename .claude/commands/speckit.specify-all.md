---
description: Run specify on all ready sub-specs in parallel using the Task tool.
handoffs:
  - label: Plan All Sub-Specs
    agent: speckit.plan-all
    prompt: Plan all sub-specs that are ready
---

## User Input

```text
$ARGUMENTS
```

## Purpose

This command identifies all sub-specs that are ready for specification and spawns parallel agents to specify them concurrently. It uses Claude Code's Task tool to achieve true parallelism.

## Outline

### 1. Find Meta-Spec Directory

```bash
META_SPEC_DIR=$(.specify/scripts/bash/manifest.sh find-meta-spec)
```

If no meta-spec found, inform the user to run `/speckit.specify` or `/speckit.breakdown` first.

### 2. Query Manifest for All Ready Sub-Specs

```bash
READY_IDS=$(.specify/scripts/bash/manifest.sh get-ready "$META_SPEC_DIR" "specify")
```

This returns a JSON array like `["001-parser", "002-native-adapter", "003-web-adapter"]`.

If the array is empty, check why and report appropriately.

### 3. Confirm with User

Before spawning multiple agents, confirm:

```markdown
## Ready for Parallel Specification

The following sub-specs are ready to be specified:

| ID | Title | Dependencies |
|----|-------|--------------|
| 001-parser | Parser & Sanitizer | None |
| 002-native-adapter | Native Renderer | 001-parser |
| 003-web-adapter | Web Renderer | 001-parser |

**Parallel agents to spawn**: 3

This will consume tokens for each parallel agent. Proceed?

- [Yes, specify all in parallel]
- [No, I'll use /speckit.specify-next instead]
```

### 4. Mark All as In-Progress

For each ready sub-spec:

```bash
.specify/scripts/bash/manifest.sh update-phase "$META_SPEC_DIR" "$ID" "specify" "in-progress"
```

### 5. Spawn Parallel Agents

Use the Task tool to spawn agents for each sub-spec. Each agent:
- Navigates to the appropriate worktree
- Reads the breakdown.md for its sub-spec's context
- Generates the spec.md
- Runs validation
- Updates the manifest to "complete"

**CRITICAL**: Use a single message with multiple Task tool calls to achieve true parallelism.

Example Task prompts:

```
For sub-spec 001-parser:
"You are specifying sub-spec 001-parser in the iris-ornament project.

1. Navigate to worktree: ../iris-ornament-worktrees/001-html-renderer-001-parser
2. Read context from: specs/001-html-renderer/breakdown.md (section for 001-parser)
3. Read constitution: .specify/docs/CONSTITUTION-REFERENCE.md
4. Generate spec.md at: specs/001-html-renderer/001-parser/spec.md
5. Run validation and iterate until passing
6. Update manifest: .specify/scripts/bash/manifest.sh update-phase specs/001-html-renderer 001-parser specify complete

Report when complete with a summary of the specification."
```

### 6. Monitor Agent Completion

As agents complete, collect their results. Each agent should report:
- Sub-spec ID
- Spec file path
- Validation status
- Any issues encountered

### 7. Update Manifest Summary

After all agents complete:

```bash
.specify/scripts/bash/manifest.sh summary "$META_SPEC_DIR"
```

### 8. Report Results

```markdown
## Parallel Specification Complete

**Sub-Specs Specified**: 3 of 3

| ID | Status | Spec File |
|----|--------|-----------|
| 001-parser | Complete | specs/001-html-renderer/001-parser/spec.md |
| 002-native-adapter | Complete | specs/001-html-renderer/002-native-adapter/spec.md |
| 003-web-adapter | Complete | specs/001-html-renderer/003-web-adapter/spec.md |

### Next Steps
- Run `/speckit.plan-all` to plan all specified sub-specs in parallel
- Run `/speckit.plan-next` to plan one at a time
```

## Error Handling

### Agent Failure

If an agent fails:
1. Leave the sub-spec as "in-progress" in the manifest
2. Report the failure with error details
3. Suggest running `/speckit.specify-next` for that specific sub-spec

### Partial Completion

If some agents succeed and others fail:
1. Update successful sub-specs to "complete"
2. Leave failed sub-specs as "in-progress"
3. Report mixed results with next steps for each

## Guidelines

### Task Tool Usage

When spawning agents:
- Use `subagent_type: "general-purpose"` for specification work
- Provide complete context in the prompt (don't rely on conversation history)
- Include explicit file paths and commands
- Request structured completion reports

### Parallelism Considerations

- All sub-specs at the same dependency level can be specified in parallel
- Sub-specs with unmet dependencies will not appear in the "ready" list
- The manifest lock prevents race conditions during updates

### Token Efficiency

Parallel agents consume tokens independently. For cost-sensitive situations:
- Use `/speckit.specify-next` for sequential processing
- Limit parallelism to sub-specs that truly benefit from concurrent work
