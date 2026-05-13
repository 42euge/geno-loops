---
name: geno-loops-ignition
description: >-
  Cold-start bootstrap loop — turn a high-level goal into a blueprint,
  scaffold, implementation, and verification cycle.
  Use when user says /geno-loops-ignition.
argument-hint: "[goal] [--blueprint <file>] [--max <n>]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
  observability:
    success_signal: "First verified slice bootstrapped — at least one layer passed scaffolder+builder+verifier with a usable artifact"
    failure_signals:
      - "Blueprint generated but no layers completed"
      - "Two consecutive layers produce only placeholders without a usable slice"
      - "Max layers reached with zero verified layers"
      - "Goal too vague to generate a blueprint and user not reachable"
    knowledge_reads:
      - "geno-notes active tasks (project scope)"
      - "Existing repo structure and conventions"
      - "User-provided blueprint file (if --blueprint given)"
    knowledge_writes:
      - "Blueprint at .geno/loops/ignition/<timestamp>/blueprint.md"
      - "Layer plans and checkpoint files in layers/ and checkpoints/"
      - "Session log at .geno/loops/ignition/<timestamp>/session.md"
      - "Milestone notes in geno-notes (kind: milestone, note)"
      - "Scaffolded files and directories in the target repo"
---

# Ignition Loop

Cold-start bootstrap loop. Takes a high-level goal, generates or loads a blueprint, then iteratively bootstraps the work in layers: structure -> implementation -> verification. Each layer hands off checkpoints between Scaffolder, Builder, and Verifier roles so the plan can evolve as the repo takes shape.

## Input

Parse `$ARGUMENTS` for:

- **Task pattern** — fuzzy-matches against geno-notes tasks (optional)
- **Goal text** — a freeform description of what to bootstrap
- **`--blueprint <file>`** — start from an existing blueprint instead of generating one
- **`--max <n>`** — maximum layers or iterations (default: 6)

If no task pattern or goal is provided, use `AskUserQuestion` to ask the user for one of:
1. A high-level goal
2. A blueprint file path
3. "Start from current issue/task"

## When to Use

- Starting a new project, package, module, or feature branch from a rough goal
- Bootstrapping structure before detailed specs exist
- Standing up the first vertical slice: skeleton, core implementation, and verification harness
- Turning an issue brief into an executable blueprint

Do **not** use when a spec already exists (use Turbocharge), when a step-by-step plan already exists (use Cruise), or when the work is mostly exploratory research (use Drift).

## Workflow

### 1. Load or create task context

- Check for geno-notes project scope: `geno-notes list --project --status active --json`
- If a task pattern was provided, activate it: `geno-notes start <pattern> --project`
- If no active task matches and the user gave a goal, create one: `geno-notes add "<goal>" --project`
- Start or activate the task so milestones attach to it
- Create session directory:
  ```
  .geno/loops/ignition/<YYYYMMDD-HHMM>/
  ├── session.md
  ├── goal.md
  ├── blueprint.md
  ├── layers/
  │   ├── layer_01.md
  │   └── ...
  └── checkpoints/
      ├── layer_01_scaffolder.md
      ├── layer_01_builder.md
      └── layer_01_verifier.md
  ```
- Write `session.md` header:
  ```markdown
  # Ignition Session — <YYYY-MM-DD HH:MM>
  ## Config
  - Task: <geno-notes task id or "none">
  - Goal: <summary>
  - Blueprint: <generated or file path>
  - Max layers: <n>

  ## Log
  ```

### 2. Generate or load blueprint

- If `--blueprint <file>` was provided, copy it into `blueprint.md`
- Otherwise inspect the repo, issue, and constraints, then write a blueprint containing:
  - Objective and non-goals
  - Deliverables
  - Proposed structure (directories, files, entrypoints, interfaces)
  - Implementation slices or layers
  - Verification plan
  - Open questions and assumptions
- Save the normalized goal in `goal.md`
- Record the first log entry in `session.md`

### 3. Pick the next bootstrap layer

Sequence work from lowest-friction foundation to first usable slice:

1. **Structure** — folders, files, entrypoints, interfaces, placeholders
2. **Implementation** — enough working code or content to make the layer real
3. **Verification** — tests, lint/build integration, manual checks, docs updates

Choose the smallest layer that meaningfully advances the blueprint without over-scaffolding. Write `layers/layer_<n>.md` with the target, files, verification method, and handoff notes.

### 4. Scaffold the layer

