---
name: geno-loops-vaults-fleet-status
description: >-
  Check fleet health: which loops are running, stale, missing, or have schema
  violations. Use when user asks to check the fleet, see which loops are dead,
  or wants a fleet status report.
argument-hint: "[--stale-only] [--tsv]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
---

# Vault Status

Run `resources/vault-status.sh` from the vault root:

```bash
cd ~/geno-vault
bash resources/vault-status.sh
```

## Options

| Flag | Effect |
|------|--------|
| _(none)_ | Human-readable table of all sessions |
| `--stale-only` | Only sessions that are stale (>1h), missing, or have schema violations |
| `--tsv` | Tab-separated output (used by vault-agent to regenerate `dashboard.md`) |

## Output columns

| Column | Meaning |
|--------|---------|
| SESSION | Loop session name (from `loops.yaml`) |
| PROJECT | Project name |
| LAST ITER | Timestamp of the most recent iteration note |
| AGE | Time since last iteration |
| LAYOUT | `root` (canonical) or `project` (legacy) or `missing` |
| SCHEMA | `ok` or `VIOLATION` (filename doesn't match `YYYY-MM-DDTHHMM-iter-NNN.md`) |

Exit 0 = all healthy. Exit 1 = anything stale, missing, or schema-violating.

## Interpreting results

- **stale (>1h)** — loop hasn't iterated in over an hour; likely dead or watchdog needs to run
- **missing** — no `iterations/` directory yet; loop never completed an iteration
- **VIOLATION** — iter note filename doesn't match the canonical schema; vault-agent will flag it in `dashboard.md`
- **project layout** — iter notes are under `<project>/<session>/iterations/` instead of `<session>/iterations/`; harmless but non-canonical

## Quick summary

After running, the script prints a footer:

```
stale (>1h): N   missing: N   schema violations: N
```

For a faster read, check `~/geno-vault/dashboard.md` — the vault-agent
regenerates it every 15 minutes.
