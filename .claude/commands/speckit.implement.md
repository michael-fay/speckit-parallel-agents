---
description: Execute the implementation plan by processing and executing all tasks defined in tasks.md (project)
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Argument Parsing:**
- `--feature <name>`: Specify feature/meta-spec name directly (allows running from main branch)
- `--sub-spec <id>`: Implement a specific sub-spec (requires --feature)
- No arguments: Use branch-based detection (original behavior)

## Sub-Spec/Worktree Mode

**IMPORTANT**: When working in a meta-spec context with worktrees:

1. **This command MUST be run from a worktree**, not the meta-spec branch
2. If you're on the meta-spec branch (e.g., `001-feature`), use `/speckit.implement-next` instead
3. When run from a sub-spec worktree (e.g., `001-feature-001-parser`):
   - The command auto-detects the sub-spec context
   - If implementation is already `in-progress` for this sub-spec, it **resumes** automatically
   - No `--feature` or `--sub-spec` flags needed - context is derived from branch name

### Auto-Resume Behavior

When running from a worktree with `implement: in-progress` in the manifest:
1. Skip the "mark as in-progress" step (already done)
2. Load the tasks.md and find uncompleted tasks (those not marked `[X]`)
3. Resume implementation from the first uncompleted task
4. Continue with the normal implementation flow

## Outline

### 0. Detect Context and Validate Location

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
```

**Check if on a sub-spec branch** (pattern: `###-meta-###-sub`):
- If yes: Auto-detect META_SPEC_DIR and SUB_SPEC_ID from branch name
- If no (on meta-spec or main branch): **ERROR** - Display message:
  ```
  Error: /speckit.implement must be run from a sub-spec worktree.

  You are on branch: [branch name]

  Options:
  1. Use /speckit.implement-next to start the next scheduled sub-spec
  2. Navigate to an existing worktree: cd ../<project>-worktrees/[sub-spec]
  3. Use explicit flags: /speckit.implement --feature [name] --sub-spec [id]
  ```

**If auto-detected sub-spec, check manifest for current state**:
```bash
IMPL_STATUS=$(cat "$META_SPEC_DIR/manifest.json" | jq -r ".subSpecs[] | select(.id == \"$SUB_SPEC_ID\") | .phases.implement")
```

- If `in-progress`: **RESUME MODE** - Note this and continue to check-prerequisites
- If `complete`: **ERROR** - "Implementation already complete for this sub-spec"
- If `blocked` or `pending`: Check if ready (deps complete), then mark as in-progress using the manifest update protocol

### Manifest Update Protocol

When updating manifest state (marking as in-progress or complete), use the atomic manifest update script:

```bash
.specify/scripts/bash/manifest-update.sh "$META_SPEC_DIR" update-phase "$SUB_SPEC_ID" "implement" "in-progress"
```

This script follows the **worktree→remote→meta-spec protocol**:
1. Acquires file lock to prevent race conditions
2. Updates the manifest in the current worktree
3. Commits with standardized message
4. Pushes to the **worktree's remote branch** first
5. Merges the worktree branch into the **meta-spec branch** (in main worktree)
6. Pushes the meta-spec branch to remote
7. Releases lock

This ensures manifest changes flow: worktree → remote → meta-spec branch, keeping all worktrees and the meta-spec branch in sync.

### 1. Run Prerequisites Check

Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root, adding `--feature <name>` and/or `--sub-spec <id>` flags if provided in arguments. Parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

### 2. Check Checklists Status (if FEATURE_DIR/checklists/ exists)
   - Scan all checklist files in the checklists/ directory
   - For each checklist, count:
     - Total items: All lines matching `- [ ]` or `- [X]` or `- [x]`
     - Completed items: Lines matching `- [X]` or `- [x]`
     - Incomplete items: Lines matching `- [ ]`
   - Create a status table:

     ```text
     | Checklist | Total | Completed | Incomplete | Status |
     |-----------|-------|-----------|------------|--------|
     | ux.md     | 12    | 12        | 0          | ✓ PASS |
     | test.md   | 8     | 5         | 3          | ✗ FAIL |
     | security.md | 6   | 6         | 0          | ✓ PASS |
     ```

   - Calculate overall status:
     - **PASS**: All checklists have 0 incomplete items
     - **FAIL**: One or more checklists have incomplete items

   - **If any checklist is incomplete**:
     - Display the table with incomplete item counts
     - **STOP** and ask: "Some checklists are incomplete. Do you want to proceed with implementation anyway? (yes/no)"
     - Wait for user response before continuing
     - If user says "no" or "wait" or "stop", halt execution
     - If user says "yes" or "proceed" or "continue", proceed to step 3

   - **If all checklists are complete**:
     - Display the table showing all checklists passed
     - Automatically proceed to step 3

3. Load and analyze the implementation context:
   - **REQUIRED**: Read tasks.md for the complete task list and execution plan
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure
   - **IF EXISTS**: Read data-model.md for entities and relationships
   - **IF EXISTS**: Read contracts/ for API specifications and test requirements
   - **IF EXISTS**: Read research.md for technical decisions and constraints
   - **IF EXISTS**: Read quickstart.md for integration scenarios

