---
name: geno-loops-engines-dynamic
description: >-
  Adaptive self-paced loop — wraps /loop in dynamic mode. Starts at 10
  minutes, measures each iteration's duration, then EMA-steps the wake
  interval toward `duration + buffer` so the next firing lands just
  after the previous one finishes. Use when user says
  /geno-loops-dynamic or /gl-dyn.
argument-hint: "<prompt> [--start <s>] [--buffer <s>] [--min <s>] [--max <s>] [--alpha <0..1>] [--max-iterations <n>] | --resume <session-id> | --stop <session-id>"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
observability:
  success_signal: "max-iterations reached, user stopped, or wrapped prompt signals completion"
  failure_signals:
    - "iteration runs longer than max interval (3600s) repeatedly without converging"
    - "ScheduleWakeup repeatedly fails to schedule the next firing"
    - "state file becomes unreadable mid-session"
  knowledge_reads:
    - ".geno/loops/dynamic/<session>/state.json"
    - "active session pointer at .geno/loops/dynamic/active.json"
  knowledge_writes:
    - ".geno/loops/dynamic/<session>/state.json (per-iteration timing + interval history)"
    - ".geno/loops/dynamic/<session>/session.md (human-readable log)"
---

# Dynamic Loop

> Requires a geno-specs spec — see umbrella.

A self-paced wrapper around `/loop`'s dynamic mode (no fixed interval). Instead of asking the user to pick an interval up-front, this loop:

1. Starts at **10 minutes** (configurable).
2. Measures how long each iteration of the wrapped prompt actually takes.
3. EMA-steps the interval toward `duration + buffer` — fast enough to keep cadence tight, smooth enough to absorb a single slow iteration.

The wake-up uses `ScheduleWakeup`, which is `/loop`'s dynamic-mode mechanism. So this skill behaves like `/loop <prompt>` (no interval), except the model isn't free-styling the delay each turn — it's following a deterministic stepping rule grounded in observed timings.

## Input

Parse `$ARGUMENTS`:

- **`<prompt>`** (positional, required for new sessions) — the prompt or slash command to run each iteration (e.g. `"check CI and fix lint drift"`, `"/geno-dev-prs-check"`)
- **`--start <s>`** — initial interval in seconds. Default `600` (10 min).
- **`--buffer <s>`** — buffer added on top of observed duration. Default `60`.
- **`--min <s>`** — floor for the interval. Default `60` (matches `ScheduleWakeup` clamp).
- **`--max <s>`** — ceiling for the interval. Default `3600` (matches `ScheduleWakeup` clamp).
- **`--alpha <0..1>`** — EMA step factor; `0` = never adapt, `1` = jump fully to last observation. Default `0.5`.
- **`--max-iterations <n>`** — stop after n iterations. Default `48` (≈ 8h at 10min cadence).
- **`--resume <session-id>`** — internal flag used by `ScheduleWakeup` to continue an existing session. Do not pass manually.
- **`--stop <session-id>`** — cancel the active loop and write a final summary.

## When to Use

- You want a recurring task but don't know the right interval up-front.
- The wrapped prompt has variable runtime (some iterations finish in seconds, others in minutes).
- You want the loop to "ride the iteration" — wake just after the previous one ends, not on a fixed wall-clock cadence.
- You want a single command (`/gl-dyn`) for self-paced loops without baking the timing math into every prompt.

Do **not** use when:
- The wrapped task needs to fire on a strict wall-clock cadence (use `/loop 5m ...` or `CronCreate` directly).
- You need active implementation work, not periodic polling (use Turbocharge or Cruise).
- The work is one-shot or non-recurring (use `ScheduleWakeup` directly).

## Workflow

### 1. Dispatch on argument shape

```
if --stop <id>:        → go to "Stop"
if --resume <id>:      → go to "Resume iteration"
else:                  → go to "Start new session"
```

### 2. Start new session

