---
name: geno-loops-vaults-watchdog
description: >-
  Vault watchdog operations: inspect watchdog health, force a fleet rebuild,
  debug cron setup, and understand the rebuild sequence. Use when the fleet
  looks dead, tmux sessions are missing, or loops stopped iterating.
argument-hint: "[--status|--rebuild|--debug-cron]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
---

# Vault Watchdog

The watchdog (`tools/watchdog.sh`) runs every 5 minutes via cron. It counts
running `claude --dangerously` processes — if fewer than 5 are alive, it
kills everything and does a full fleet rebuild.

## Quick health check

```bash
# How many claude processes are currently alive?
ps aux | grep "[c]laude --dangerously" | wc -l

# What did the watchdog last do?
tail -20 ~/geno-vault/tools/watchdog.log

# Is the cron entry installed?
crontab -l | grep watchdog
```

## Cron entry (should be present)

```
*/5 * * * * cd ~/.geno-tools/geno-loops/vault && bash tools/watchdog.sh >> tools/watchdog.log 2>&1
```

To install if missing:

```bash
(crontab -l 2>/dev/null; echo "*/5 * * * * cd ~/.geno-tools/geno-loops/vault && bash tools/watchdog.sh >> tools/watchdog.log 2>&1") | crontab -
```

## Force a rebuild now

```bash
cd ~/geno-vault
bash tools/watchdog.sh
```

What the rebuild does:
1. `kill -9` all claude processes
2. `tmux kill-server`
3. Creates a new tmux session per loop from `loops.yaml`
4. Starts `claude --dangerously-skip-permissions` in each session
5. Waits 15 s for claude to boot, then sends the `/loop` prompt
6. Starts `live-renderer` tmux session

## Rebuild sequence (detailed)

```python
# Pseudocode from tools/watchdog.sh
for loop in loops.yaml["loops"]:
    tmux new-session -d -s {session} -c {work_dir}

for loop in loops:
    tmux send-keys: "claude --dangerously-skip-permissions"
    sleep 15
    tmux send-keys: Enter

for loop in loops:
    full_prompt = f"/loop {interval} {email_rule} {steer_rule} --- {prompt}"
    tmux send-keys: full_prompt
    sleep 2
    tmux send-keys: Enter

# Also restarts the live renderer
tmux new-session -d -s live-renderer
tmux send-keys: "python3 tools/live-render.py"
```

## Known issue: watchdog reverts working tree

The watchdog does NOT touch `tools/` directly, but the rsync
`sync-from-remote.sh` path can revert uncommitted edits.

Mitigation: vault-agent commits atomically in a single shell block
before any rsync tick can revert. See `tools/iter-restore.sh` for
recovery if this happens anyway.

## Boop-watcher (manual vault-agent nudge)

To wake the vault-agent immediately without waiting for its 15-min tick,
write anything to `boop.md`:

```bash
echo "$(date)" >> ~/geno-vault/boop.md
```

`tools/watch-boop.sh` polls `boop.md` every 2 s and restarts the
`t20-vault-agent` tmux session when it changes.

The boop-watcher must be running:

```bash
tmux new-session -d -s boop-watcher -c ~/geno-vault
tmux send-keys -t boop-watcher "bash tools/watch-boop.sh" Enter
```
