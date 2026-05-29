---
name: geno-loops-vaults
description: >-
  Vault track — persistent loop fleet with a shared vault directory, iteration
  notes, steering, and a meta-loop (vault-agent) that manages the fleet.
  Parent skill for all vault subskills.
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
---

# Vaults

The vault track runs a fleet of loops that share a vault directory
(`vault_dir` in `~/.geno-tools/geno-loops/config/config.yaml`). Each loop writes
iteration notes, reads steering from `main.md`, and is managed by the
vault-agent meta-loop.

## Client

| Skill | Purpose |
|-------|---------|
| `geno-loops-vaults-client` | rsync daemons, Obsidian sync (run on client machine) |

## Skills

| Skill | Purpose |
|-------|---------|
| `geno-loops-vaults-fleet` | Add/remove/restart loops in `loops.yaml` |
| `geno-loops-vaults-fleet-status` | Check which loops are running, stale, or missing |
| `geno-loops-vaults-host-setup` | Version check, live renderer (first-time host setup) |
| `geno-loops-vaults-agent` | Meta-loop: dashboard, email, improvement queue |
| `geno-loops-vaults-iteration` | Per-session iteration protocol and filename schema |
| `geno-loops-vaults-watchdog` | Watchdog health, cron setup, force rebuild |
| `geno-loops-vaults-remote-status` | Show live processes, tmux sessions, iteration recency, and dashboard on a remote host |