1. Generate session id: `dyn-<YYYYMMDD-HHMM>` (e.g. `dyn-20260523-1430`).
2. Create directory: `.geno/loops/dynamic/<session-id>/`.
3. Parse flags, compute initial config:
   ```json
   {
     "session_id": "dyn-20260523-1430",
     "prompt": "<the user's wrapped prompt verbatim>",
     "config": {
       "start_s": 600,
       "buffer_s": 60,
       "min_s": 60,
       "max_s": 3600,
       "alpha": 0.5,
       "max_iterations": 48
     },
     "state": {
       "target_interval_s": 600,
       "iterations": [],
       "started_at": "<ISO 8601 UTC>",
       "stopped": false,
       "stop_reason": null
     }
   }
   ```
4. Write `state.json` and a `session.md` header:
   ```markdown
   # Dynamic Loop — <session-id>
   ## Config
   - Prompt: <prompt>
   - Start: 600s | Buffer: 60s | Min: 60s | Max: 3600s | Alpha: 0.5
   - Max iterations: 48

   ## Iterations
   ```
5. Update active pointer: write `{"session_id": "<id>"}` to `.geno/loops/dynamic/active.json` (overwrites any prior pointer).
6. Run iteration #1 (go to step 4 below).

### 3. Resume iteration

1. Read `.geno/loops/dynamic/<session-id>/state.json`.
2. If `state.stopped` is `true`, exit with no work — the loop was stopped externally.
3. If `iterations.length >= config.max_iterations`, mark stopped (`stop_reason: "max-iterations"`), write final summary, exit.
4. Run the next iteration (step 4 below).

### 4. Run one iteration

