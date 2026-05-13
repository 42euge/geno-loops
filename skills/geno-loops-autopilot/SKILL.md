---
name: geno-loops-autopilot
description: >-
  Background monitoring loop — periodically checks CI, tests, lint, and git
  status, auto-fixing low-risk issues or alerting when human attention is
  needed. Use when user says /geno-loops-autopilot.
argument-hint: "[task] [--watch <tests|ci|lint|git|all>] [--every <15m|30m>] [--for <duration>]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
---

# Autopilot Loop

Background monitoring and maintenance loop. Watches the repo or PR over a long window and reacts when conditions change. Low intensity and reactive: it wakes on a cron, checks health signals, applies safe fixes when obvious, and escalates anything ambiguous.

## Input

Parse `$ARGUMENTS` for:

- **Task pattern** — fuzzy-matches against geno-notes tasks (optional)
- **`--watch <tests|ci|lint|git|all>`** — what to monitor. Default: `all`
- **`--every <15m|30m>`** — wake interval. Default: `15m`
- **`--for <duration>`** — total monitoring window. Default: `24h`, max `7d`

If no explicit watch target is given, monitor `ci`, `lint`, `tests`, and `git`.

## When to Use

- You opened a PR and want passive CI/watchdog coverage
- You want regression catching while other work is happening
- You need low-touch maintenance over hours instead of an active tight loop
- You want automatic journaling of failures, fixes, and follow-up tasks

Do **not** use when the goal is active implementation (use Turbocharge or Cruise), exploratory research (use Drift), or a one-time delayed action (use Snooze).

## Workflow

### 1. Load context

- Check for geno-notes project scope: `geno-notes list --project --status active --json`
- If a task pattern was provided, activate it: `geno-notes start <pattern> --project`
- Detect repo, current branch, default branch, and whether the branch has an open PR
- Create session directory:
  ```
  .geno/loops/autopilot/<YYYYMMDD-HHMM>/
  ├── session.md
  └── checkpoints/
  ```
- Write `session.md` header:
  ```markdown
  # Autopilot Session — <YYYY-MM-DD HH:MM>
  ## Config
  - Task: <geno-notes task id or "none">
  - Watch: <tests, ci, lint, git>
  - Interval: <15m or 30m>
  - Duration: <target end time>
  - Branch: <current branch>

  ## Log
  ```

### 2. Establish baseline

Record the starting state for each selected signal:

- **tests** — detect the project's normal test command and run it once if it is safe and well-defined
- **lint** — detect the lint command (or formatter/lint autofix command if available)
- **ci** — inspect current PR checks or recent workflow runs with `gh`
- **git** — capture working tree status, ahead/behind state, and merge-conflict markers

Log the baseline in `session.md`:

```markdown
### Baseline — <timestamp>
- Tests: passing / failing / unavailable
- Lint: clean / failing / unavailable
- CI: green / red / pending / unavailable
- Git: clean / dirty / diverged
```

If no reliable local test or lint command can be detected, keep monitoring CI and git state instead of guessing.

### 3. Schedule recurring checks

- Use `CronCreate` to schedule recurring wakeups every 15 or 30 minutes
- Set the schedule end time to the requested duration, capped at 7 days
- Pass a wake prompt that includes:
  - session directory
  - watch targets
  - branch / PR context
  - conservative fix rules
- Record the cron id and end time in `session.md`

### 4. On each cycle

On each wakeup:

1. Re-check each selected signal
2. Compare against the previous cycle and the baseline
3. Classify findings:
   - **Healthy** — no action needed
   - **Retryable** — likely transient failure (for example flaky CI or network failure)
   - **Safe fix** — deterministic, low-risk fix is available
   - **Human action** — needs design judgment or touches user work

Allowed safe fixes:

- Run documented formatter or lint autofix commands
- Regenerate deterministic tracked artifacts when the repo already treats them as generated outputs
- Retry a failing test or CI check once when the failure looks transient

If a safe fix changes tracked files:

- Verify immediately with the relevant check
- Only auto-commit on a non-default branch
- Use a narrow commit message like `autopilot: fix lint drift`

If the branch is the default branch, never auto-commit. Log the fix opportunity and alert instead.

### 5. Log and journal

Append each cycle to `session.md`:

```markdown
### Cycle <n> — <timestamp>
- Findings: <summary>
- Action: <none | retried | fixed | escalated>
- Result: <green | still failing | waiting on human>
```

Integrate with geno-notes when available:

- New failures or regressions → `geno-notes note ... --kind bug`
- Successful auto-fixes → `geno-notes note ... --kind milestone`
- Issues needing a human later → create or suggest a follow-up task

### 6. Continue or stop

Keep monitoring while progress is passive and safe.

Stop the loop when:

- The requested duration expires
- The PR is merged or closed
- The branch is deleted or no longer relevant
- The same problem fails repeated retries or safe fixes
- Human input is required

When stopping, write a final summary to `session.md` and report whether the session ended cleanly, with fixes applied, or blocked on a person.

## Error Recovery

- If a check command crashes, retry once. If it crashes again, mark that signal unavailable and continue with the others.
- If the same safe fix fails twice, stop retrying it and escalate.
- If `gh` is unavailable, continue monitoring local signals and log degraded mode.
- If `geno-notes` fails, keep monitoring and write the journal information to `session.md` instead.
- Never do destructive git operations inside Autopilot: no force pushes, hard resets, rebases, merges, or automatic conflict resolution.

## What NOT to Do

- **Don't monitor forever.** Respect the `CronCreate` 7-day cap.
- **Don't auto-fix ambiguous failures.** If the cause is not obvious, alert a human.
- **Don't commit to the default branch.** Background maintenance must stay off `main`/`master`.
- **Don't overwrite user changes.** If the tree is dirty from unrelated edits, log it and stop.
- **Don't turn Autopilot into Turbocharge.** If the loop becomes active implementation, switch to a tighter execution loop.

## Runtime

No venv or scripts — pure markdown workflow. Uses `CronCreate` for 15–30 minute recurring checks over long-running sessions.
