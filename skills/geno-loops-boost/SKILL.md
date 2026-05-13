---
name: geno-loops-boost
description: >-
  Time-boxed focus sessions (Pomodoro) — work for 25min, reflect for 5min.
  Use when user says /geno-loops-boost.
argument-hint: "[task] [--work <min>] [--reflect <min>]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
  observability:
    success_signal: "Session completed with at least one full work+reflect cycle and reflection logged to geno-notes"
    failure_signals:
      - "ScheduleWakeup never fires and no reflection occurs"
      - "geno-notes note fails and session.md also fails to write"
      - "Zero work blocks completed before the session ends"
    knowledge_reads:
      - "geno-notes active tasks (project scope)"
      - "Previous boost session logs in .geno/loops/boost/"
    knowledge_writes:
      - "Reflection journal entries in geno-notes (kind: note, milestone)"
      - "Session log at .geno/loops/boost/<timestamp>/session.md"
---

# Boost Loop (Pomodoro)

Time-boxed focus sessions. Implements the Pomodoro technique: 25 minutes of deep work followed by 5 minutes of reflection. Forces periodic stopping to prevent context degradation and ensure progress is logged. Journal-heavy — every reflection phase writes a journal entry to `geno-notes`.

## Input

Parse `$ARGUMENTS` for:

- **Task pattern** — fuzzy-matches against geno-notes tasks (optional)
- **`--work <min>`** — duration of the work phase in minutes (default: 25)
- **`--reflect <min>`** — duration of the reflection phase in minutes (default: 5)

## When to Use

- **Complex investigation** where context degradation is a risk
- **Open-ended exploration** or debugging without a clear end-point
- When you want to ensure **steady journal logging**
- To prevent "rabbit-holing" on a single approach for too long

Do **not** use when you have a clear plan (use Cruise), when you have a testable spec (use Turbocharge), or for quick tasks (under 30min).

## Workflow

### 1. Load context

- Check for geno-notes project scope: `geno-notes list --project --status active --json`
- If a task pattern was provided, activate it: `geno-notes start <pattern> --project`
- Create session directory:
  ```
  .geno/loops/boost/<YYYYMMDD-HHMM>/
  ├── session.md
  └── log/
  ```
- Write `session.md` header:
  ```markdown
  # Boost Session — <YYYY-MM-DD HH:MM>
  ## Config
  - Task: <geno-notes task id or "none">
  - Work: <work_min>m
  - Reflect: <reflect_min>m

  ## Log
  ```

### 2. Start Work Phase

1. Log the start of the work block to `session.md`.
2. Determine the work duration (default 25min, max 60min for `ScheduleWakeup`).
3. Call `ScheduleWakeup` with the delay and the prompt: `/loop-boost-reflect <session_dir>`
4. Start working autonomously on the task.

### 3. Reflect Phase (Triggered by Wakeup)

When the wakeup fires, transition to reflection:

1. **Summarize** what was accomplished during the work block.
2. **Identify** key findings, decisions made, or new sub-tasks.
3. **Write to geno-notes**:
   ```bash
   geno-notes note "Boost Reflection: <summary>" --task <id> --kind note --project
   ```
4. Update `session.md` with the reflection summary.
5. Use `AskUserQuestion` to ask the user:
   - "Continue for another block?"
   - "Finish session"
   - "Change task"

### 4. Continue or Finish

- **If Continue**: Repeat from Step 2.
- **If Finish**:
  1. Write final summary to `session.md`.
  2. Log completion: `geno-notes note "Boost session complete" --task <id> --kind milestone --project`
  3. Report to the user and stop.
- **If Change Task**: Update configuration and repeat from Step 1.

## Error Recovery

- If `geno-notes` fails, log the reflection to `session.md` and continue.
- If the agent crashes during a work block, the `ScheduleWakeup` will still fire. On wake, the agent should attempt to reconstruct the lost work state from file changes.

## Completion

When this skill finishes (success, failure, or abandoned), emit a trace:

```bash
geno-trace emit \
  --skill geno-loops-boost \
  --status <success|failure|abandoned> \
  --tool-calls <approximate count> \
  --errors <count of tool/command errors> \
  --task <geno-notes task id, if any> \
  --scope project \
  --produced "<.geno/loops/boost/<timestamp>/session.md>"
```

- `success` = at least one full work+reflect cycle completed with reflection logged to geno-notes
- `failure` = no work blocks completed, or reflection could not be persisted anywhere
- `abandoned` = user stopped early

## Runtime

Pure markdown workflow. Uses `ScheduleWakeup` for time-boxing and `geno-notes` for reflection persistence.
