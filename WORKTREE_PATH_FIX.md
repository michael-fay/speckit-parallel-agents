# Worktree Spec File Location Fix

## Problem

When using the speckit parallel agents workflow with worktrees, spec files (`spec.md`, `plan.md`, `tasks.md`, `spec-checklist.md`) were being placed at the wrong directory level, causing merge conflicts when syncing worktrees with the base branch.

### Symptoms

- Files appeared at: `specs/spec.md`, `specs/plan.md`, `specs/tasks.md`
- Expected location: `specs/{meta-spec-id}/{sub-spec-id}/spec.md`, etc.
- Merge conflicts occurred when syncing worktrees with the meta-spec branch
- Manual file relocation was required after each speckit command

## Root Cause

The scripts `setup-plan.sh` and `update-agent-context.sh` were using the old `get_feature_paths()` function which doesn't have sub-spec/worktree awareness. When running commands in a worktree with a sub-spec branch (e.g., `001-html-renderer-002-parser`), the path resolution would fail to detect the nested structure.

## Solution

Updated both scripts to use `get_feature_paths_v2()` which correctly:
- Detects sub-spec branches using the pattern: `###-meta-name-###-sub-name`
- Resolves paths to nested directories: `specs/001-html-renderer/002-parser/`
- Sets appropriate context variables (IS_SUB_SPEC, META_SPEC_DIR, SUB_SPEC_ID)

## Migration Instructions

If you have existing worktrees with misplaced spec files, follow these steps:

### 1. Identify Affected Worktrees

Check for spec files at the wrong level:
```bash
cd <your-worktree>
ls -la specs/*.md
```

If you see files like `specs/spec.md`, `specs/plan.md`, etc., they need to be moved.

### 2. Determine Correct Location

For a sub-spec branch like `001-html-renderer-002-parser`:
- Meta-spec ID: `001-html-renderer`
- Sub-spec ID: `002-parser`
- Correct directory: `specs/001-html-renderer/002-parser/`

### 3. Move Files to Correct Location

```bash
# Extract IDs from branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
META_SPEC_ID=$(echo $BRANCH | sed -E 's/^([0-9]{3}-[^-]+)-.*/\1/')
SUB_SPEC_ID=$(echo $BRANCH | sed -E 's/^[0-9]{3}-[^-]+-([0-9]{3}-.*)$/\1/')

# Create target directory
TARGET_DIR="specs/${META_SPEC_ID}/${SUB_SPEC_ID}"
mkdir -p "$TARGET_DIR"

# Move misplaced files
for file in specs/*.md; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "Moving $file to $TARGET_DIR/$filename"
        mv "$file" "$TARGET_DIR/$filename"
    fi
done

# Move checklists if they exist
if [ -d "specs/checklists" ]; then
    mv specs/checklists "$TARGET_DIR/"
fi

# Commit the relocation
git add specs/
git commit -m "Fix: Relocate spec files to correct sub-spec directory"
```

### 4. Verify and Sync

```bash
# Verify files are in correct location
ls -la "$TARGET_DIR"

# Sync with meta-spec branch
git fetch origin
git rebase origin/<meta-spec-branch>
```

## Verification

After the fix, when you run `/speckit.plan` or other commands in a worktree:

1. The script will detect the sub-spec context from the branch name
2. Paths will be resolved correctly to `specs/{meta-spec-id}/{sub-spec-id}/`
3. Files will be written to the nested directory structure
4. Worktree syncs will complete without merge conflicts

Example test:
```bash
# In a sub-spec worktree
cd <worktree-path>

# Check current branch (should match pattern: ###-meta-###-sub)
git branch --show-current

# Run plan command (will now write to correct location)
# /speckit.plan

# Verify output location
ls -la specs/<meta-spec-id>/<sub-spec-id>/plan.md
```

## Commands Affected

- `/speckit.plan` - Now correctly places `plan.md` in sub-spec directory
- `/speckit.checklist` - Already correct (uses `check-prerequisites.sh` which had awareness)
- `/speckit.tasks` - Already correct (uses `check-prerequisites.sh` which had awareness)

## Commands NOT Affected

These commands already had correct path handling:
- `/speckit.specify-next` - Uses manifest to determine paths
- `/speckit.plan-next` - Uses manifest to determine paths
- `/speckit.tasks-next` - Uses manifest to determine paths
- `/speckit.breakdown` - Creates meta-spec structure correctly

## Prevention

Going forward:
- Always use the `-next` variants for sub-spec work when available
- The regular `/speckit.specify`, `/speckit.plan`, `/speckit.tasks` commands are now fixed to work correctly in worktree contexts
- The path resolution logic in `common.sh` now consistently uses V2 (sub-spec aware) detection

## Technical Details

### Path Resolution Logic

The `get_feature_paths_v2()` function in `common.sh`:

1. **Branch Pattern Detection**: Checks if branch matches `###-meta-name-###-sub-name`
2. **Meta-Spec Lookup**: Finds parent meta-spec directory with `manifest.json`
3. **Nested Path Construction**: Builds path as `{meta-spec-dir}/{sub-spec-id}`
4. **Context Variables**: Sets IS_SUB_SPEC, META_SPEC_DIR, SUB_SPEC_ID

### Updated Scripts

- `.specify/scripts/bash/setup-plan.sh`: Changed from `get_feature_paths()` to `get_feature_paths_v2()`
- `.specify/scripts/bash/update-agent-context.sh`: Changed from `get_feature_paths()` to `get_feature_paths_v2()`

## Support

If you encounter issues after applying this fix:
1. Verify your branch name matches the sub-spec pattern (`###-meta-###-sub`)
2. Ensure the meta-spec directory has a `manifest.json` file
3. Check that the sub-spec directory exists under the meta-spec
4. Run the path resolution test script to debug

For additional help, open an issue on the repository.
