---
description: Perform a non-destructive cross-artifact consistency and quality analysis across spec.md, plan.md, and tasks.md after task generation. (project)
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Argument Parsing:**
- `--feature <name>`: Specify feature/meta-spec name directly (allows running from main branch)
- `--sub-spec <id>`: Analyze a specific sub-spec within a meta-spec (requires --feature)
- `--all`: For meta-specs, analyze all sub-specs and produce aggregate report
- No arguments: Use branch-based detection (original behavior)

## Goal

Identify inconsistencies, duplications, ambiguities, and underspecified items across the three core artifacts (`spec.md`, `plan.md`, `tasks.md`) before implementation. This command MUST run only after `/speckit.tasks` has successfully produced a complete `tasks.md`.

**Meta-Spec Support:** When analyzing a meta-spec (directory with `manifest.json`), this command can:
1. Analyze a specific sub-spec within the meta-spec
2. Aggregate analysis across all sub-specs (with `--all`)
3. Validate cross-sub-spec consistency (dependency alignment, shared terminology)

## Operating Constraints

**STRICTLY READ-ONLY**: Do **not** modify any files. Output a structured analysis report. Offer an optional remediation plan (user must explicitly approve before any follow-up editing commands would be invoked manually).

**Constitution Authority**: The project constitution (`.specify/memory/constitution.md`) is **non-negotiable** within this analysis scope. Constitution conflicts are automatically CRITICAL and require adjustment of the spec, plan, or tasks—not dilution, reinterpretation, or silent ignoring of the principle. If a principle itself needs to change, that must occur in a separate, explicit constitution update outside `/speckit.analyze`.

## Execution Steps

### 1. Initialize Analysis Context

**Parse Arguments First:**

Extract `--feature`, `--sub-spec`, and `--all` flags from `$ARGUMENTS` if present.

**Build check-prerequisites command:**

```bash
# Build command as an array to avoid eval security issues
CMD=(.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks)

# Add feature flag if specified
if [ -n "$FEATURE" ]; then
    CMD+=(--feature "$FEATURE")
fi

# Add sub-spec flag if specified
if [ -n "$SUB_SPEC" ]; then
    CMD+=(--sub-spec "$SUB_SPEC")
fi

# Execute command array directly
"${CMD[@]}"
```

Parse the JSON output for context detection:
- `IS_META_SPEC`: true if analyzing a meta-spec (aggregate mode)
- `IS_SUB_SPEC`: true if analyzing a specific sub-spec
- `FEATURE_DIR`: path to feature/sub-spec directory
- `META_SPEC_DIR`: path to parent meta-spec (for sub-specs)

**Context-Specific Path Resolution:**

For **simple feature** or **sub-spec**:
- SPEC = FEATURE_DIR/spec.md
- PLAN = FEATURE_DIR/plan.md
- TASKS = FEATURE_DIR/tasks.md

For **meta-spec aggregate** (`--all`):
- USER_STORY = FEATURE_DIR/user-story.md
- BREAKDOWN = FEATURE_DIR/breakdown.md
- MANIFEST = FEATURE_DIR/manifest.json
- Iterate each sub-spec directory for individual artifacts

Abort with an error message if any required file is missing (instruct the user to run missing prerequisite command).
For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

### 2. Load Artifacts (Context-Aware Loading)

**CRITICAL**: For meta-spec aggregate analysis (`--all`), DO NOT load all sub-spec artifacts directly. Instead, use the Task tool to spawn parallel agents (see Step 2B below).

#### 2A. For Simple Feature or Sub-Spec Context

Load only the minimal necessary context from each artifact:

**From spec.md:**

- Overview/Context
- Functional Requirements
- Non-Functional Requirements
- User Stories
- Edge Cases (if present)

**From plan.md:**

- Architecture/stack choices
- Data Model references
- Phases
- Technical constraints

**From tasks.md:**

- Task IDs
- Descriptions
- Phase grouping
- Parallel markers [P]
- Referenced file paths

**From constitution:**

