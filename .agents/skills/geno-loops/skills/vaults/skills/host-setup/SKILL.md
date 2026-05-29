---
name: geno-loops-vaults-host-setup
description: >-
  Run on the REMOTE host (where loops execute). Before doing anything, verifies
  that local and remote have the same geno-loops version installed. Starts the
  live renderer that tails JSONL session files and writes live.md per project.
  Use when setting up the remote host or restarting a dropped renderer.
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
---

# Vault — Remote

## 1. Version check (always first)

Before running anything on the remote, verify both machines have the same
`geno-loops` version:

```bash
bash resources/check-version.sh
```

This compares the `version` field in `genotools.yaml` on the local machine
against the same file on the remote host (via SSH). It exits non-zero and
prints a diff if they diverge.

If versions differ, sync the skills first:

```bash
# On local — install latest, then push to remote
npx --yes skills add . --agent '*' --global --yes
ssh "$REMOTE_HOST" "npx --yes skills add ~/.geno-tools/geno-loops/main --agent '*' --global --yes"
```

Then re-run `check-version.sh` to confirm.

## 2. Live renderer (JSONL → live.md)

Watches `.claude/projects/*/` JSONL files and writes
`~/geno-vault/<project>/live.md` as new lines appear.

```bash
tmux new-session -d -s live-renderer -c ~/geno-vault
tmux send-keys -t live-renderer "python3 tools/live-render.py" Enter
```

The watchdog restarts this session automatically during fleet rebuilds.

## What it produces

`~/geno-vault/<project>/live.md` — one file per project, overwritten
as new JSONL lines arrive.
