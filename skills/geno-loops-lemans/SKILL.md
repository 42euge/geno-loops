---
name: geno-loops-lemans
description: >-
  Endurance loop — long-haul, iteration-on-worktree pattern. Each iteration
  is a single small, verified, merged-to-main change with tests, an entry
  in ITERATION_LOG.md, and regenerated reports. Designed to sustain quality
  over many hours/days of autonomous work, like a 24h race. Requires a
  geno-specs YAML spec as the durable goal. Use when user says
  /geno-loops-lemans (alias /gl-lemans).
argument-hint: "--spec <file> [--interval <duration>] [--worktree-root <dir>] [--report-cmd <cmd>]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
observability:
  success_signal: "iteration merged to main with passing tests, log entry, and regenerated reports"
  failure_signals:
    - "tests fail and cannot be made green within the iteration"
    - "ff merge to main is blocked (main moved underneath the worktree)"
    - "report regeneration command fails twice"
    - "spec is missing or invalid — loop refuses to start"
  knowledge_reads:
    - "geno-specs YAML spec (durable goal)"
    - "ITERATION_LOG.md (history of prior iterations)"
    - "geno-notes tasks (active, project scope)"
  knowledge_writes:
    - "ITERATION_LOG.md (one ## section per iteration)"
    - "iter-reports/ (regenerated HTML, plots, indexes)"
    - "geno-notes journal (one milestone per merged iteration)"
    - ".geno/loops/lemans/<session>/session.md"
---

# Le Mans Loop

Endurance loop — long-haul, iteration-on-worktree pattern. Le Mans is a 24h
race, and that is the flavor: sustained, high-quality, small-step improvement
over many hours or days. Each iteration ships exactly one logical change as a
worktree branch, with tests, a log entry, and regenerated reports, then merges
it ff-only to main and reschedules itself.

