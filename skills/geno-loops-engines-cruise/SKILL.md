---
name: geno-loops-engines-cruise
description: >-
  Plan-driven sequential execution loop — execute a plan one step at a time.
  Use when user says /geno-loops-cruise.
argument-hint: "[task] [--plan <file>]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
observability:
  success_signal: "all plan steps completed successfully"
  failure_signals:
    - "step failed twice consecutively"
    - "user intervention required"
  knowledge_reads:
    - "geno-notes tasks (active, project scope)"
    - "geno-notes plans"
  knowledge_writes:
    - "geno-notes journal (milestones per step)"
    - ".geno/loops/cruise/*/session.md"
---

# Cruise Loop

> Requires a geno-specs spec — see umbrella.

Plan-driven sequential execution. Takes a plan (numbered step list) and executes steps one at a time, each in a fresh Agent subagent with checkpoint handoff. Methodical and predictable — no re-planning, no parallelism, just steady forward progress.

## Input

Parse `$ARGUMENTS` for:

- **Task pattern** — fuzzy-matches against geno-notes tasks (optional)
- **`--plan <file>`** — path to a plan file with numbered steps

Plan discovery order if `--plan` is not provided:

1. Check `geno-notes plans/<task-slug>.md` for the matched task
2. Check `.geno/loops/cruise/` for a recent session with an unfinished plan
3. If nothing found, use `AskUserQuestion` to ask the user for one of:
   - A plan file path
   - A numbered list of steps (freeform text — write to `.geno/loops/cruise/<session>/plan.md`)
   - "Create one" — enter `EnterPlanMode`, design a plan, save it, then continue

## When to Use

- You have a **clear, ordered plan** with numbered steps
- Steps are mostly **sequential** — each builds on the previous
- Multi-step refactors, migration checklists, documentation across files
- Following a plan written in a previous planning session
- Executing a runbook or checklist

Do **not** use when the work needs re-planning as it progresses (use Overdrive), when steps are independent and can run in parallel (use NOS), or when there's no plan yet and the goal is exploratory (use Drift or Boost).

## Workflow

### 1. Load context

- Check for geno-notes project scope: `geno-notes list --project --status active --json`
- If a task pattern was provided, activate it: `geno-notes start <pattern> --project`
- Read the plan file
- Create session directory:
  ```
  .geno/loops/cruise/<YYYYMMDD-HHMM>/
  ├── session.md
  ├── plan.md          (copy of the plan)
  └── checkpoints/
  ```
- Write `session.md` header:
  ```markdown
  # Cruise Session — <YYYY-MM-DD HH:MM>
  ## Config
  - Task: <geno-notes task id or "none">
  - Plan: <plan file path>
  - Steps: <total count>

  ## Checklist
  - [ ] Step 1: <description>
  - [ ] Step 2: <description>
  ...

  ## Log
  ```

### 2. Parse plan

Extract the numbered steps from the plan file. For each step, identify:

- **Description** — what to do
- **Files involved** — which files will be read or modified (if stated)
- **Dependencies** — whether this step depends on a previous step's output
- **Verification** — how to confirm the step is done (if stated)

Write the parsed checklist to `session.md`.

### 3. Pick next step

Select the first step in the checklist that is not yet marked `[x]`. Read the checkpoint from the previous step (if any) at `checkpoints/step_<n-1>.md` to understand the current state.

If all steps are done, skip to step 6 (complete).

### 4. Execute step

Spawn an **Agent subagent** with a self-contained prompt including:

- The step description
- Relevant file paths from the plan
- The previous step's checkpoint (handoff context)
- Instructions to write a checkpoint when done

The agent prompt should follow this structure:

```
You are executing step <n> of a plan for: <task description>

## Previous step
<checkpoint from step n-1, or "This is the first step">

## Your task
<step description>

## Files
<relevant file paths>

## When done
Write a checkpoint to: <session-dir>/checkpoints/step_<n>.md

Checkpoint format:
  # Step <n> Checkpoint
  ## What was done
  <summary of changes>
  ## Files modified
  <list>
  ## State for next step
  <anything the next step needs to know>
  ## Issues encountered
  <any problems or deviations from plan>
```

Wait for the agent to complete and read its checkpoint.

### 5. Verify + log

Read the agent's checkpoint at `checkpoints/step_<n>.md`:

- Verify the step's claimed changes actually exist (spot-check modified files)
- If verification is defined in the plan, run it (test command, type check, etc.)
- Update `session.md`: mark the step `[x]` in the checklist, append a log entry:
  ```markdown
  ### Step <n> — <timestamp>
  <summary from checkpoint>
  ```
- Log to geno-notes:
  ```bash
  geno-notes note "Cruise step <n>/<total>: <summary>" --task <id> --kind milestone --project
  ```

If verification fails:
- If this is the first failure for this step, retry (go back to step 4)
- If this is the second failure, stop and ask the user for guidance via `AskUserQuestion`

### 6. Loop or complete

**If more steps remain:**
- Go back to step 3 (pick next step)
- No delay needed between steps — Agent subagents already provide fresh context

**If all steps are done:**
1. Write final summary to `session.md`:
   ```markdown
   ## Summary
   - Steps completed: <n>/<total>
   - Duration: <start to end>
   - Key changes: <list>
   ```
2. Log completion: `geno-notes note "Cruise complete: <n> steps executed" --task <id> --kind milestone --project`
3. If the task is fully done: `geno-notes done <id> --project`
4. Report to the user what was accomplished

**If a step failed twice and user guidance is needed:**
1. Write partial summary to `session.md`
2. Log: `geno-notes note "Cruise paused at step <n>: <error>" --task <id> --kind bug --project`
3. Present the issue to the user and wait for direction

## Error Recovery

- If an Agent subagent fails to write a checkpoint, read the agent's output directly and construct the checkpoint manually.
- If a step makes changes that break a previous step's work, revert the step's changes and flag the conflict. Do not attempt to fix inter-step conflicts automatically — ask the user.
- If the plan file references files that don't exist, skip to the next step and log the missing file. The plan may be outdated.
- If `geno-notes` CLI fails, continue executing steps — don't let journal failures block plan execution. Log the error to `session.md`.
- Never do destructive git operations (force push, hard reset, branch delete) inside the loop.
- If context grows too large (agent subagents help prevent this), write a comprehensive checkpoint and continue with fresh agents.

## What NOT to Do

- **Don't re-plan mid-execution.** If the plan needs changing, stop and tell the user. Re-planning is Overdrive's job.
- **Don't skip steps without user approval.** Even if a step seems unnecessary, execute it or ask first.
- **Don't parallelize steps.** Steps are sequential by design. If you notice independent steps, suggest NOS for next time.
- **Don't modify the plan file.** The plan is the contract. Deviations go in `session.md` and geno-notes, not the plan itself.
- **Don't continue after two failures on the same step.** Escalate to the user.

## Completion

When this skill finishes (success, failure, or abandoned), emit a trace:

```bash
geno-trace emit \
  --skill geno-loops-cruise \
  --status <success|failure|abandoned> \
  --tool-calls <approximate count> \
  --errors <count of tool/command errors> \
  --task <geno-notes task id, if any> \
  --scope project \
  --produced ".geno/loops/cruise/<session>/session.md"
```

- `success` = all plan steps completed
- `failure` = step failed twice or user had to intervene on a blocker
- `abandoned` = user stopped the loop early

## Runtime

No venv or scripts — pure markdown workflow. Uses Agent subagents for step execution with checkpoint-based handoff.
