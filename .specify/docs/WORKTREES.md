# Git Worktree Workflow for Parallel Agent Development

## Overview

This project uses **git worktrees** to enable parallel development by multiple AI agents. Each agent works in an isolated worktree with its own feature branch, preventing conflicts while sharing the same git repository.

## Concept

```
iris-ornament/                    # Main worktree (main branch)
├── .specify/
│   └── specs/                    # All feature specifications live here
│       ├── 001-html-parser/
│       ├── 002-native-adapter/
│       └── 003-web-adapter/
└── src/                          # Shared codebase

iris-ornament-worktrees/          # Worktree container (sibling directory)
├── 001-html-parser/              # Agent 1's worktree
│   └── (full repo checkout on 001-html-parser branch)
├── 002-native-adapter/           # Agent 2's worktree
│   └── (full repo checkout on 002-native-adapter branch)
└── 003-web-adapter/              # Agent 3's worktree
    └── (full repo checkout on 003-web-adapter branch)
```

## Why Worktrees?

1. **Parallel Work**: Multiple agents can work simultaneously without stepping on each other
2. **Shared History**: All worktrees share the same git repository and history
3. **Efficient Storage**: Git uses hardlinks, so disk usage is minimal
4. **Spec Isolation**: Each worktree has its own branch for feature implementation
5. **Easy Integration**: Standard git merge/rebase workflow for combining work

## Workflow

### 1. Create a Feature Specification (Main Worktree)

All specifications are created and edited in the main worktree:

```bash
cd iris-ornament
.specify/scripts/bash/create-new-feature.sh "Implement HTML parser"
# Creates: specs/001-html-parser/spec.md
# Creates branch: 001-html-parser
```

### 2. Create a Worktree for Implementation

When ready to implement, create a worktree:

```bash
.specify/scripts/bash/worktree-create.sh 001-html-parser
# Creates: ../iris-ornament-worktrees/001-html-parser/
```

### 3. Assign Agent to Worktree

Launch an AI agent session in the worktree directory:

```bash
cd ../iris-ornament-worktrees/001-html-parser
claude  # or your preferred AI agent
```

### 4. Agent Works on Implementation

The agent:
- Reads the spec from `specs/001-html-parser/spec.md`
- Implements code in `src/`
- Commits changes to the `001-html-parser` branch
- Pushes to remote for backup

### 5. Merge Completed Work

When implementation is complete:

```bash
cd iris-ornament  # Return to main worktree
git checkout main
git merge 001-html-parser
.specify/scripts/bash/worktree-remove.sh 001-html-parser
```

## Commands

| Command | Description |
|---------|-------------|
| `worktree-create.sh <branch>` | Create a new worktree for a feature branch |
| `worktree-list.sh` | List all active worktrees |
| `worktree-remove.sh <branch>` | Remove a worktree (keeps the branch) |
| `worktree-sync.sh` | Pull latest changes into all worktrees |

## Best Practices

### For Spec Authors

1. **Complete specs before creating worktrees**: Ensure `spec.md`, `plan.md`, and `tasks.md` are finalized
2. **Use the main worktree for spec edits**: Never edit specs from a feature worktree
3. **Coordinate merges**: Merge features in dependency order (per `tasks.md`)

### For AI Agents

1. **Stay in your worktree**: Never modify files outside your worktree directory
2. **Commit frequently**: Make atomic commits for each logical change
3. **Push regularly**: Push to remote to prevent work loss
4. **Follow the spec**: Reference `specs/<feature>/` for requirements
5. **Check for conflicts**: Before starting, pull the latest from main

### Parallel Execution Strategy

Based on the task template's parallel markers `[P]`:

```
Phase 1: Setup (Main Worktree)
├── T001 Create project structure
└── T002 Initialize dependencies

Phase 2: Parallel Implementation (Separate Worktrees)
├── Agent 1: 001-html-parser worktree
│   ├── T010 Parser implementation
│   └── T011 Parser tests
├── Agent 2: 002-native-adapter worktree
│   ├── T020 Native adapter
│   └── T021 Native tests
└── Agent 3: 003-web-adapter worktree
    ├── T030 Web adapter
    └── T031 Web tests

Phase 3: Integration (Main Worktree)
├── Merge 001-html-parser
├── Merge 002-native-adapter
├── Merge 003-web-adapter
└── T099 Integration tests
```

## Conflict Resolution

If branches have conflicting changes:

1. **In main worktree**, merge the first branch:
   ```bash
   git checkout main
   git merge 001-html-parser
   ```

2. **Update other worktrees** with the merged changes:
   ```bash
   cd ../iris-ornament-worktrees/002-native-adapter
   git fetch origin
   git rebase origin/main
   ```

3. **Continue with remaining merges**

## Troubleshooting

### "fatal: 'X' is already checked out at 'Y'"

A branch can only be checked out in one worktree. Either:
- Remove the existing worktree first
- Use a different branch name

### Worktree shows outdated files

```bash
cd <worktree>
git fetch origin
git pull origin main
```

### Lost track of worktrees

```bash
git worktree list
# Shows all worktrees and their branches
```