This is not Turbocharge (which converges to zero failures against a fixed test
spec) or Cruise (which executes a finite plan). Le Mans is open-ended: the
spec describes a durable goal (the project's "championship"), and each
iteration picks the next-best small improvement that moves toward it.

## Input

Parse `$ARGUMENTS` for:

- **`--spec <file>`** (required) — path to a geno-specs YAML spec describing
  the durable goal. Conventional location: `.specs/features/<slug>.genospecs.yaml`.
  If missing, the loop refuses to start and points the user at
  `/geno-specs-init` (which runs superpowers brainstorming to author one).
- **`--interval <duration>`** — wake interval between iterations (default `30m`).
  Examples: `15m`, `45m`, `1h`. Used by `ScheduleWakeup`.
- **`--worktree-root <dir>`** — where to create per-iteration worktrees
  (default: `<repo-parent>/<repo-name>-worktrees/`).
- **`--report-cmd <cmd>`** — command to regenerate reports after each iteration.
  Default: probe for one of, in order:
    1. `python scripts/generate_iteration_reports.py`
    2. `make iter-reports`
    3. `npm run iter-reports`
  If none exist, the loop will create a minimal `scripts/generate_iteration_reports.py`
  stub on first run and ask the user to flesh it out.

If `--spec` is absent, use `AskUserQuestion`:

> Le Mans requires a geno-specs spec as the durable goal.
> Options:
>   1. Point me at an existing spec file
>   2. Run /geno-specs-init now to author one (uses superpowers brainstorming)
>   3. Cancel

Do not invent a spec inline. The spec is the contract for the entire run.

## When to Use

- You have a **durable, long-horizon goal** described in a geno-specs spec
- You want **many small, individually-verified, individually-merged** improvements
- You want a **publishable audit trail** — one log section per iteration,
  HTML reports, browsable history
- The project is in a state where **ff merge to main is realistic** (low contention,
  one driver) — typically a personal project, research repo, or solo workstream
- You're willing to let the loop run for hours or days

Do **not** use Le Mans when:

- The change is a **single small tweak** — use Cruise (one plan, done) or just do it
- The work is **pure exploration** with no clear goal yet — use Drift, then come back
- You're **babysitting CI** for someone else's PRs — use Autopilot
- The codebase has **multiple concurrent committers on main** — ff-only merging
  will thrash; resolve coordination first
- You don't have a spec and don't want one — Le Mans is spec-mandatory by design

## Spec Dependency

All `geno-loops` invocations are spec-driven. Le Mans is the most opinionated:
the spec is the championship, every iteration is a lap, and the log is the
race report. The spec must exist before the loop starts.

Conventional layout:

```
<repo>/
├── .specs/
│   └── features/
│       └── <slug>.genospecs.yaml      # durable goal
├── ITERATION_LOG.md                    # one ## section per iter (created on iter-001)
├── iter-reports/                       # regenerated each iteration
│   ├── index.html
│   ├── iter-001.html …
│   └── testing.html
└── scripts/
    └── generate_iteration_reports.py   # report regenerator (configurable)
```

If the spec exists but `ITERATION_LOG.md` does not, create it on iter-001 with
a header describing the spec and the start date.

## Workflow

### 0. Bootstrap (run once at session start)

1. Validate `--spec` exists and parses as a geno-specs YAML. If not, refuse.
2. Resolve repo root (`git rev-parse --show-toplevel`).
3. Resolve worktree root (`--worktree-root` or `<repo-parent>/<repo-name>-worktrees/`).
   Create the directory if it doesn't exist.
4. Resolve report command (`--report-cmd` or probe). If absent, scaffold a stub
   and warn the user.
5. Create session directory:
   ```
   .geno/loops/lemans/<YYYYMMDD-HHMM>/
   ├── session.md
   ├── spec.yaml          # symlink or copy of the spec
   └── iters/             # per-iter notes (mirrors ITERATION_LOG.md sections)
   ```
6. Determine the next iteration number `NNN` by scanning `ITERATION_LOG.md`
   for the highest existing `## iter-NNN` header (or 1 if none).
7. Write `session.md` header:
   ```markdown
   # Le Mans Session — <YYYY-MM-DD HH:MM>
   ## Config
   - Spec: <spec path>
   - Worktree root: <dir>
   - Report cmd: <cmd>
   - Interval: <duration>
   - Starting at iter-<NNN>

   ## Log
   ```

### 1–11. Per-iteration body

Each iteration is one logical change. Steps:

#### 1. Read the log; pick the next item

- Read `ITERATION_LOG.md` (if missing, treat as empty).
- Read the spec.
- Pick the next bug or improvement. Order of preference:
    1. An item explicitly listed in the spec or in a `## Bug list` / `## Goals`
       section of `ITERATION_LOG.md` that is not yet done.
    2. A regression or flake observed in the most recent test runs.
    3. A small architecture improvement that moves toward a spec goal.
- Act on agent judgment when the next item is not specified — small, real,
  verifiable changes always beat large speculative ones.
- Write a one-line plan to `session.md`: `iter-NNN: <slug> — <one-sentence intent>`.

#### 2. Create the worktree

```bash
git -C <repo> worktree add <worktree-root>/iter-<NNN>-<slug> -b iter-<NNN>-<slug>
```

`<slug>` is a kebab-case summary (e.g. `fix-vad-threshold-clamp`,
`refactor-stt-streaming-buffer`). Keep it short.

All subsequent steps run with cwd inside the worktree.

#### 3. Implement a single small change

- One bug or one small improvement per iteration. Resist combining.
- Verified-before-fix: when fixing a bug, write or extend a `pytest` (or the
  project's test framework) that **reproduces the bug first**, watch it fail,
  then fix.
- Do not modify the spec. Do not modify `ITERATION_LOG.md` yet.
- Do not touch unrelated files. If you notice an adjacent issue, log it as
  `geno-notes note "<bug>" --kind bug --project` and move on.

#### 4. Write tests

- Unit tests are the default.
- Integration tests are encouraged for cross-component changes; place them
  under `tests/integration/` (the geno-voice convention) if the project
  doesn't have its own layout.
- Tests must be deterministic. Flaky tests are a regression and must be
  fixed in the same iteration or reverted.

#### 5. Run the FULL suite

- Run the entire project test suite (not just the new tests).
- All tests must pass before merge. No exceptions.
- If a pre-existing test fails for unrelated reasons, you have two options:
    - Fix it as part of this iteration (and call that out in the log).
    - Revert your change, log the broken test as a separate iter target,
      and start over.

#### 6. Commit with a multi-paragraph message

Format:

```
iter-NNN: <one-line summary>

Bug / motivation:
<paragraph describing the bug, regression, or improvement>

Fix:
<paragraph describing what changed and why>

Tests:
<paragraph describing what the tests cover, including any new
integration tests>
```

No squashing. One commit per iteration. The commit is the canonical record;
the log entry is the human-readable index.

#### 7. Merge to main with ff-only

```bash
git -C <repo> checkout main
git -C <repo> pull --ff-only       # only if main tracks a remote
git -C <repo> merge --ff-only iter-<NNN>-<slug>
```

If ff-only fails, main has moved underneath the worktree. Recovery:

1. `cd` into the worktree.
2. `git rebase main`.
3. Re-run the full test suite (step 5).
4. Retry the ff merge.

Never `git merge --no-ff`, never squash, never force-push. The linear history
is the race report.

#### 8. Append the iteration entry to ITERATION_LOG.md

Append a section to the **end** of `ITERATION_LOG.md`:

```markdown
## iter-NNN — <slug-as-title>

- **Date:** <YYYY-MM-DD>
- **Branch:** iter-NNN-<slug>
- **Commit:** <short SHA>

### What changed
<2–6 sentences>

### Why
<2–4 sentences tying back to the spec or to a real observed bug>

### Tests
<bullet list of new/changed tests, including any tests/integration/ entries>

### Verification
<command(s) you ran to verify, e.g. `pytest -q`, `python -m geno_voice.smoke`>
```

Commit the log update directly on main (not in the worktree branch — that
branch is already merged and gone). Use a message of the form
`iter-NNN: log entry`.

#### 9. Regenerate reports

Run the report command (default `python scripts/generate_iteration_reports.py`).
This must regenerate at minimum:

- `iter-reports/index.html` — list of all iterations with links
- `iter-reports/iter-NNN.html` — one page per iteration
- `iter-reports/testing.html` — test-count and pass-rate trends, with SVG
  plots if the project has the data

If the report command fails:

- Retry once.
- If it fails again, log the failure to `session.md`, log a `geno-notes note --kind bug`,
  and **continue the loop**. Reports are valuable but not blocking — losing them
  for one iteration is recoverable; halting the race is not.
- Two consecutive report-regeneration failures escalate to a stop signal; the
  loop refuses further iterations until the user fixes the report tool.

Commit the regenerated `iter-reports/` directory on main with a message of
the form `iter-NNN: regenerate reports`.

#### 10. Remove the worktree

```bash
git -C <repo> worktree remove <worktree-root>/iter-<NNN>-<slug>
git -C <repo> branch -D iter-<NNN>-<slug>      # branch is merged; safe to delete
```

The branch's content lives on as a fast-forward in main's history. The
worktree directory is disposable.

#### 11. Reschedule

Append a milestone to geno-notes:

```bash
geno-notes note "Le Mans iter-NNN merged: <slug>" --kind milestone --project
```

Then call `ScheduleWakeup` with the configured interval. On wake, increment
`NNN` and repeat from step 1.

If running under cron instead of `ScheduleWakeup`, exit cleanly — cron will
re-invoke the loop.

## Reporting (required)

Le Mans is a public-history loop. Report regeneration is **required**, not
optional. The default `scripts/generate_iteration_reports.py` should produce:

- An index page that lists every `## iter-NNN` section in `ITERATION_LOG.md`
- One page per iteration with the log section rendered to HTML
- A `testing.html` page with at least:
    - Test count over time
    - Pass-rate over time (should always be 1.0 if the loop is doing its job)
    - SVG plots inline (no external image deps)

Different repos may have different report tooling — `--report-cmd` is the
override. The contract is: **after every merged iteration, the published
report reflects the new iteration**.

## Ship Discipline

Non-negotiable rules:

1. **Tests must pass.** Full suite, every iteration, before merge.
2. **One logical change per iteration.** If it can be split, split it across
   iterations.
3. **ff-only merges.** No squash, no `--no-ff`, no force-push.
4. **Auditable trail.** Every merged iteration has: a commit, a log section,
   a report page, and a geno-notes milestone.
5. **Spec is sacred.** Never modify the spec inside the loop. If the spec
   needs to change, stop the loop and ask the user.

## Error Recovery

- **Tests won't go green within the iteration:** revert all changes, log the
  attempt to `session.md` with what went wrong, and pick a different next item
  on the next iteration. Do not merge red.
- **ff merge blocked:** rebase the worktree branch onto main, re-run tests,
  retry. If the rebase introduces new conflicts that can't be resolved
  cleanly, abort the iteration (delete branch + worktree, no log entry) and
  pick a different item next iteration.
- **Worktree directory dirty / leftover from a crashed iteration:**
  `git worktree remove --force` and `git branch -D` the leftover branch, then
  start fresh.
- **Report regeneration fails twice in a row:** stop the loop and surface the
  error. Reports are required for the audit trail.
- **`geno-notes` CLI failures:** continue the loop, but log the failure in
  `session.md`. Journal failures are not blocking.
- **`ScheduleWakeup` not available:** fall back to exiting cleanly (cron mode)
  or to a `sleep` for the configured interval; the user's harness chooses.

## What NOT to Do

- **Don't merge without tests passing.** Ever.
- **Don't squash or `--no-ff`.** The linear, per-iteration history is the
  product.
- **Don't combine multiple bugs in one iteration.** Each iteration must be
  isolatable, revertable, and individually understandable.
- **Don't modify the spec inside the loop.** Stop and tell the user.
- **Don't skip the log entry or the report regen.** They are the audit trail.
- **Don't keep going after the report tool has been broken for two iterations.**
  Fix it first.
- **Don't run Le Mans on a shared `main` with multiple committers.** It will
  thrash. Use a feature branch protected from outside writes if you must.

## Completion

Le Mans is open-ended; it does not "complete" by hitting an iteration count.
Stop conditions:

- The user stops the loop.
- The spec is marked done (`status: complete` in the geno-specs YAML).
- Two consecutive report-regen failures.
- A test failure that cannot be resolved within the iteration **and** the
  loop has tried the same area three iterations in a row.

When the loop stops, emit a trace:

```bash
geno-trace emit \
  --skill geno-loops-lemans \
  --status <success|failure|abandoned> \
  --tool-calls <approximate count> \
  --errors <count of tool/command errors> \
  --task <geno-notes task id, if any> \
  --scope project \
  --produced "ITERATION_LOG.md, iter-reports/, .geno/loops/lemans/<session>/session.md"
```

- `success` = spec marked done, all iterations merged with passing tests
- `failure` = report tool broken, or stuck region in code with no progress
- `abandoned` = user stopped the loop early

## Runtime

No venv or scripts of its own — pure markdown workflow over `git worktree`,
`pytest` (or project equivalent), and `ScheduleWakeup` (or cron). Uses
`geno-specs` for the durable goal and `geno-notes` for milestones.