- Load `.specify/memory/constitution.md` for principle validation

**Then continue to Step 3.**

#### 2B. For Meta-Spec Aggregate Context (`--all`) - PARALLEL AGENT WORKFLOW

**DO NOT load sub-spec artifacts directly.** Instead, use the Task tool to analyze each sub-spec in parallel.

**Step 2B.1: Load Meta-Spec Level Artifacts Only**

Load only these lightweight files for cross-sub-spec validation:

**From user-story.md:**

- High-level user story
- Acceptance criteria
- Scope boundaries

**From breakdown.md:**

- Sub-spec decomposition
- Declared dependencies
- Scope allocation per sub-spec

**From manifest.json:**

- Sub-spec list with phase status
- Dependency graph
- Schedule (if approved)

**Step 2B.2: Query Sub-Specs with Tasks Complete**

Read the manifest.json and identify sub-specs where `phases.tasks.status === "complete"`:

```bash
# Read manifest and extract sub-spec IDs with tasks complete
jq -r '.subSpecs[] | select(.phases.tasks.status == "complete") | .id' "$META_SPEC_DIR/manifest.json"
```

Alternatively, use the summary command for a quick overview:

```bash
.specify/scripts/bash/manifest.sh summary "$META_SPEC_DIR"
```

**Step 2B.3: Confirm with User**

Display the sub-specs to be analyzed:

```markdown
## Ready for Parallel Analysis

The following sub-specs will be analyzed:

| ID | Title | Status |
|----|-------|--------|
| 001-parser | Parser & Sanitizer | tasks complete |
| 002-native-adapter | Native Renderer | tasks complete |

**Parallel agents to spawn**: N

Proceed with parallel analysis?
```

**Step 2B.4: Spawn Parallel Agents**

Use the Task tool with **multiple calls in a single message** to analyze each sub-spec concurrently:

```text
For each sub-spec, spawn a Task with subagent_type="general-purpose":

"Analyze sub-spec [ID] for meta-spec [META_SPEC_NAME].

You are performing a focused analysis of a single sub-spec. Do NOT use --all flag.

1. Read the constitution: .specify/memory/constitution.md
2. Read spec: specs/[META_SPEC]/[SUB_SPEC_ID]/spec.md
3. Read plan: specs/[META_SPEC]/[SUB_SPEC_ID]/plan.md
4. Read tasks: specs/[META_SPEC]/[SUB_SPEC_ID]/tasks.md

Perform the following analysis passes:
- Duplication detection
- Ambiguity detection (vague adjectives, placeholders)
- Underspecification (missing acceptance criteria, undefined references)
- Constitution alignment (MUST principles)
- Coverage gaps (requirements without tasks, tasks without requirements)
- Inconsistency (terminology drift, contradictions)

Return a structured JSON report:
{
  \"subSpecId\": \"[ID]\",
  \"metrics\": {
    \"totalRequirements\": N,
    \"totalTasks\": N,
    \"coveragePercent\": N,
    \"ambiguityCount\": N,
    \"duplicationCount\": N
  },
  \"issues\": [
    {
      \"id\": \"A1\",
      \"category\": \"Duplication|Ambiguity|Underspecification|Constitution|Coverage|Inconsistency\",
      \"severity\": \"CRITICAL|HIGH|MEDIUM|LOW\",
      \"location\": \"file.md:L123\",
      \"summary\": \"Brief description\",
      \"recommendation\": \"How to fix\"
    }
  ],
  \"criticalCount\": N,
  \"highCount\": N,
  \"mediumCount\": N,
  \"lowCount\": N
}

Limit to 15 findings per sub-spec. Focus on CRITICAL and HIGH severity first."
```

**Step 2B.5: Collect Results**

Wait for all parallel agents to complete. Parse JSON reports from each.

**Step 2B.6: Cross-Sub-Spec Analysis**

With the collected individual reports AND the meta-spec level artifacts (user-story.md, breakdown.md), perform cross-sub-spec checks:

