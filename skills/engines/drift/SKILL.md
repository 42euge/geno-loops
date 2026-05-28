---
name: geno-loops-engines-drift
description: >-
  Question-driven exploration loop. Maintains a prioritized question queue.
  Each cycle answers the top question and may spawn new questions.
  Follows the thread wherever it leads.
argument-hint: "[starting-question] [--max <n>]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
  observability:
    success_signal: "All questions in the queue answered, or max cycles reached with findings documented"
    failure_signals:
      - "No questions answered after multiple cycles"
      - "Session ends with no findings logged to session.md or geno-notes"
      - "Question queue grows unboundedly without any questions being resolved"
    knowledge_reads:
      - "geno-notes active tasks (project scope)"
      - "Codebase files explored during investigation"
    knowledge_writes:
      - "Answered questions and findings in .geno/loops/drift/<timestamp>/session.md"
      - "Question queue with answers in .geno/loops/drift/<timestamp>/questions.md"
      - "Bug and decision notes in geno-notes (kind: bug, decision, milestone)"
---

# Drift Loop

> Requires a geno-specs spec — see umbrella.

Question-driven exploration loop. Ideal for codebase archaeology, debugging complex issues with unclear scope, or understanding unfamiliar systems. It maintains a prioritized queue of questions, systematically answering each while spawning new inquiries along the way.

## Input

Parse `$ARGUMENTS` for:

- **Starting question** — the initial inquiry to kick off exploration (optional)
- **`--max <n>`** — maximum cycles (default: 10)

If no starting question is provided, use `AskUserQuestion` to ask the user what they want to explore.

## When to Use

- **Codebase archaeology**: Understanding how a legacy or complex system works
- **Debugging**: Investigating issues with high uncertainty or "where do I even start?"
- **Research**: Exploring a new library, framework, or architectural pattern
- **Root-cause analysis**: Following a chain of "why" questions

Do **not** use when you have a clear spec or target (use Turbocharge), when you have a linear plan (use Cruise), or when you just need to get work done in focused blocks (use Boost).

## Workflow

### 1. Load context

- Check for geno-notes project scope: `geno-notes list --project --status active --json`
- Create session directory:
  ```
  .geno/loops/drift/<YYYYMMDD-HHMM>/
  ├── session.md
  └── questions.md
  ```
- Write `questions.md` with the starting question:
  ```markdown
  # Question Queue
  - [ ] <starting-question> (Priority: High)
  ```
- Write `session.md` header:
  ```markdown
  # Drift Session — <YYYY-MM-DD HH:MM>
  ## Config
  - Max cycles: <n>

  ## Log
  ```

### 2. Pick next question

Select the highest priority open question from `questions.md`. If multiple have the same priority, pick the most specific one.

Record the choice in `session.md`:
```markdown
### Cycle <n> — Exploring: "<question>"
```

### 3. Explore and answer

Investigate the codebase or system to answer the question:

- Use `grep_search`, `read_file`, `run_shell_command` as needed.
- Document findings in `session.md` as they are discovered.
- If the exploration leads to new questions, add them to `questions.md` with a priority (High/Medium/Low).
- If a bug is found: `geno-notes note "Found bug: <desc>" --kind bug --project`
- If a decision is needed or made: `geno-notes note "<decision>" --kind decision --project`

### 4. Finalize answer

Once the question is sufficiently answered:

- Update `questions.md`: mark the question as done and include the answer summary.
- Log a milestone: `geno-notes note "Drift answered: <question>" --kind milestone --project`

### 5. Loop or complete

**If all questions in `questions.md` are done OR max cycles reached:**
1. Write final summary to `session.md`
2. Present findings to the user.
3. Stop the loop

**If questions remain and cycles < max:**
1. Call `ScheduleWakeup` with delay 180–270 seconds (exploratory work takes time)
2. On wake, repeat from step 2

## What NOT to Do

- **Don't get stuck on one question.** If a question is too broad, break it down into smaller ones.
- **Don't skip documentation.** The value of Drift is the trail of breadcrumbs it leaves.
- **Don't fix things blindly.** If you find a bug, log it first. Only fix it if it blocks the exploration itself.
- **Don't lose the thread.** Always relate findings back to the current or future questions.

## Completion

When this skill finishes (success, failure, or abandoned), emit a trace:

```bash
geno-trace emit \
  --skill geno-loops-drift \
  --status <success|failure|abandoned> \
  --tool-calls <approximate count> \
  --errors <count of tool/command errors> \
  --task <geno-notes task id, if any> \
  --scope project \
  --produced "<.geno/loops/drift/<timestamp>/session.md>"
```

- `success` = all questions answered, or max cycles reached with findings documented in session.md and questions.md
- `failure` = no questions answered after multiple cycles, or session ended without any findings logged
- `abandoned` = user stopped early

## Runtime

Pure markdown workflow. Uses `ScheduleWakeup` for self-pacing within `/loop`.
