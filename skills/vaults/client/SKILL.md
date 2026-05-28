---
name: geno-loops-vaults-client
description: >-
  Run on the LOCAL machine (where Obsidian lives). Starts bidirectional rsync
  daemons that push steering edits to the remote host and pull iter notes back.
  Use when setting up sync on a new machine or restarting a dropped sync.
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
---

# Vault Sync — Local

Run these on the machine where you edit the vault in Obsidian.
`remote_host` and `vault_dir` are read from `~/.geno-tools/geno-loops/config/config.yaml`.

## Start bidirectional sync

```bash
cd ~/geno-vault
bash tools/sync-both.sh &
```

Launches two background rsync loops:
- `sync-to-remote.sh` — local → remote every 3 s
- `sync-from-remote.sh` — remote → local every 5 s

Stop with `Ctrl-C` or kill the background PID.

## Sync rules

Both scripts exclude `.git/`, `.obsidian/`, `node_modules/`, and each other.

`sync-to-remote.sh` uses `--delete` — local is authoritative for tracked files.  
`sync-from-remote.sh` does NOT use `--delete` — remote iter notes must not vanish locally.

## Troubleshooting drift

```bash
REMOTE_HOST=$(awk '/^remote_host:/ {print $2}' ~/.geno-tools/geno-loops/config/config.yaml)
VAULT=$(awk '/^vault_dir:/ {print $2}' ~/.geno-tools/geno-loops/config/config.yaml | sed "s|~|$HOME|")

# Force push local state to remote (dry run first)
rsync -n -av "$VAULT/" "$REMOTE_HOST:$VAULT/" | head -40
rsync -az --delete --exclude='.git' --exclude='.obsidian' --exclude='node_modules' \
  "$VAULT/" "$REMOTE_HOST:$VAULT/"
```

**Do not run `git pull` or `git push` across hosts** — sync is rsync-only.