4. **Project Setup Verification**:
   - **REQUIRED**: Create/verify ignore files based on actual project setup:

   **Detection & Creation Logic**:
   - Check if the following command succeeds to determine if the repository is a git repo (create/verify .gitignore if so):

     ```sh
     git rev-parse --git-dir 2>/dev/null
     ```

   - Check if Dockerfile* exists or Docker in plan.md → create/verify .dockerignore
   - Check if .eslintrc* exists → create/verify .eslintignore
   - Check if eslint.config.* exists → ensure the config's `ignores` entries cover required patterns
   - Check if .prettierrc* exists → create/verify .prettierignore
   - Check if .npmrc or package.json exists → create/verify .npmignore (if publishing)
   - Check if terraform files (*.tf) exist → create/verify .terraformignore
   - Check if .helmignore needed (helm charts present) → create/verify .helmignore

   **If ignore file already exists**: Verify it contains essential patterns, append missing critical patterns only
   **If ignore file missing**: Create with full pattern set for detected technology

   **Common Patterns by Technology** (from plan.md tech stack):
   - **Node.js/JavaScript/TypeScript**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
   - **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `*.egg-info/`
   - **Java**: `target/`, `*.class`, `*.jar`, `.gradle/`, `build/`
   - **C#/.NET**: `bin/`, `obj/`, `*.user`, `*.suo`, `packages/`
   - **Go**: `*.exe`, `*.test`, `vendor/`, `*.out`
   - **Ruby**: `.bundle/`, `log/`, `tmp/`, `*.gem`, `vendor/bundle/`
   - **PHP**: `vendor/`, `*.log`, `*.cache`, `*.env`
   - **Rust**: `target/`, `debug/`, `release/`, `*.rs.bk`, `*.rlib`, `*.prof*`, `.idea/`, `*.log`, `.env*`
   - **Kotlin**: `build/`, `out/`, `.gradle/`, `.idea/`, `*.class`, `*.jar`, `*.iml`, `*.log`, `.env*`
   - **C++**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.so`, `*.a`, `*.exe`, `*.dll`, `.idea/`, `*.log`, `.env*`
   - **C**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.a`, `*.so`, `*.exe`, `Makefile`, `config.log`, `.idea/`, `*.log`, `.env*`
   - **Swift**: `.build/`, `DerivedData/`, `*.swiftpm/`, `Packages/`
   - **R**: `.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata`, `*.Rproj`, `packrat/`, `renv/`
   - **Universal**: `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, `.vscode/`, `.idea/`

   **Tool-Specific Patterns**:
   - **Docker**: `node_modules/`, `.git/`, `Dockerfile*`, `.dockerignore`, `*.log*`, `.env*`, `coverage/`
   - **ESLint**: `node_modules/`, `dist/`, `build/`, `coverage/`, `*.min.js`
   - **Prettier**: `node_modules/`, `dist/`, `build/`, `coverage/`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
   - **Terraform**: `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`
   - **Kubernetes/k8s**: `*.secret.yaml`, `secrets/`, `.kube/`, `kubeconfig*`, `*.key`, `*.crt`

5. Parse tasks.md structure and extract:
   - **Task phases**: Setup, Tests, Core, Integration, Polish
   - **Task dependencies**: Sequential vs parallel execution rules
   - **Task details**: ID, description, file paths, parallel markers [P]
   - **Execution flow**: Order and dependency requirements

6. Execute implementation following the task plan:
   - **Phase-by-phase execution**: Complete each phase before moving to the next
   - **Respect dependencies**: Run sequential tasks in order, parallel tasks [P] can run together  
   - **Follow TDD approach**: Execute test tasks before their corresponding implementation tasks
   - **File-based coordination**: Tasks affecting the same files must run sequentially
   - **Validation checkpoints**: Verify each phase completion before proceeding

7. Implementation execution rules:
   - **Setup first**: Initialize project structure, dependencies, configuration
   - **Tests before code**: If you need to write tests for contracts, entities, and integration scenarios
   - **Core development**: Implement models, services, CLI commands, endpoints
   - **Integration work**: Database connections, middleware, logging, external services
   - **Polish and validation**: Unit tests, performance optimization, documentation

8. Progress tracking and error handling:
   - Report progress after each completed task
   - Halt execution if any non-parallel task fails
   - For parallel tasks [P], continue with successful tasks, report failed ones
   - Provide clear error messages with context for debugging
   - Suggest next steps if implementation cannot proceed
   - **IMPORTANT** For completed tasks, make sure to mark the task off as [X] in the tasks file.

9. Completion validation:
   - Verify all required tasks are completed
   - Check that implemented features match the original specification
   - Validate that tests pass and coverage meets requirements
   - Confirm the implementation follows the technical plan
   - Report final status with summary of completed work

10. Mark Implementation Complete:
    - After all tasks pass and quality checks succeed, update the manifest:
      ```bash
      .specify/scripts/bash/manifest-update.sh "$META_SPEC_DIR" update-phase "$SUB_SPEC_ID" "implement" "complete"
      ```
    - This follows the worktree→remote→meta-spec protocol to sync all branches
    - The update will automatically unblock dependent sub-specs

Note: This command assumes a complete task breakdown exists in tasks.md. If tasks are incomplete or missing, suggest running `/speckit.tasks` first to regenerate the task list.