- **Dependency alignment**: Do task dependencies match breakdown.md declarations?
- **Interface contracts**: Are shared types/APIs consistent across sub-specs?
- **Scope leakage**: Does any sub-spec implement another's scope?
- **Terminology consistency**: Same concepts named consistently?
- **User story coverage**: All acceptance criteria mapped to sub-spec requirements?

**Then skip to Step 6 to produce the aggregate report.**

### 3. Build Semantic Models (Simple Feature/Sub-Spec Only)

**Note**: This step is for simple feature or individual sub-spec analysis only. For `--all` mode, the parallel agents handle this internally and you skip to Step 6 after collecting results.

Create internal representations (do not include raw artifacts in output):

- **Requirements inventory**: Each functional + non-functional requirement with a stable key (derive slug based on imperative phrase; e.g., "User can upload file" → `user-can-upload-file`)
- **User story/action inventory**: Discrete user actions with acceptance criteria
- **Task coverage mapping**: Map each task to one or more requirements or stories (inference by keyword / explicit reference patterns like IDs or key phrases)
- **Constitution rule set**: Extract principle names and MUST/SHOULD normative statements

### 4. Detection Passes (Simple Feature/Sub-Spec Only)

**Note**: For `--all` mode, detection passes A-F are performed by parallel agents. Only Step 4G (Cross-Sub-Spec Consistency) is performed after collecting agent results.

Focus on high-signal findings. Limit to 50 findings total; aggregate remainder in overflow summary.

#### A. Duplication Detection

- Identify near-duplicate requirements
- Mark lower-quality phrasing for consolidation

#### B. Ambiguity Detection

- Flag vague adjectives (fast, scalable, secure, intuitive, robust) lacking measurable criteria
- Flag unresolved placeholders (TODO, TKTK, ???, `<placeholder>`, etc.)

#### C. Underspecification

- Requirements with verbs but missing object or measurable outcome
- User stories missing acceptance criteria alignment
- Tasks referencing files or components not defined in spec/plan

#### D. Constitution Alignment

- Any requirement or plan element conflicting with a MUST principle
- Missing mandated sections or quality gates from constitution

#### E. Coverage Gaps

- Requirements with zero associated tasks
- Tasks with no mapped requirement/story
- Non-functional requirements not reflected in tasks (e.g., performance, security)

#### F. Inconsistency

- Terminology drift (same concept named differently across files)
- Data entities referenced in plan but absent in spec (or vice versa)
- Task ordering contradictions (e.g., integration tasks before foundational setup tasks without dependency note)
- Conflicting requirements (e.g., one requires Next.js while other specifies Vue)

#### G. Meta-Spec Cross-Consistency (`--all` mode - performed after parallel agents complete)

When analyzing a meta-spec with multiple sub-specs, this is the **only Step 4 action** you perform directly (after collecting parallel agent results). Check:

- **Dependency alignment**: Sub-spec declares dependency on another, but tasks don't reflect integration points
- **Interface contracts**: Data types/APIs defined in one sub-spec match expected inputs in dependent sub-specs
- **Scope leakage**: Sub-spec implements functionality allocated to a different sub-spec in breakdown.md
- **Terminology consistency**: Same concept named differently across sub-specs
- **Shared component conflicts**: Multiple sub-specs define the same component/file path
- **User story coverage**: All acceptance criteria from user-story.md have corresponding requirements in at least one sub-spec
- **Manifest accuracy**: Phase status in manifest.json matches actual artifact existence

### 5. Severity Assignment

**Note**: For `--all` mode, parallel agents assign severity to individual sub-spec findings. You only assign severity to cross-sub-spec issues (Step 4G findings).

Use this heuristic to prioritize findings:

- **CRITICAL**: Violates constitution MUST, missing core spec artifact, or requirement with zero coverage that blocks baseline functionality
- **HIGH**: Duplicate or conflicting requirement, ambiguous security/performance attribute, untestable acceptance criterion
- **MEDIUM**: Terminology drift, missing non-functional task coverage, underspecified edge case
- **LOW**: Style/wording improvements, minor redundancy not affecting execution order