- Spawn a **Scaffolder** agent with the blueprint, current layer file, and previous verifier checkpoint
- Scaffolder creates or reorganizes the minimal structure needed for the layer and writes `checkpoints/layer_<n>_scaffolder.md`:
  ```markdown
  # Layer <n> Scaffolder
  ## Structure created
  ## Files touched
  ## Assumptions
  ## Handoff to Builder
  ```
- If scaffolding reveals a better structure, update `blueprint.md` before continuing

### 5. Build the layer

- Spawn a **Builder** agent with the blueprint, layer file, and scaffolder checkpoint
- Builder fills in the scaffold with the smallest coherent implementation that makes the layer usable
- Builder writes `checkpoints/layer_<n>_builder.md`:
  ```markdown
  # Layer <n> Builder
  ## What was implemented
  ## Files modified
  ## Remaining gaps
  ## Handoff to Verifier
  ```

### 6. Verify the layer

- Spawn a **Verifier** agent with the blueprint, layer file, and builder checkpoint
- Verifier runs the lightest meaningful validation for the layer:

| Layer type | Verification examples |
|---|---|
| Structure | File tree check, import smoke test, command help output |
| Implementation | Focused test, type check, local run, fixture execution |
| Verification/docs | Full test target, lint, docs link spot-check |

- Verifier writes `checkpoints/layer_<n>_verifier.md` with pass/fail, evidence, remaining gaps, and the recommended next layer
- Log milestone:
  ```bash
  geno-notes note "Ignition layer <n> complete: <summary>" --task <id> --kind milestone --project
  ```

### 7. Evolve the blueprint

Update `blueprint.md` and `session.md` with what became concrete:

- Completed layers
- Decisions discovered during implementation
- Remaining layers
- Scope cuts or new risks

Treat the blueprint as a living build sheet, not a frozen spec.

### 8. Loop or complete

**If the goal has a usable scaffold plus first verified slice:**
1. Write final summary to `session.md`
2. Log completion: `geno-notes note "Ignition complete: first verified slice bootstrapped" --task <id> --kind milestone --project`
3. If the task is fully done: `geno-notes done <id> --project`
4. Stop the loop

**If work remains and layers < max:**
1. Call `ScheduleWakeup` with delay 90-180 seconds
2. On wake, repeat from step 3

**If max layers reached:**
1. Write summary to `session.md` with current scaffold, completed layers, and recommended next layer
2. Log: `geno-notes note "Ignition stopped at max layers: <n>/<max> complete" --task <id> --kind note --project`
3. Report what exists, what is next, and where to resume
4. Stop the loop

## Error Recovery

- If the blueprint is too vague to pick a first layer, stop and ask the user for a narrower goal.
- If Scaffolder, Builder, and Verifier disagree on structure, resolve it in `blueprint.md` before starting the next layer.
- If a verification step fails because the harness does not exist yet, treat building that harness as the next layer instead of forcing a broken check.
- If two consecutive layers add only placeholders without producing a usable slice, reduce scope and bootstrap a thinner vertical path.
- If `geno-notes` CLI fails, continue the loop and log the journal failure in `session.md`.
- Never do destructive git operations or mass deletions of generated structure without explicit user confirmation.

## What NOT to Do

- **Don't start coding without a blueprint.** Ignition is spec-generating; the blueprint is the contract for the next layers.
- **Don't scaffold the whole project upfront.** Build only the next few layers needed to reach a verified slice.
- **Don't freeze the blueprint.** Update it when the repo teaches you something new.
- **Don't confuse placeholders with completion.** Every layer should end with something checkable.
- **Don't use Ignition when the work already has a detailed plan or test suite.** Prefer Cruise or Turbocharge in those cases.

## Completion

When this skill finishes (success, failure, or abandoned), emit a trace:

```bash
geno-trace emit \
  --skill geno-loops-ignition \
  --status <success|failure|abandoned> \
  --tool-calls <approximate count> \
  --errors <count of tool/command errors> \
  --task <geno-notes task id, if any> \
  --scope project \
  --produced "<.geno/loops/ignition/<timestamp>/session.md>"
```

- `success` = first verified slice bootstrapped with at least one layer passing scaffolder+builder+verifier
- `failure` = blueprint generated but no layers verified, or max layers reached with zero usable artifacts
- `abandoned` = user stopped early

## Runtime

No venv or scripts — pure markdown workflow. Uses Agent subagents for role handoffs and `ScheduleWakeup` for self-pacing within `/loop`.
