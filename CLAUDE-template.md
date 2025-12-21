# [Project Name]

## Project Overview

**Codename**: [project-codename]
**See**: `README.md` for full project brief

## Core Principles

### Test-Driven Development (NON-NEGOTIABLE)
- Write tests BEFORE implementation code
- Verify RED state (test fails) before writing implementation
- Write minimum viable code to pass each test
- Tests must verify behavior, not implementation details

### Quality Gates (NON-NEGOTIABLE)
- All code MUST pass linting and type checks
- **NEVER use**: `// eslint-disable`, `@ts-ignore`, `@ts-expect-error`
- Fix problems, don't bypass them with disable comments

### Code Style
- TypeScript strict mode enabled
- Self-documenting code through clear naming
- Comments ONLY for complex algorithms or non-obvious business logic
- NO comments that restate what code does

## Technology Stack

- **Language**: [Primary language]
- **Runtime**: [Runtime/Framework]
- **Testing**: [Test framework]

## Spec-Driven Development Workflow

This project uses **speckit** for spec-driven development with **parallel agent support**.

### Simple Feature Workflow

For simple features (single spec, single developer):

1. `/speckit.constitution` - Establish project principles (once per project)
2. `/speckit.specify` - Create feature specification
3. `/speckit.clarify` - (optional) Ask clarifying questions
4. `/speckit.plan` - Create technical implementation plan
5. `/speckit.tasks` - Generate actionable task list
6. `/speckit.analyze` - (optional) Cross-artifact validation
7. `/speckit.implement` - Execute implementation

### Complex Feature Workflow (Meta-Spec with Sub-Specs)

For complex features requiring parallel development:

```
/speckit.specify        → Detects complexity, asks about breakdown
        ↓
/speckit.breakdown      → Creates sub-specs + worktrees + manifest
        ↓
/speckit.specify-all    → Parallel: specify all sub-specs
   or -next             → Sequential: one at a time
        ↓
/speckit.plan-all       → Parallel: plan all sub-specs
   or -next             → Sequential: one at a time
        ↓
/speckit.tasks-all      → Parallel: generate all sub-specs
   or -next             → Sequential: one at a time
        ↓
/speckit.schedule       → REQUIRED: Human approves execution order
        ↓
/speckit.implement-next → Implements according to schedule
```

### Feature Branch Pattern

- **Simple features**: `###-feature-name` (e.g., `001-html-parser`)
- **Meta-spec (complex)**: `###-feature-name` (e.g., `001-html-renderer`)
- **Sub-specs**: `###-feature-name-###-sub-spec` (e.g., `001-html-renderer-001-parser`)

## Meta-Spec Architecture

Complex features are decomposed into sub-specs with explicit dependencies.

### Directory Structure

```
[project]/
├── specs/
│   └── 001-feature/                    # Meta-spec directory
│       ├── user-story.md               # High-level user story
│       ├── breakdown.md                # Sub-spec decomposition
│       ├── manifest.json               # State tracking
│       ├── schedule.md                 # Execution schedule
│       │
│       ├── 001-component/              # Sub-spec
│       │   ├── spec.md
│       │   ├── plan.md
│       │   └── tasks.md
│       └── 002-integration/            # Sub-spec (depends on 001)

[project]-worktrees/                    # Worktree container
├── 001-feature-001-component/          # Sub-spec worktree
└── 001-feature-002-integration/
```

### Phase Rules

| Phase | Can Start When | Parallel? |
|-------|----------------|-----------|
| specify | breakdown complete | Yes (via -all) |
| plan | own specify complete | Yes (via -all) |
| tasks | own plan complete | Yes (via -all) |
| schedule | ALL tasks complete | No (human gate) |
| implement | schedule + deps complete | Per schedule |

### Manifest & Lock

- **Manifest**: `specs/<meta-spec>/manifest.json` tracks all sub-spec state
- **Lock**: Atomic locking prevents race conditions during parallel updates
- **Scripts**: `.specify/scripts/bash/manifest.sh` provides CLI for manifest ops

## Worktree Commands

| Command | Description |
|---------|-------------|
| `.specify/scripts/bash/worktree-create.sh <branch>` | Create a worktree |
| `.specify/scripts/bash/worktree-list.sh` | List active worktrees |
| `.specify/scripts/bash/worktree-remove.sh <branch>` | Remove a worktree |
| `.specify/scripts/bash/worktree-sync.sh` | Sync with main |
| `.specify/scripts/bash/manifest.sh summary <dir>` | Show manifest status |

### Agent Isolation Rules

When working in a worktree:
1. **Stay in your worktree** - Never modify files outside your directory
2. **Reference specs from meta-spec** - Read `specs/<meta-spec>/<sub-spec>/`
3. **Commit frequently** - Make atomic commits for each logical change
4. **Push regularly** - Push to remote to prevent work loss
5. **Update manifest** - Mark phases complete when done

See `.specify/docs/WORKTREES.md` for full documentation.

## Project Constraints

[Add project-specific constraints here]

## Out of Scope

[Add out-of-scope items here]