### 6. Produce Compact Analysis Report

Output a Markdown report (no file writes) with the following structure:

**For Simple Feature or Sub-Spec**

## Specification Analysis Report

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | Duplication | HIGH | spec.md:L120-134 | Two similar requirements ... | Merge phrasing; keep clearer version |

(Add one row per finding; generate stable IDs prefixed by category initial.)

**Coverage Summary Table:**

| Requirement Key | Has Task? | Task IDs | Notes |
|-----------------|-----------|----------|-------|

**Constitution Alignment Issues:** (if any)

**Unmapped Tasks:** (if any)

**Metrics:**

- Total Requirements
- Total Tasks
- Coverage % (requirements with >=1 task)
- Ambiguity Count
- Duplication Count
- Critical Issues Count

**For Meta-Spec Aggregate (`--all`)**

## Meta-Spec Analysis Report

**Meta-Spec:** [ID] - [Title]
**Sub-Specs Analyzed:** X of Y

### Sub-Spec Summary

| Sub-Spec | Requirements | Tasks | Coverage | Issues |
|----------|--------------|-------|----------|--------|
| 001-parser | 12 | 15 | 100% | 2 LOW |
| 002-native-adapter | 8 | 20 | 100% | 1 MEDIUM |

### Cross-Sub-Spec Issues

| ID | Category | Severity | Sub-Specs | Summary | Recommendation |
|----|----------|----------|-----------|---------|----------------|
| G1 | Interface | HIGH | 001→002 | Parser output type differs... | Align HTMLNode type |

### Per-Sub-Spec Details

<details>
<summary>001-parser (2 issues)</summary>

[Individual sub-spec analysis table]

</details>

**Aggregate Metrics:**

- Total Sub-Specs: X
- Total Requirements (all): Y
- Total Tasks (all): Z
- Average Coverage: N%
- Cross-Sub-Spec Issues: M
- Critical Issues: C

### 7. Provide Next Actions

At end of report, output a concise Next Actions block:

**For Simple Feature or Sub-Spec**

- If CRITICAL issues exist: Recommend resolving before `/speckit.implement`
- If only LOW/MEDIUM: User may proceed, but provide improvement suggestions
- Provide explicit command suggestions: e.g., "Run /speckit.specify with refinement", "Run /speckit.plan to adjust architecture", "Manually edit tasks.md to add coverage for 'performance-metrics'"

**For Meta-Spec Aggregate**

- If CRITICAL cross-sub-spec issues: Recommend resolving before `/speckit.schedule` or `/speckit.implement-next`
- If sub-spec-specific CRITICAL issues: Recommend which sub-specs need attention
- Provide targeted command suggestions:
  - `/speckit.analyze --feature <name> --sub-spec <id>` for detailed sub-spec analysis
  - Manual edits to specific sub-spec artifacts
  - `/speckit.schedule` if ready for implementation scheduling

### 8. Offer Remediation

Ask the user: "Would you like me to suggest concrete remediation edits for the top N issues?" (Do NOT apply them automatically.)

For meta-spec context, also offer: "Would you like me to analyze a specific sub-spec in detail?"

## Operating Principles

### Context Efficiency

- **Minimal high-signal tokens**: Focus on actionable findings, not exhaustive documentation
- **Progressive disclosure**: Load artifacts incrementally; don't dump all content into analysis
- **Token-efficient output**: Limit findings table to 50 rows; summarize overflow
- **Deterministic results**: Rerunning without changes should produce consistent IDs and counts

### Analysis Guidelines

- **NEVER modify files** (this is read-only analysis)
- **NEVER hallucinate missing sections** (if absent, report them accurately)
- **Prioritize constitution violations** (these are always CRITICAL)
- **Use examples over exhaustive rules** (cite specific instances, not generic patterns)
- **Report zero issues gracefully** (emit success report with coverage statistics)

## Context

$ARGUMENTS