1. Record `iteration_start = now()` (ISO 8601 UTC, also capture epoch seconds for math).
2. Execute the wrapped prompt **in the main thread** (not a subagent, to mirror `/loop`'s behavior). Treat the prompt the same way `/loop` would — if it starts with `/`, dispatch as a slash command via `Skill`; otherwise, treat as a natural-language directive and do the work.
3. Record `iteration_end = now()` and compute `duration_s = iteration_end - iteration_start`.
4. Compute the new target interval (EMA step):
   ```
   observed     = duration_s + buffer_s
   raw_next     = (1 - alpha) * current_target + alpha * observed
   next_target  = clamp(raw_next, min_s, max_s)
   ```
5. Append to `state.iterations`:
   ```json
   {
     "n": <iteration number>,
     "start": "<ISO>",
     "end": "<ISO>",
     "duration_s": <number>,
     "interval_used_s": <current_target before this iteration>,
     "next_interval_s": <next_target>,
     "outcome": "ok" | "wrapped-prompt-error" | "skipped"
   }
   ```
6. Update `state.target_interval_s = next_target` and write `state.json`.
7. Append to `session.md`:
   ```markdown
   ### Iteration <n> — <iteration_start>
   - Duration: <duration_s>s
   - Used interval: <interval_used>s
   - Next interval: <next_target>s  (observed: <observed>s, alpha: <alpha>)
   - Outcome: <ok | error: ...>
   ```
8. Schedule the next firing:
   ```
   ScheduleWakeup(
     delaySeconds = next_target,
     prompt       = "/geno-loops-dynamic --resume <session-id>",
     reason       = "dyn loop iter <n+1>: target <next_target>s based on prev <duration_s>s"
   )
   ```
9. Exit (the wake-up will re-enter this skill).

### 5. Stop

1. Read `state.json`. If already stopped, just confirm to user.
2. Mark `stopped: true`, `stop_reason: "user-stop"`, write `state.json`.
3. Append a closing block to `session.md`:
   ```markdown
   ## Summary
   - Iterations: <n>
   - Mean duration: <avg>s
   - Final interval: <last>s
   - Stopped: <reason>
   ```
4. Clear `active.json` if it points to this session.
5. Report to user: iterations completed, final converged interval.

## Stepping Behavior

The EMA with `alpha = 0.5` gives a half-life of ~1 iteration: a single slow run pulls the target halfway toward it; two consecutive slow runs converge fully. This is intentionally aggressive — the goal is to ride iteration time, not smooth out variance over many cycles.

For more conservative stepping (smooth out flaky iterations), use `--alpha 0.25` or lower. For stricter "wake exactly when done" behavior, use `--alpha 1.0` (but expect oscillation if iterations vary).

| alpha | Behavior | Use case |
|-------|----------|----------|
| 0.25  | Slow convergence, smooths noise | Iterations with high variance |
| 0.5   | Balanced (default) | Most cases |
| 0.75  | Quick to track changes | Iterations with steadily growing/shrinking time |
| 1.0   | Always = last observation + buffer | Reactive, noisy, simplest mental model |

## Convergence Examples

Starting at 600s, buffer=60s, alpha=0.5:

| Iter | Actual duration | Used interval | Next interval |
|------|-----------------|---------------|---------------|
| 1    | 30s             | 600s          | (600+90)/2 = 345s |
| 2    | 35s             | 345s          | (345+95)/2 = 220s |
| 3    | 40s             | 220s          | (220+100)/2 = 160s |
| 4    | 35s             | 160s          | (160+95)/2 = 128s |
| 5    | 38s             | 128s          | (128+98)/2 = 113s |

Within ~5 iterations the interval is hugging duration+buffer.

## Storage

```
.geno/loops/dynamic/
├── active.json                          # pointer to currently active session
└── <session-id>/
    ├── state.json                       # config + per-iteration history
    └── session.md                       # human-readable log
```

## Error Recovery

- **Wrapped prompt errors mid-iteration** — capture the error, log `outcome: "wrapped-prompt-error"`, but still compute next interval based on duration. Do not stop the loop on a single failure; the prompt may be transient.
- **State file unreadable on resume** — write a recovery note to `session.md`, attempt to reconstruct `target_interval_s` from the last log entry, and continue. If recovery fails, mark stopped with `stop_reason: "state-corrupt"` and report.
- **`ScheduleWakeup` returns an error** — retry once with a slightly jittered delay (`next_target + random(1..10)s`). If it fails twice, mark stopped with `stop_reason: "schedule-failed"`.
- **Iteration takes longer than `max_s`** — the next interval clamps to `max_s` but log a warning. If 3 consecutive iterations exceed `max_s`, stop with `stop_reason: "iteration-exceeds-max"` and surface to user — the workload is too heavy for self-pacing.
- **User runs `/gl-dyn <new-prompt>` while a session is already active** — confirm with `AskUserQuestion` whether to stop the existing session first or run side-by-side. Default to stopping the prior session unless the user opts otherwise.

## What NOT to Do

- **Don't run iterations in subagents by default.** `/loop` runs in the main thread; preserve that semantics. (A future `--agent` flag could opt in.)
- **Don't ignore the clamps.** `ScheduleWakeup` clamps to [60, 3600]; the skill must too, or the math drifts out of sync.
- **Don't poll harder than the iteration takes.** If duration is 5s and buffer is 60s, the floor is 65s — never schedule below `duration + buffer` even if `min_s` allows it.
- **Don't lose state across iterations.** Every iteration must read and write `state.json`. The active pointer is convenience; the session dir is truth.
- **Don't add a fallback "if state missing, start fresh" branch on resume.** A missing state file on `--resume` is a bug, not a feature — log and exit, don't silently restart.

## Completion

When this skill finishes (success, stop, or fatal error), emit a trace if `geno-trace` is available:

```bash
geno-trace emit \
  --skill geno-loops-dynamic \
  --status <success|failure|abandoned> \
  --tool-calls <approximate count> \
  --errors <count of tool/command errors> \
  --produced ".geno/loops/dynamic/<session-id>/session.md"
```

- `success` = max-iterations reached cleanly, or user stopped after the loop converged
- `failure` = state corruption, schedule-failed, or iteration-exceeds-max stop
- `abandoned` = user stopped early before any meaningful convergence

## Runtime

No venv or scripts — pure markdown workflow. Uses `ScheduleWakeup` for self-paced firing and a JSON state file for cross-iteration memory.

## Related

- `/loop <interval> <prompt>` — fixed-cadence loop. Use when interval is known.
- `/loop <prompt>` — fully model-paced (no stepping rule). Use when you want the model free-styling the delay.
- `/geno-loops-autopilot` — different shape: monitors signals on a fixed cron, fixes safe drift. Not adaptive.

## Alias

If `/geno-loops-dynamic` is too long to type, install `/gl-dyn` via:

```
/geno-alias /gl-dyn /geno-loops-dynamic
```
