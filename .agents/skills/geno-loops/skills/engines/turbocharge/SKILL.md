---
name: geno-loops-engines-turbocharge
description: >-
  Spec-driven convergence loop — iterate until all acceptance criteria pass.
  Use when user says /geno-loops-turbocharge.
argument-hint: "[task] [--spec <file>] [--max <n>]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
observability:
  success_signal: "all acceptance criteria pass"
  failure_signals:
    - "max iterations reached with failing criteria"
    - "spec runner crashed twice"
    - "same criterion fails 3 iterations in a row"
  knowledge_reads:
    - "geno-notes tasks (active, project scope)"
    - "geno-notes plans"
  knowledge_writes:
    - "geno-notes journal (milestones per criterion)"
    - ".geno/loops/turbocharge/*/session.md"
---

# Turbocharge Loop

> Requires a geno-specs spec — see umbrella.

Spec-driven convergence loop. Takes a testable specification (test file, acceptance criteria, type contract) and iterates until every criterion passes. Each iteration validates, identifies gaps, implements fixes, and re-validates. The loop converges toward zero failures.

## Input

Parse `$ARGUMENTS` for:

- **Task pattern** — fuzzy-matches against geno-notes tasks (optional)
- **`--spec <file>`** — path to the spec file (test suite, criteria list, type definitions)
- **`--max <n>`** — maximum iterations (default: 8)

If no spec is provided, use `AskUserQuestion` to ask the user for one of:
1. A test file to run
2. A list of acceptance criteria (freeform text — write them to `.geno/loops/turbocharge/<session>/spec.md`)
3. A type contract or API spec file

## When to Use

- You have a **testable target**: test suite, type definitions, acceptance criteria, API contract
- The work is **convergence-oriented** — each iteration should get closer to passing
- TDD: write tests first, then loop until green
- Contract-first development: implement until the interface is satisfied
- Migrations with known targets: old behavior must be preserved in new code

Do **not** use when the goal is exploratory (use Drift), when there's no spec to validate against (use Boost), or when the work has many independent items (use NOS).

## Workflow

### 1. Load context

- Check for geno-notes project scope: `geno-notes list --project --status active --json`
- If a task pattern was provided, activate it: `geno-notes start <pattern> --project`
- Read the spec file (or the criteria written during Input)
- Create session directory:
  ```
  .geno/loops/turbocharge/<YYYYMMDD-HHMM>/
  ├── session.md
  ├── spec.md          (copy of spec or user-provided criteria)
  └── checkpoints/
  ```
- Write `session.md` header:
  ```markdown
  # Turbocharge Session — <YYYY-MM-DD HH:MM>
  ## Config
  - Task: <geno-notes task id or "none">
  - Spec: <spec file path>
  - Max iterations: <n>

  ## Log
  ```

### 2. Validate spec (baseline)

Run the spec check. The validation method depends on the spec type:

| Spec type | Validation command |
|---|---|
| Test file (`.test.*`, `*_test.*`) | Run the test runner (`npm test`, `pytest`, `go test`, etc.) |
| Type definitions (`.d.ts`, `.pyi`) | Run the type checker (`tsc --noEmit`, `mypy`, etc.) |
| Acceptance criteria (`.md` list) | Grep/check each criterion manually against the codebase |
| API contract (OpenAPI, protobuf) | Run contract validation tool or diff against implementation |

Record baseline results in `session.md`:
```markdown
### Iteration 0 (baseline) — <timestamp>
- Passing: 3/10
- Failing: 7/10
- Failures: <list each failing criterion>
```

If everything already passes, write a note and stop — no work needed.

### 3. Identify gaps

Compare passing vs. failing criteria. Prioritize:

1. **Quick wins** — criteria that are close to passing (small changes needed)
2. **Blockers** — criteria that other failing criteria depend on
3. **Isolated** — criteria that can be fixed without touching shared code
4. **Hard** — criteria requiring significant design or multi-file changes

Pick the top 1–3 gaps to address this iteration. Write the plan to `session.md`.

### 4. Implement fixes

Make targeted changes to close the selected gaps:

- Keep changes **small and focused** — one logical change per iteration
- Do not touch code unrelated to the failing criteria
- Do not modify the spec itself
- If a fix requires a design decision, log it: `geno-notes note "<decision>" --task <id> --kind decision --project`

### 5. Re-validate

Run the spec check again (same method as step 2). Log results to `session.md`:

```markdown
### Iteration <n> — <timestamp>
- Passing: 7/10 (+4)
- Failing: 3/10 (-4)
- Fixed this iteration: <list>
- Still failing: <list>
```

For each newly-passing criterion, log a milestone:
```bash
geno-notes note "Turbocharge: <criterion> now passing" --task <id> --kind milestone --project
```

### 6. Loop or complete

**If all criteria pass:**
1. Write final summary to `session.md`
2. Log completion: `geno-notes note "Turbocharge complete: all <n> criteria passing after <iterations> iterations" --task <id> --kind milestone --project`
3. If the task is fully done: `geno-notes done <id> --project`
4. Stop the loop

**If criteria remain and iterations < max:**
1. Call `ScheduleWakeup` with delay 60–120 seconds (stay in prompt cache)
2. On wake, repeat from step 3

**If max iterations reached:**
1. Write summary to `session.md` with remaining failures
2. Log: `geno-notes note "Turbocharge stopped at max iterations: <passing>/<total> passing" --task <id> --kind note --project`
3. Report remaining gaps to the user
4. Stop the loop

## Error Recovery

- If a spec check command fails (not "tests failed" but "command crashed"), retry once. If it fails again, log the error to `session.md` and stop — the spec runner itself is broken.
- If an iteration makes things worse (more failures than before), revert the changes (`git checkout -- .`) and try a different approach. Log the revert.
- If the same criterion fails 3 iterations in a row with the same error, flag it as stuck and skip to other criteria.
- If `geno-notes` CLI fails, continue the loop — don't let journal failures block convergence work. Log the geno-notes error to `session.md` instead.
- Never do destructive git operations (force push, hard reset, branch delete) inside the loop.

## What NOT to Do

- **Don't modify the spec.** The spec is the target, not the implementation. If the spec is wrong, stop and tell the user.
- **Don't skip failing criteria.** Every criterion must either pass or be explicitly flagged as stuck.
- **Don't make unrelated changes.** If you notice other issues, log them as `geno-notes note --kind bug` but don't fix them in this loop.
- **Don't continue past max iterations.** Respect the limit — infinite loops waste resources.
- **Don't run without a spec.** If there's nothing to validate against, suggest Boost or Drift instead.

## Completion

When this skill finishes (success, failure, or abandoned), emit a trace:

```bash
geno-trace emit \
  --skill geno-loops-turbocharge \
  --status <success|failure|abandoned> \
  --tool-calls <approximate count> \
  --errors <count of tool/command errors> \
  --task <geno-notes task id, if any> \
  --scope project \
  --produced ".geno/loops/turbocharge/<session>/session.md"
```

- `success` = all criteria pass
- `failure` = max iterations reached or spec runner broken
- `abandoned` = user stopped the loop early

## Runtime

No venv or scripts — pure markdown workflow. Uses `ScheduleWakeup` for self-pacing within `/loop`.
