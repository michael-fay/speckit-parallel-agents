---
description: Break down a complex user story into parallelizable sub-specs with dependency tracking.
handoffs:
  - label: Specify All Sub-Specs
    agent: speckit.specify-all
    prompt: Run specify on all sub-specs in parallel
  - label: Specify Next Sub-Spec
    agent: speckit.specify-next
    prompt: Run specify on the next available sub-spec
---

## User Input

```text
$ARGUMENTS
```

## Purpose

This command analyzes a complex user story (meta-spec) and decomposes it into smaller, independently implementable sub-specs. Each sub-spec:
- Has its own spec.md, plan.md, and tasks.md
- Gets its own git worktree for parallel development
- Has explicit dependencies on other sub-specs

## Prerequisites

Before running this command:
1. You must be on a feature branch with a user-story.md file
2. The user-story.md should describe a complex feature that benefits from decomposition

## Outline

### 1. Locate the Meta-Spec

```bash
# Find the current feature directory
FEATURE_DIR=$(find specs -maxdepth 1 -type d -name "[0-9]*" | head -1)
META_SPEC_ID=$(basename "$FEATURE_DIR")
```

If no feature directory exists, prompt the user to run `/speckit.specify` first.

### 2. Read the User Story

Read `$FEATURE_DIR/user-story.md` to understand:
- Overall feature scope and goals
- Key user scenarios
- Success criteria
- Constraints and dependencies

Also read:
- `.specify/docs/CONSTITUTION-REFERENCE.md` for project principles
- `.specify/docs/PROJECT-STRUCTURE.md` for existing breakdown guidance (if available)

### 3. Analyze for Decomposition

Identify natural boundaries for sub-specs based on:

**Architectural Boundaries**:
- Core/Foundation components (parsers, data models, shared utilities)
- Platform adapters (native, web, mobile-specific code)
- Feature modules (distinct user-facing capabilities)
- Integration layers (APIs, external services)

**Dependency Analysis**:
- Which components MUST exist before others can be built?
- Which components can be built in parallel?
- Are there circular dependencies to resolve?

**Parallelization Opportunities**:
- Independent feature slices
- Platform-specific implementations of same interface
- Test infrastructure vs implementation

### 4. Generate Breakdown Document

Create `$FEATURE_DIR/breakdown.md`:

```markdown
# Breakdown: [Meta-Spec Title]

**Meta-Spec**: [ID]
**Created**: [DATE]
**Status**: Draft

## Decomposition Strategy

[Explain the reasoning behind how this was decomposed]

## Sub-Spec Summary

| ID | Title | Dependencies | Parallelizable With |
|----|-------|--------------|---------------------|
| 001-parser | Parser & Sanitizer | None | - |
| 002-native-adapter | Native Renderer | 001 | 003 |
| 003-web-adapter | Web Renderer | 001 | 002 |
| 004-core-component | Core Component | 002, 003 | - |

## Dependency Graph

```
001-parser
├── 002-native-adapter ──┐
└── 003-web-adapter ─────┴── 004-core-component
```

## Sub-Specs

### 001-parser: Parser & Sanitizer

**Scope**: [Brief description]

**Deliverables**:
- [List key outputs]

**Dependencies**: None

**Success Criteria**:
- [List measurable criteria]

---

### 002-native-adapter: Native Renderer

**Scope**: [Brief description]

**Deliverables**:
- [List key outputs]

**Dependencies**: 001-parser

**Success Criteria**:
- [List measurable criteria]

---

[Continue for all sub-specs...]

## Execution Order

### Phase 1: Foundation (Sequential)
- 001-parser

### Phase 2: Parallel Development
- 002-native-adapter (can start when 001 complete)
- 003-web-adapter (can start when 001 complete)

### Phase 3: Integration
- 004-core-component (requires 002 + 003)

## Notes

[Any additional context, risks, or considerations]
```

### 5. Initialize Manifest

Run the manifest initialization:

```bash
.specify/scripts/bash/manifest.sh init "$FEATURE_DIR" "[User Story Title]"
```

### 6. Add Sub-Specs to Manifest

For each sub-spec identified:

```bash
# Example for a sub-spec with no dependencies
.specify/scripts/bash/manifest.sh add-sub-spec "$FEATURE_DIR" "001-parser" "Parser & Sanitizer" "[]"

# Example for a sub-spec with dependencies
.specify/scripts/bash/manifest.sh add-sub-spec "$FEATURE_DIR" "002-native-adapter" "Native Renderer" '["001-parser"]'
```

### 7. Create Sub-Spec Directories and Worktrees

For each sub-spec:

```bash
# Create sub-spec directory within meta-spec
mkdir -p "$FEATURE_DIR/001-parser"

# Create git branch and worktree
META_SPEC_ID=$(basename "$FEATURE_DIR")
BRANCH_NAME="${META_SPEC_ID}-001-parser"

git branch "$BRANCH_NAME" main
.specify/scripts/bash/worktree-create.sh "$BRANCH_NAME"

# Update manifest with worktree path
.specify/scripts/bash/manifest.sh update-worktree "$FEATURE_DIR" "001-parser" "../<project>-worktrees/$BRANCH_NAME"
```

### 8. Report Results

Display:
- Number of sub-specs created
- Dependency graph visualization
- Which sub-specs can be worked on in parallel
- Next steps (run `/speckit.specify-all` or `/speckit.specify-next`)

```markdown
## Breakdown Complete

**Meta-Spec**: 001-feature
**Sub-Specs Created**: 4

### Dependency Graph
```
001-parser (foundation)
├── 002-adapter-a ─┐
└── 003-adapter-b ─┴── 004-integration
```

### Parallelization
- **Phase 1**: 001-parser (sequential, foundation)
- **Phase 2**: 002-adapter-a, 003-adapter-b (parallel)
- **Phase 3**: 004-integration (sequential, integration)

### Worktrees Created
- `<project>-worktrees/001-feature-001-parser`
- `<project>-worktrees/001-feature-002-adapter-a`
- `<project>-worktrees/001-feature-003-adapter-b`
- `<project>-worktrees/001-feature-004-integration`

### Next Steps
1. Run `/speckit.specify-all` to specify all sub-specs in parallel
2. Or run `/speckit.specify-next` to specify one at a time

**Manifest**: `specs/001-feature/manifest.json`
```

## Guidelines

### Decomposition Principles

1. **Single Responsibility**: Each sub-spec should have one clear purpose
2. **Minimal Dependencies**: Prefer flatter dependency graphs
3. **Testable Boundaries**: Each sub-spec should be independently testable
4. **Clear Interfaces**: Define contracts between sub-specs

### Naming Conventions

- Sub-spec IDs: `NNN-short-name` (e.g., `001-parser`, `002-native-adapter`)
- Branch names: `<meta-spec-id>-<sub-spec-id>` (e.g., `001-feature-001-parser`)
- Directories: Match sub-spec ID exactly

### Dependency Rules

- No circular dependencies allowed
- Prefer linear or tree-shaped dependency graphs
- Identify the "foundation" sub-spec that others depend on
- Mark sub-specs that can run in parallel

### When NOT to Break Down

Some features don't need decomposition:
- Simple features that can be completed in 1-2 days
- Features with no natural architectural boundaries
- Features where parallelization adds more overhead than benefit

In these cases, proceed directly to `/speckit.plan` instead.
