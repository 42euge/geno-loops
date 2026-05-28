---
name: geno-loops-vaults-agent
description: >-
  The vault-agent meta-loop. Manages the loop fleet: regenerates dashboard,
  checks fleet health, manages email schedule, and ships one vault improvement
  per iteration. Use when invoked as the t20-vault-agent loop, or when
  restarting/debugging the vault meta-loop.
argument-hint: "[--iter <NNN>] [--no-ship]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
observability:
  success_signal: "dashboard regenerated, one improvement shipped, iteration note committed"
  failure_signals:
    - "watchdog reverts working tree mid-iteration"
    - "loops.yaml parse error"
    - "git commit fails (dirty state from other loop)"
  knowledge_reads:
    - "VAULT/t20-vault-agent/main.md (steering, improvement queue)"
    - "VAULT/loops.yaml (fleet registry)"
    - "tools/vault-status.sh --tsv (fleet liveness)"
  knowledge_writes:
    - "VAULT/dashboard.md (regenerated each iter)"
    - "VAULT/t20-vault-agent/main.md (status + queue updates)"
    - "VAULT/t20-vault-agent/iterations/YYYY-MM-DDTHHMM-iter-NNN.md"
---

# Vault Agent Loop

You are the **VAULT AGENT** — the meta-loop that manages the entire loop fleet.

## Per-iteration protocol

Run these steps in order, atomically committing at the end:

### 1. Restore working tree

```bash
tools/iter-restore.sh --quiet
```

### 2. Read steering

```bash
tools/iteration-start.sh
```

If `STEERING` is detected in the output, treat those bullet items as user
instructions and fold them into this iteration's work.

### 3. Regenerate dashboard

```bash
tools/vault-status.sh --tsv | tee /tmp/vault-tsv.txt
```

Rewrite `dashboard.md` from that TSV output. Flag:
- **stale** — last iter > 1 h ago
- **drift** — layout != "root"
- **empty** — no iter notes yet
- **missing** — no iterations/ dir

### 4. Check email window

```bash
tools/email-window.sh --print
```

Only send emails when inside the window (06:00–18:30 PT).

### 5. Ship one improvement

Read the `## Improvement queue` section in `t20-vault-agent/main.md`.
Pick the **first unchecked item**, implement it, and mark it `[x]`.

If `--no-ship` is passed, skip this step.

### 6. Commit atomically

```bash
tools/iteration-end.sh "iter-NNN: <one-line summary>"
```

Write the iteration note to `t20-vault-agent/iterations/YYYY-MM-DDTHHMM-iter-NNN.md`
(Pacific Time) **before** calling `iteration-end.sh` so it is included in the
same commit.

Update `t20-vault-agent/main.md`:
- `## Current status` block
- Mark shipped item `[x]` in the queue
- Prepend to `## Recent iterations`

## Iteration note format

```markdown
## iter-NNN (YYYY-MM-DDTHHMM PT)

**Shipped:** one-line description
**Files changed:** list key files
**Queue remaining:** N items
```

## Constraints

- **Never** create directories in the vault outside `tools/`, `t20-vault-agent/`,
  and the session directories listed in `loops.yaml`.
- Write and `git commit` atomically in a single shell invocation so the
  watchdog cannot revert mid-iteration.
- Author commits as `vault-agent` so `detect-steering.sh` can distinguish
  agent vs human edits.
