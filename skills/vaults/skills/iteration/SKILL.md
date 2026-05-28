---
name: geno-loops-vaults-iteration
description: >-
  Per-session iteration protocol for any vault loop. Covers iter-start,
  steering detection, writing iter notes with the canonical filename schema,
  and iter-end commit. Use when implementing or debugging a loop's iteration
  logic, or when an iteration note is malformed/missing.
argument-hint: "[--session <name>] [--iter <NNN>]"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
---

# Vault Iteration Protocol

Every loop in the fleet follows this pattern at the start and end of each
iteration. The vault-agent enforces the schema via `vault-status.sh`.

## Canonical filename schema

```
VAULT/<session>/iterations/YYYY-MM-DDTHHMM-iter-NNN.md
```

- `YYYY-MM-DD` — Pacific date (e.g. `2026-05-27`)
- `HHMM` — Pacific time, zero-padded, 24hr (e.g. `0930`)
- `NNN` — zero-padded 3-digit counter (e.g. `001`)

Example: `t3-Session/iterations/2026-05-27T0930-iter-007.md`

**Schema violations** are flagged by `vault-status.sh` and reported in
`dashboard.md`.

## Iteration start

```bash
tools/iteration-start.sh
```

Prints current PT time, next 15-min tick, and runs `detect-steering.sh`.
If `STEERING` is found, read and follow the bullet items under
`## Steering (user-editable)` in the session's `main.md`.

## Working tree restore (if needed)

```bash
tools/iter-restore.sh          # restore + report
tools/iter-restore.sh --check  # report only
tools/iter-restore.sh --quiet  # restore silently
```

Use at the top of any iteration that follows a watchdog rebuild or rsync
pull from the remote host.

## Writing the iteration note

Create the file before committing:

```bash
PT=$(TZ=America/Los_Angeles date '+%Y-%m-%dT%H%M')
ITER=NNN  # next unused number
NOTE="VAULT/<session>/iterations/${PT}-iter-${ITER}.md"

cat > "$NOTE" << 'EOF'
## iter-NNN (YYYY-MM-DDTHHMM PT)

**Shipped:** one-line description
**Files changed:** list key files
EOF
```

## Iteration end (commit)

```bash
tools/iteration-end.sh "iter-NNN: short description"
```

This stages all changes (`git add -A`) and commits with author
`vault-agent / vault-agent@local` so `detect-steering.sh` can
distinguish agent vs human edits.

**Write the iter note and all other changes BEFORE calling this**, so
everything lands in a single atomic commit.

## Updating main.md

After shipping, update the session's `main.md`:

1. `## Current status` — last iter timestamp, any drift/issues
2. `## Improvement queue` — mark shipped item `[x]`
3. `## Recent iterations` — prepend a one-liner for this iter

Keep the `## Steering (user-editable)` section intact (do not clear it —
that is the user's job or a subsequent iter's job).

## Time helpers

```bash
tools/time-helpers.sh pt12       # "9:39 PM PDT"
tools/time-helpers.sh utc24      # "2026-05-27T04:39Z"
tools/time-helpers.sh next15     # "9:45 PM PDT"
tools/time-helpers.sh countdown  # "6 min"
```
