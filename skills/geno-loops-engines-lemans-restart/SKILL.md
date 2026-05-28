---
name: geno-loops-engines-lemans-restart
description: >-
  Kill and restart all Le Mans loops from the registry (~/.geno/geno-vault/loops.yaml).
  Reads the loop registry, kills all claude processes on the remote host,
  then relaunches every session with its configured prompt. Use when user
  says /geno-loops-lemans-restart or "restart all loops" or "restart the loops".
argument-hint: "[--kill-only] [--session <name>]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
---

# Restart Loops

Kill and restart all loops (or a single one) from the loop registry.

## Input

- **No args** — restart ALL loops from `~/.geno/geno-vault/loops.yaml`
- **`--kill-only`** — kill all loops but don't restart
- **`--session <name>`** — restart only one session (e.g., `t3-BlueTron`)

## Registry

The loop registry lives at `~/.geno/geno-vault/loops.yaml` (symlinked to
`/Volumes/HIL_DATA/erramos/geno/loops.yaml` = `/mnt/HIL_DATA/erramos/geno/loops.yaml` on z2).

It defines:
- `vault` — vault path on the remote
- `email_rule` — the email schedule rule prepended to all prompts
- `steer_rule` — the vault steering protocol prepended to all prompts
- `loops[]` — array of loop definitions, each with:
  - `session` — tmux session name
  - `project` — project name (maps to steer/ and outbox/ folders)
  - `work_dir` — working directory on the remote
  - `interval` — loop interval (e.g., `30m`)
  - `prompt` — the project-specific loop prompt

## Steps

### 1. Resolve remote host

Read `~/.geno/geno-loops/config/config.yaml` → `execution.remote_host` (default: `z2`).
Resolve hostname from `~/.geno/config.yaml` → `remote.hosts.<alias>.hostname`.

### 2. Kill

```bash
ssh <host> 'ps aux | grep "claude" | grep -v grep | awk "{print \$2}" | xargs kill -9 2>/dev/null || true'
```

Wait 3 seconds for processes to die.

If `--kill-only`, stop here and report.

### 3. Start claude in all sessions

```bash
ssh <host> 'for s in $(tmux list-sessions -F "#S" | grep -E "^t[0-9]"); do
  tmux send-keys -t $s "claude --dangerously-skip-permissions" Enter
done'
```

Wait 15 seconds for boot.

### 4. Dismiss welcome screens

```bash
ssh <host> 'for s in $(tmux list-sessions -F "#S" | grep -E "^t[0-9]"); do
  tmux send-keys -t $s Enter
done'
```

Wait 5 seconds.

### 5. Send loop prompts from registry

Read `~/.geno/geno-vault/loops.yaml`. For each loop entry, compose the full prompt:

```
/loop {interval} {email_rule} {steer_rule} --- {prompt}
```

Where `{steer_rule}` has `{project}` replaced with the loop's project name.

Send via:
```bash
ssh <host> 'tmux send-keys -t <session> "<full prompt>" Enter'
sleep 2
ssh <host> 'tmux send-keys -t <session> Enter'
```

### 6. Verify

Count sessions with child processes. Report success.

### Single Session Mode

If `--session <name>` is provided:
1. Kill only that session's claude process
2. Restart only that one
3. Send only its prompt from the registry

## Output

Print a summary table:
```
✓ t3-BlueTron (BlueTron) — started
✓ t4-BlueChill (BlueChill) — started
...
=== All N loops started ===
```

## Important

- **Never use `tmux capture-pane`** — it kills sessions.
- The registry is the single source of truth. Edit `~/.geno/geno-vault/loops.yaml` to change prompts, add loops, or remove them.
- After editing the registry, run `/geno-loops-restart` to apply changes.
