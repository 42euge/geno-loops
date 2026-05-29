---
name: geno-loops-vaults-fleet
description: >-
  Fleet management for the geno-vault loop registry. Covers adding/removing
  loops, inspecting fleet health, restarting stale sessions, and editing
  loops.yaml. Use when user wants to add a new loop, check which loops are
  dead, or change an existing loop's interval or prompt.
argument-hint: "[add|remove|status|restart] [--session <name>]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
---

# Vault Fleet Management

## Key files

| File | Purpose |
|------|---------|
| `VAULT/loops.yaml` | Authoritative fleet registry |
| `VAULT/tools/vault-status.sh` | Per-session liveness check |
| `VAULT/tools/watchdog.sh` | Cron watchdog (cron `*/5`) — rebuilds dead fleet |
| `VAULT/dashboard.md` | Last-regenerated fleet snapshot |

`VAULT` = `~/geno-vault` (symlinked from `geno-vault-system/vault/`).

---

## Status check

Use the `vault-status` skill to check fleet health.

---

## Adding a loop

1. Open `loops.yaml` and append under `loops:`:

```yaml
  - session: my-project
    project: MyProject
    work_dir: ~/code/my-project
    interval: 30m
    prompt: "Read ITERATION_LOG.md. Worktrees, ff-only merge, tests. <goal>."
```

2. Create the session directory in the vault:

```bash
mkdir -p ~/.geno-tools/geno-loops/vault/my-project/iterations
```

3. The next watchdog run (within 5 min) will pick up the new session.
   Or restart it manually — see **Manual fleet restart** below.

---

## Removing a loop

1. Remove the entry from `loops.yaml`.
2. Kill the tmux session: `tmux kill-session -t <session-name>`.
3. Optionally archive the session dir: `mv ~/geno-vault/<session> ~/geno-vault/archive/`.

---

## Manual fleet restart

The watchdog normally handles this, but to force an immediate rebuild:

```bash
cd ~/geno-vault
bash tools/watchdog.sh
```

This kills all claude processes, rebuilds tmux sessions, and re-issues
`/loop` commands for every entry in `loops.yaml`.

---

## Email window

All loops respect `tools/email-window.sh` — check it before any
`send_email` call:

```bash
tools/email-window.sh --print   # INSIDE or OUTSIDE: <reason>
tools/email-window.sh --json    # structured output
tools/email-window.sh           # exit 0=inside, 1=outside
```

Window: **06:00–18:30 Pacific Time**, every day.

---

## Steering a specific loop

Edit the session's `main.md` under `## Steering (user-editable)`.
The loop reads this at the start of each iteration via `detect-steering.sh`.

For the vault-agent specifically: `~/geno-vault/t20-vault-agent/main.md`.

---

## Steer rule (injected into every loop prompt by watchdog)

```
VAULT=~/geno-vault. Before each iteration: read VAULT/{session}/main.md —
if the user edited it, follow their instructions. After each iteration:
write iteration note to VAULT/{session}/iterations/YYYY-MM-DDTHHMM-iter-NNN.md
(Pacific Time). Update VAULT/{session}/main.md with current status.
Do NOT create any other folders in the vault.
```
