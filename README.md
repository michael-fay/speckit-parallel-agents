# Speckit Parallel Agents Template

A speckit template extension that enables parallel agent development through meta-specs, sub-specs, and git worktrees.

## Features

- **Meta-Spec / Sub-Spec Hierarchy**: Decompose complex user stories into independent sub-specs
- **Git Worktrees**: Each sub-spec gets its own worktree for true parallel development
- **Manifest-Driven State**: JSON manifest tracks phase completion with atomic locking
- **Dependency Graph**: Sub-specs can declare dependencies for ordered execution
- **Human Gates**: Required `/speckit.schedule` approval before implementation

## Installation

### Option 1: Initialize with base speckit, then overlay

```bash
# Initialize a new project with speckit
specify init my-project --ai claude
cd my-project

# Clone this template and copy files
git clone https://github.com/michael-fay/speckit-parallel-agents /tmp/spa
cp -r /tmp/spa/.specify/* .specify/
cp -r /tmp/spa/.claude/* .claude/
rm -rf /tmp/spa
```

### Option 2: Use as git template

```bash
# Clone directly as your project base
git clone https://github.com/michael-fay/speckit-parallel-agents my-project
cd my-project
rm -rf .git
git init
```

## Workflow

### Simple Feature (Standard Speckit)

For single-scope features, use standard workflow:

```
/speckit.specify → /speckit.plan → /speckit.tasks → /speckit.implement
```

### Complex Feature (Parallel Agents)

For features requiring parallel development:

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
/speckit.tasks-all      → Parallel: generate all task lists
   or -next             → Sequential: one at a time
        ↓
/speckit.schedule       → REQUIRED: Human approves execution order
        ↓
/speckit.implement-next → Implements according to schedule
```

## Directory Structure

```
my-project/
├── specs/
│   └── 001-feature/                    # Meta-spec directory
│       ├── user-story.md               # High-level user story
│       ├── breakdown.md                # Sub-spec decomposition
│       ├── manifest.json               # State tracking
│       ├── schedule.md                 # Execution schedule
│       │
│       ├── 001-parser/                 # Sub-spec
│       │   ├── spec.md
│       │   ├── plan.md
│       │   └── tasks.md
│       ├── 002-adapter/                # Sub-spec (depends on 001)
│       └── 003-integration/            # Sub-spec (parallel with 002)

my-project-worktrees/                   # Worktree container (sibling dir)
├── 001-feature-001-parser/             # Sub-spec worktree
├── 001-feature-002-adapter/
└── 001-feature-003-integration/
```

## Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Simple feature | `###-name` | `001-html-parser` |
| Meta-spec | `###-name` | `001-html-renderer` |
| Sub-spec | `###-meta-###-sub` | `001-html-renderer-001-parser` |

## Scripts

| Script | Purpose |
|--------|---------|
| `manifest.sh` | Manifest CRUD with atomic locking |
| `create-sub-spec.sh` | Create sub-spec + branch + worktree |
| `worktree-create.sh` | Create a worktree |
| `worktree-list.sh` | List active worktrees |
| `worktree-remove.sh` | Remove a worktree |
| `worktree-sync.sh` | Sync worktree with main |

## Phase Rules

| Phase | Can Start When | Parallel? |
|-------|----------------|-----------|
| specify | breakdown complete | Yes (via -all) |
| plan | own specify complete | Yes (via -all) |
| tasks | own plan complete | Yes (via -all) |
| schedule | ALL tasks complete | No (human gate) |
| implement | schedule + deps complete | Per schedule |

## Agent Isolation

When working in a worktree:

1. **Stay in your worktree** - Never modify files outside your directory
2. **Reference specs from meta-spec** - Read `specs/<meta-spec>/<sub-spec>/`
3. **Commit frequently** - Make atomic commits for each logical change
4. **Push regularly** - Push to remote to prevent work loss
5. **Update manifest** - Mark phases complete when done

## License

MIT
